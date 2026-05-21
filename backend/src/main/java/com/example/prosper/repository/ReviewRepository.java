package com.example.prosper.repository;

import com.example.prosper.model.Review;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ReviewRepository extends JpaRepository<Review, Long> {
    List<Review> findByBookIdAndParentReviewIsNullOrderByCreatedAtDesc(Long bookId);
}
