package com.example.prosper.service;

import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.example.prosper.model.Review;
import com.example.prosper.repository.ReviewRepository;

@Service
public class ReviewService {

    @Autowired
    private ReviewRepository reviewRepository;

    public List<Review> getReviewsByBook(Long bookId) {
        return reviewRepository.findByBookIdOrderByCreatedAtDesc(bookId);
    }

    public Review createReview(Review review) {
        validateReview(review);
        return reviewRepository.save(review);
    }

    public void deleteReview(Long id) {
        reviewRepository.deleteById(id);
    }

    public Optional<Review> getReviewById(Long id) {
        return reviewRepository.findById(id);
    }

    private void validateReview(Review review) {
        String content = review.getContent();
        int length = content != null ? content.length() : 0;

        if (review.getType() == Review.ReviewType.REVIEW) {
            if (length < 500 || length > 2000) {
                throw new IllegalArgumentException("Review must be between 500 and 2000 characters");
            }
        } else if (review.getType() == Review.ReviewType.CRITIQUE) {
            if (length < 3000) {
                throw new IllegalArgumentException("Critique must be at least 3000 characters");
            }
        }
    }
}
