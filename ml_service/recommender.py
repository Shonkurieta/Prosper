import asyncio
import logging
import os
import threading
from collections import defaultdict

import numpy as np
import psycopg2
from sklearn.decomposition import TruncatedSVD
from sklearn.metrics.pairwise import cosine_similarity

from embeddings import EmbeddingStore

logger = logging.getLogger(__name__)

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "db"),
    "port": int(os.getenv("DB_PORT", 5432)),
    "dbname": os.getenv("DB_NAME", "prosper"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "12345"),
}


class Recommender:
    def __init__(self):
        self.embedding_store = EmbeddingStore(DB_CONFIG)

        self._svd_ready = False
        self._user_factors: np.ndarray | None = None
        self._svd_matrix: np.ndarray | None = None
        self._svd_user_ids: list[int] = []
        self._svd_book_ids: list[int] = []
        self._svd_user_idx: dict[int, int] = {}
        self._svd_book_idx: dict[int, int] = {}
        self._lock = threading.RLock()

    # ──────────────────────────────────────────────────────────────────────────
    # Lifecycle
    # ──────────────────────────────────────────────────────────────────────────

    async def initialize(self):
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(None, self.embedding_store.load_and_compute)
        await loop.run_in_executor(None, self._build_svd)

    async def background_refresh(self):
        """Rebuild embeddings (new books only) and SVD every hour."""
        while True:
            await asyncio.sleep(3600)
            loop = asyncio.get_running_loop()
            await loop.run_in_executor(None, self.embedding_store.load_and_compute)
            await loop.run_in_executor(None, self._build_svd)

    # ──────────────────────────────────────────────────────────────────────────
    # DB helpers
    # ──────────────────────────────────────────────────────────────────────────

    def _conn(self):
        return psycopg2.connect(**DB_CONFIG)

    def _get_user_data(self, user_id: int) -> dict:
        conn = self._conn()
        cur = conn.cursor()

        # Bookmarks with reading progress
        cur.execute(
            """
            SELECT ub.book_id, ub.status, ub.current_chapter,
                   (SELECT COUNT(*) FROM chapters c WHERE c.book_id = ub.book_id)
            FROM user_books ub
            WHERE ub.user_id = %s AND ub.bookmarked = true
            """,
            (user_id,),
        )
        bookmarks = cur.fetchall()  # (book_id, status_str, current_chapter, total_chapters)

        # Ratings
        cur.execute(
            "SELECT book_id, rating FROM book_ratings WHERE user_id = %s",
            (user_id,),
        )
        ratings = cur.fetchall()  # (book_id, rating)

        # Genres of bookmarked books
        cur.execute(
            """
            SELECT ub.book_id, ub.status, g.name
            FROM user_books ub
            JOIN book_genres bg ON bg.book_id = ub.book_id
            JOIN genres g ON g.id = bg.genre_id
            WHERE ub.user_id = %s AND ub.bookmarked = true
            """,
            (user_id,),
        )
        bookmark_genres = cur.fetchall()  # (book_id, status_str, genre_name)

        # Genres of rated books
        cur.execute(
            """
            SELECT br.book_id, br.rating, g.name
            FROM book_ratings br
            JOIN book_genres bg ON bg.book_id = br.book_id
            JOIN genres g ON g.id = bg.genre_id
            WHERE br.user_id = %s
            """,
            (user_id,),
        )
        rating_genres = cur.fetchall()  # (book_id, rating, genre_name)

        cur.close()
        conn.close()
        return {
            "bookmarks": bookmarks,
            "ratings": ratings,
            "bookmark_genres": bookmark_genres,
            "rating_genres": rating_genres,
        }

    def _get_all_book_ids(self) -> list[int]:
        conn = self._conn()
        cur = conn.cursor()
        cur.execute("SELECT id FROM books")
        ids = [r[0] for r in cur.fetchall()]
        cur.close()
        conn.close()
        return ids

    def _fetch_genre_scores_for_targets(
        self, target_ids: list[int], genre_weights: dict[str, float]
    ) -> dict[int, float]:
        """Score target books by their genres using pre-computed genre weights."""
        if not target_ids or not genre_weights:
            return {}
        conn = self._conn()
        cur = conn.cursor()
        cur.execute(
            """
            SELECT b.id, g.name
            FROM books b
            JOIN book_genres bg ON bg.book_id = b.id
            JOIN genres g ON g.id = bg.genre_id
            WHERE b.id = ANY(%s)
            """,
            (target_ids,),
        )
        book_genre_map: dict[int, list[str]] = defaultdict(list)
        for bid, gname in cur.fetchall():
            book_genre_map[bid].append(gname)
        cur.close()
        conn.close()

        scores = {
            bid: sum(genre_weights.get(g, 0.0) for g in genres)
            for bid, genres in book_genre_map.items()
        }
        scores = {k: v for k, v in scores.items() if v > 0}
        if scores:
            mx = max(scores.values())
            if mx > 0:
                scores = {k: v / mx for k, v in scores.items()}
        return scores

    # ──────────────────────────────────────────────────────────────────────────
    # SVD collaborative filtering
    # ──────────────────────────────────────────────────────────────────────────

    def _build_svd(self):
        """Build TruncatedSVD user-item matrix from book_ratings."""
        try:
            conn = self._conn()
            cur = conn.cursor()
            cur.execute("SELECT user_id, book_id, rating FROM book_ratings")
            rows = cur.fetchall()
            cur.close()
            conn.close()

            if not rows:
                return

            user_ids = sorted({r[0] for r in rows})
            book_ids = sorted({r[1] for r in rows})
            user_idx = {uid: i for i, uid in enumerate(user_ids)}
            book_idx = {bid: i for i, bid in enumerate(book_ids)}

            matrix = np.zeros((len(user_ids), len(book_ids)), dtype=np.float32)
            for uid, bid, rating in rows:
                matrix[user_idx[uid], book_idx[bid]] = float(rating)

            n_comp = min(20, min(matrix.shape) - 1)
            if n_comp < 1:
                return

            svd = TruncatedSVD(n_components=n_comp, random_state=42)
            user_factors = svd.fit_transform(matrix)

            with self._lock:
                self._user_factors = user_factors
                self._svd_matrix = matrix
                self._svd_user_ids = user_ids
                self._svd_book_ids = book_ids
                self._svd_user_idx = user_idx
                self._svd_book_idx = book_idx
                self._svd_ready = True

            logger.info(f"SVD ready: matrix={matrix.shape}, components={n_comp}")
        except Exception as e:
            logger.error(f"SVD build error: {e}")

    # ──────────────────────────────────────────────────────────────────────────
    # Scoring: Level 2 (bookmarks, no ratings)
    # ──────────────────────────────────────────────────────────────────────────

    def _genre_scores_from_bookmarks(
        self,
        bookmarks: list,
        bookmark_genres: list,
        target_ids: list[int],
    ) -> dict[int, float]:
        """
        Genre weights from bookmarks.
        DROPPED status → weight ×0.5.
        Progress > 30% of total chapters → weight ×1.5.
        """
        genre_weights: dict[str, float] = defaultdict(float)

        for book_id, status, current_chapter, total_chapters in bookmarks:
            mult = 1.0
            if status == "DROPPED":
                mult *= 0.5
            if total_chapters and total_chapters > 0:
                if current_chapter / total_chapters > 0.3:
                    mult *= 1.5

            for bg_book_id, _, genre_name in bookmark_genres:
                if bg_book_id == book_id:
                    genre_weights[genre_name] += mult

        if not genre_weights:
            return {}

        total = sum(genre_weights.values())
        norm_weights = {k: v / total for k, v in genre_weights.items()}
        return self._fetch_genre_scores_for_targets(target_ids, norm_weights)

    # ──────────────────────────────────────────────────────────────────────────
    # Scoring: Level 3/4 (ratings-based)
    # ──────────────────────────────────────────────────────────────────────────

    def _genre_scores_from_ratings(
        self,
        ratings: list,
        rating_genres: list,
        target_ids: list[int],
    ) -> dict[int, float]:
        """
        Genre weights from rated books.
        High-rated (7+) books preferred; genres of low-rated books (≤3) are penalised.
        """
        rating_map = {bid: r for bid, r in ratings}
        high_rated_ids = {bid for bid, r in ratings if r >= 7}
        source_ids = high_rated_ids if high_rated_ids else set(rating_map.keys())

        penalised_genres: set[str] = set()
        genre_sum: dict[str, float] = defaultdict(float)
        genre_count: dict[str, int] = defaultdict(int)

        for book_id, rating, genre_name in rating_genres:
            if rating <= 3:
                penalised_genres.add(genre_name)
            if book_id not in source_ids:
                continue
            genre_sum[genre_name] += rating_map.get(book_id, 5)
            genre_count[genre_name] += 1

        genre_weights: dict[str, float] = {}
        for genre, s in genre_sum.items():
            avg = s / genre_count[genre]
            if genre in penalised_genres:
                avg = max(0.0, avg - 2.0)
            genre_weights[genre] = avg

        if not genre_weights:
            return {}

        mx = max(genre_weights.values())
        if mx > 0:
            genre_weights = {k: v / mx for k, v in genre_weights.items()}
        return self._fetch_genre_scores_for_targets(target_ids, genre_weights)

    # ──────────────────────────────────────────────────────────────────────────
    # Scoring: Level 4 SVD
    # ──────────────────────────────────────────────────────────────────────────

    def _svd_scores(self, user_id: int, exclude_ids: set[int]) -> dict[int, float]:
        """
        Collaborative filtering via TruncatedSVD.
        Finds top-20 similar users, aggregates their 8+ rated books.
        """
        with self._lock:
            if not self._svd_ready or user_id not in self._svd_user_idx:
                return {}

            u_idx = self._svd_user_idx[user_id]
            user_vec = self._user_factors[u_idx : u_idx + 1]
            sims = cosine_similarity(user_vec, self._user_factors)[0]
            sims[u_idx] = -1.0  # exclude self

            top_indices = np.argsort(sims)[::-1][:20]

            book_scores: dict[int, float] = defaultdict(float)
            for sim_idx in top_indices:
                sim_weight = float(sims[sim_idx])
                if sim_weight <= 0:
                    continue
                for b_idx, bid in enumerate(self._svd_book_ids):
                    if bid in exclude_ids:
                        continue
                    rating = float(self._svd_matrix[sim_idx, b_idx])
                    if rating >= 8:
                        book_scores[bid] += sim_weight

            if not book_scores:
                return {}

            mx = max(book_scores.values())
            if mx > 0:
                book_scores = {k: v / mx for k, v in book_scores.items()}
            return dict(book_scores)

    # ──────────────────────────────────────────────────────────────────────────
    # Main entrypoint
    # ──────────────────────────────────────────────────────────────────────────

    async def get_recommendations(self, user_id: int, limit: int = 10) -> dict:
        loop = asyncio.get_running_loop()

        try:
            user_data = await loop.run_in_executor(None, self._get_user_data, user_id)
        except Exception as e:
            logger.error(f"Error fetching user data for {user_id}: {e}")
            return {"bookIds": [], "level": 0}

        bookmarks = user_data["bookmarks"]
        ratings = user_data["ratings"]
        bookmark_genres = user_data["bookmark_genres"]
        rating_genres = user_data["rating_genres"]

        bookmark_ids: set[int] = {b[0] for b in bookmarks}
        rated_ids: set[int] = {r[0] for r in ratings}
        exclude_ids = bookmark_ids | rated_ids

        has_bookmarks = bool(bookmarks)
        has_ratings = bool(ratings)
        many_ratings = len(ratings) >= 6

        # ── Level 1: no data ──────────────────────────────────────────────────
        if not has_bookmarks and not has_ratings:
            return {"bookIds": [], "level": 1}

        all_book_ids = await loop.run_in_executor(None, self._get_all_book_ids)
        target_ids = [bid for bid in all_book_ids if bid not in exclude_ids]

        if not target_ids:
            return {"bookIds": [], "level": 1}

        # ── Level 2: bookmarks only ───────────────────────────────────────────
        if has_bookmarks and not has_ratings:
            genre_sc = await loop.run_in_executor(
                None, self._genre_scores_from_bookmarks,
                bookmarks, bookmark_genres, target_ids,
            )
            emb_pairs = self.embedding_store.get_similar_books(
                list(bookmark_ids), top_k=100, exclude_ids=exclude_ids
            )
            emb_sc = {bid: s for bid, s in emb_pairs}

            candidates = set(genre_sc) | set(emb_sc)
            final = {
                bid: 0.5 * genre_sc.get(bid, 0.0) + 0.5 * emb_sc.get(bid, 0.0)
                for bid in candidates
            }
            level = 2

        # ── Level 3: few ratings (<6) ─────────────────────────────────────────
        elif has_ratings and not many_ratings:
            genre_sc = await loop.run_in_executor(
                None, self._genre_scores_from_ratings,
                ratings, rating_genres, target_ids,
            )
            high_rated_ids = [bid for bid, r in ratings if r >= 7] or list(rated_ids)
            emb_pairs = self.embedding_store.get_similar_books(
                high_rated_ids, top_k=100, exclude_ids=exclude_ids
            )
            emb_sc = {bid: s for bid, s in emb_pairs}

            candidates = set(genre_sc) | set(emb_sc)
            final = {
                bid: 0.4 * genre_sc.get(bid, 0.0) + 0.6 * emb_sc.get(bid, 0.0)
                for bid in candidates
            }
            level = 3

        # ── Level 4: many ratings (≥6) ────────────────────────────────────────
        else:
            genre_sc = await loop.run_in_executor(
                None, self._genre_scores_from_ratings,
                ratings, rating_genres, target_ids,
            )
            svd_sc = await loop.run_in_executor(
                None, self._svd_scores, user_id, exclude_ids,
            )

            # Pick embedding query books: top-rated 8+, max 30 if >100 ratings
            high_rated_ids = [bid for bid, r in ratings if r >= 8]
            if len(ratings) > 100:
                high_rated_ids = [
                    bid for bid, _ in sorted(
                        [(b, r) for b, r in ratings if r >= 8],
                        key=lambda x: x[1], reverse=True
                    )[:30]
                ]
            if not high_rated_ids:
                high_rated_ids = list(rated_ids)[:30]

            emb_pairs = self.embedding_store.get_similar_books(
                high_rated_ids, top_k=100, exclude_ids=exclude_ids
            )
            emb_sc = {bid: s for bid, s in emb_pairs}

            if not svd_sc:
                # SVD not ready yet — fall back to genre+embeddings
                candidates = set(genre_sc) | set(emb_sc)
                final = {
                    bid: 0.4 * genre_sc.get(bid, 0.0) + 0.6 * emb_sc.get(bid, 0.0)
                    for bid in candidates
                }
            else:
                candidates = set(genre_sc) | set(svd_sc) | set(emb_sc)
                final = {
                    bid: (
                        0.2 * genre_sc.get(bid, 0.0)
                        + 0.5 * svd_sc.get(bid, 0.0)
                        + 0.3 * emb_sc.get(bid, 0.0)
                    )
                    for bid in candidates
                }
            level = 4

        sorted_books = sorted(final.items(), key=lambda x: x[1], reverse=True)[:limit]
        return {"bookIds": [bid for bid, _ in sorted_books], "level": level}
