package com.example.prosper.repository;

import com.example.prosper.model.ReviewView;
import com.example.prosper.model.ReviewViewPK;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ReviewViewRepository extends JpaRepository<ReviewView, ReviewViewPK> {
    Optional<ReviewView> findByUserIdAndReviewId(Long userId, Long reviewId);
    int countByReviewId(Long reviewId);

    @Query("SELECT rv.reviewId, COUNT(rv) FROM ReviewView rv WHERE rv.reviewId IN :ids GROUP BY rv.reviewId")
    List<Object[]> countByReviewIdIn(@Param("ids") List<Long> ids);
}
