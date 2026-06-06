import asyncio
import logging
import threading
from contextlib import asynccontextmanager

import numpy as np
import psycopg2
from fastapi import FastAPI
from pydantic import BaseModel

from recommender import Recommender, DB_CONFIG

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)

recommender = Recommender()

# Cache: book_id → list of (chapter_id, title, content, mean_embedding)
_chapter_cache: dict[int, list[tuple[int, str, str, np.ndarray]]] = {}

# Set of book_ids whose embeddings are currently being computed in background
_warming_set: set[int] = set()

# Lock only for dict/set mutations — never held during DB queries or model.encode()
_cache_lock = threading.Lock()


@asynccontextmanager
async def lifespan(app: FastAPI):
    asyncio.create_task(_init_and_refresh())
    yield


async def _init_and_refresh():
    await recommender.initialize()
    await recommender.background_refresh()


app = FastAPI(title="Prosper ML Service", lifespan=lifespan)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/recommendations/{user_id}")
async def get_recommendations(user_id: int, limit: int = 10):
    return await recommender.get_recommendations(user_id, limit)


class SemanticSearchRequest(BaseModel):
    question: str
    book_id: int
    top_k: int = 5


# ──────────────────────────────────────────────────────────────────────────────
# Chunking + embedding helpers
# ──────────────────────────────────────────────────────────────────────────────

def _chunk_text(text: str, chunk_words: int = 500, overlap_words: int = 100) -> list[str]:
    """Split text into overlapping word-based chunks for full-chapter coverage."""
    words = text.split()
    if not words:
        return [""]
    if len(words) <= chunk_words:
        return [text]
    chunks = []
    start = 0
    while start < len(words):
        end = min(start + chunk_words, len(words))
        chunks.append(" ".join(words[start:end]))
        if end == len(words):
            break
        start += chunk_words - overlap_words
    return chunks


def _embed_chapter(model, content: str) -> np.ndarray:
    """Mean embedding over word-based chunks — covers the full chapter, not just first 512 chars."""
    chunks = _chunk_text(content)
    embeddings = model.encode(
        chunks, batch_size=16, show_progress_bar=False, convert_to_numpy=True
    )
    return np.mean(embeddings, axis=0).astype(np.float32)


# ──────────────────────────────────────────────────────────────────────────────
# Background cache computation
# ──────────────────────────────────────────────────────────────────────────────

def _compute_and_cache_chapters(book_id: int) -> None:
    """Runs in a thread-pool worker. Lock is NOT held during DB load or model.encode.
    Only acquired briefly at the end to write the result and remove from warming_set.
    """
    logging.info(f"Background: starting embedding computation for book_id={book_id}")
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute(
            "SELECT id, title, content FROM chapters "
            "WHERE book_id = %s AND content IS NOT NULL AND content != '' "
            "ORDER BY chapter_order ASC",
            (book_id,),
        )
        rows = cur.fetchall()
        cur.close()
        conn.close()
    except Exception as e:
        logging.error(f"DB error in background cache for book {book_id}: {e}")
        with _cache_lock:
            _warming_set.discard(book_id)
        return

    if not rows:
        with _cache_lock:
            _warming_set.discard(book_id)
        return

    model = recommender.embedding_store.model
    result = []
    for row in rows:
        cid, title, content = row[0], row[1] or "", row[2] or ""
        emb = _embed_chapter(model, content)
        result.append((cid, title, content, emb))

    with _cache_lock:
        _chapter_cache[book_id] = result
        _warming_set.discard(book_id)

    logging.info(f"Background: cached {len(result)} chapter embeddings for book_id={book_id}")


# ──────────────────────────────────────────────────────────────────────────────
# Semantic search endpoint
# ──────────────────────────────────────────────────────────────────────────────

@app.post("/semantic-search")
async def semantic_search(req: SemanticSearchRequest):
    loop = asyncio.get_running_loop()

    # --- Cache check (fast path, lock held only for dict lookups) ---
    with _cache_lock:
        chapters = _chapter_cache.get(req.book_id)
        if chapters is None:
            if req.book_id not in _warming_set:
                # First request for this book — kick off background computation and return empty.
                # FTS + ILIKE results will serve this request; semantic kicks in next time.
                _warming_set.add(req.book_id)
                loop.run_in_executor(None, _compute_and_cache_chapters, req.book_id)
                logging.info(f"Warm-up started for book_id={req.book_id}, returning empty for now")
            # Either just started warming or already in progress — return empty immediately
            return {"chapters": []}

    # --- Cache hit: compute similarity ---
    question_emb = await loop.run_in_executor(
        None,
        lambda: recommender.embedding_store.model.encode(
            [req.question], show_progress_bar=False, convert_to_numpy=True
        )[0].astype(np.float32),
    )

    q_norm = float(np.linalg.norm(question_emb))
    if q_norm > 0:
        question_emb = question_emb / q_norm

    matrix = np.array([c[3] for c in chapters], dtype=np.float32)
    norms = np.linalg.norm(matrix, axis=1, keepdims=True)
    norms = np.where(norms == 0, 1.0, norms)
    normalized = matrix / norms

    similarities = normalized @ question_emb
    top_k = min(req.top_k, len(chapters))
    top_indices = np.argsort(similarities)[::-1][:top_k]

    results = [
        {
            "chapter_id": chapters[i][0],
            "title": chapters[i][1],
            "content": chapters[i][2][:2000],
            "score": float(similarities[i]),
        }
        for i in top_indices
    ]

    return {"chapters": results}
