package com.example.prosper.repository;

import com.example.prosper.model.ReviewLike;
import com.example.prosper.model.ReviewLikePK;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ReviewLikeRepository extends JpaRepository<ReviewLike, ReviewLikePK> {
    Optional<ReviewLike> findByUserIdAndReviewId(Long userId, Long reviewId);
    int countByReviewIdAndLiked(Long reviewId, boolean liked);
    void deleteByUserIdAndReviewId(Long userId, Long reviewId);

    @Query("SELECT rl.reviewId, COUNT(CASE WHEN rl.liked = true THEN 1 END), COUNT(CASE WHEN rl.liked = false THEN 1 END) FROM ReviewLike rl WHERE rl.reviewId IN :ids GROUP BY rl.reviewId")
    List<Object[]> aggregateByReviewIds(@Param("ids") List<Long> ids);

    @Query("SELECT rl FROM ReviewLike rl WHERE rl.userId = :userId AND rl.reviewId IN :ids")
    List<ReviewLike> findByUserIdAndReviewIdIn(@Param("userId") Long userId, @Param("ids") List<Long> ids);
}
