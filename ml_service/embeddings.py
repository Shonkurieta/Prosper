import logging
import threading

import numpy as np
import psycopg2
from sentence_transformers import SentenceTransformer

logger = logging.getLogger(__name__)


class EmbeddingStore:
    def __init__(self, db_config: dict):
        self.db_config = db_config
        self.model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")
        self.model.max_seq_length = 256

        self._book_embeddings: dict[int, np.ndarray] = {}
        self._embeddings_matrix: np.ndarray | None = None
        self._book_ids: list[int] = []
        self._lock = threading.RLock()

    def _get_connection(self):
        return psycopg2.connect(**self.db_config)

    def load_and_compute(self):
        """Load all books from DB and compute embeddings for new ones only."""
        try:
            conn = self._get_connection()
            cur = conn.cursor()
            cur.execute(
                "SELECT id, description FROM books "
                "WHERE description IS NOT NULL AND description != ''"
            )
            books = cur.fetchall()
            cur.close()
            conn.close()
        except Exception as e:
            logger.error(f"DB error in load_and_compute: {e}")
            return

        with self._lock:
            new_books = [(bid, desc) for bid, desc in books if bid not in self._book_embeddings]

        if new_books:
            logger.info(f"Computing embeddings for {len(new_books)} new books")
            descriptions = [desc for _, desc in new_books]
            vectors = self.model.encode(
                descriptions, batch_size=16, show_progress_bar=False, convert_to_numpy=True
            )
            with self._lock:
                for (bid, _), vec in zip(new_books, vectors):
                    self._book_embeddings[bid] = vec.astype(np.float32)

        with self._lock:
            self._book_ids = list(self._book_embeddings.keys())
            if self._book_ids:
                matrix = np.array(
                    [self._book_embeddings[bid] for bid in self._book_ids], dtype=np.float32
                )
                norms = np.linalg.norm(matrix, axis=1, keepdims=True)
                norms = np.where(norms == 0, 1.0, norms)
                self._embeddings_matrix = matrix / norms
                logger.info(f"Embeddings matrix ready: {self._embeddings_matrix.shape}")

    def get_similar_books(
        self,
        query_book_ids: list[int],
        top_k: int = 50,
        exclude_ids: set[int] | None = None,
    ) -> list[tuple[int, float]]:
        """Return top-k books by cosine similarity to the mean of query_book_ids embeddings."""
        with self._lock:
            if self._embeddings_matrix is None or not query_book_ids:
                return []

            query_vecs = [
                self._book_embeddings[bid]
                for bid in query_book_ids
                if bid in self._book_embeddings
            ]
            if not query_vecs:
                return []

            avg_vec = np.mean(query_vecs, axis=0).astype(np.float32)
            norm = float(np.linalg.norm(avg_vec))
            if norm > 0:
                avg_vec /= norm

            # Cosine similarity: matrix rows are already normalized
            similarities = self._embeddings_matrix @ avg_vec

            exclude_set = (exclude_ids or set()) | set(query_book_ids)
            results: list[tuple[int, float]] = []
            for idx in np.argsort(similarities)[::-1]:
                bid = self._book_ids[idx]
                if bid not in exclude_set:
                    results.append((bid, float(similarities[idx])))
                    if len(results) >= top_k:
                        break
            return results
