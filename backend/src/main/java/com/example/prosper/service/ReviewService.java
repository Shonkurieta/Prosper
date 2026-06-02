package com.example.prosper.service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.prosper.model.Review;
import com.example.prosper.model.ReviewLike;
import com.example.prosper.model.ReviewView;
import com.example.prosper.repository.ReviewLikeRepository;
import com.example.prosper.repository.ReviewRepository;
import com.example.prosper.repository.ReviewViewRepository;

@Service
public class ReviewService {

    @Autowired
    private ReviewRepository reviewRepository;

    @Autowired
    private ReviewLikeRepository reviewLikeRepository;

    @Autowired
    private ReviewViewRepository reviewViewRepository;

    public List<Review> getReviewsByBook(Long bookId, Long userId) {
        List<Review> reviews = reviewRepository.findByBookIdOrderByCreatedAtDesc(bookId);
        enrichReviews(reviews, userId);
        return reviews;
    }

    public List<Review> getRecentReviews(int limit, Long userId) {
        List<Review> reviews = reviewRepository.findAllByOrderByCreatedAtDesc(PageRequest.of(0, limit));
        enrichReviews(reviews, userId);
        return reviews;
    }

    private void enrichReviews(List<Review> reviews, Long userId) {
        if (reviews.isEmpty()) return;

        List<Long> ids = reviews.stream().map(Review::getId).collect(Collectors.toList());

        Map<Long, long[]> likeCounts = new HashMap<>();
        for (Object[] row : reviewLikeRepository.aggregateByReviewIds(ids)) {
            long reviewId = ((Number) row[0]).longValue();
            long likes = ((Number) row[1]).longValue();
            long dislikes = ((Number) row[2]).longValue();
            likeCounts.put(reviewId, new long[]{likes, dislikes});
        }

        Map<Long, Long> viewCounts = new HashMap<>();
        for (Object[] row : reviewViewRepository.countByReviewIdIn(ids)) {
            long reviewId = ((Number) row[0]).longValue();
            long count = ((Number) row[1]).longValue();
            viewCounts.put(reviewId, count);
        }

        Map<Long, Boolean> userReactions = new HashMap<>();
        if (userId != null) {
            reviewLikeRepository.findByUserIdAndReviewIdIn(userId, ids)
                .forEach(rl -> userReactions.put(rl.getReviewId(), rl.isLiked()));
        }

        for (Review review : reviews) {
            long[] cnt = likeCounts.getOrDefault(review.getId(), new long[]{0, 0});
            review.setLikeCount((int) cnt[0]);
            review.setDislikeCount((int) cnt[1]);
            review.setViewCount((int) (long) viewCounts.getOrDefault(review.getId(), 0L));
            if (userId != null) {
                review.setUserLikeStatus(userReactions.getOrDefault(review.getId(), null));
            }
        }
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

    @Transactional
    public Boolean toggleLike(Long reviewId, Long userId, boolean isLike) {
        Optional<ReviewLike> existing = reviewLikeRepository.findByUserIdAndReviewId(userId, reviewId);
        if (existing.isPresent()) {
            ReviewLike rl = existing.get();
            if (rl.isLiked() == isLike) {
                // повторное нажатие — снимаем реакцию
                reviewLikeRepository.deleteByUserIdAndReviewId(userId, reviewId);
                return null;
            } else {
                // смена реакции
                rl.setLiked(isLike);
                reviewLikeRepository.save(rl);
                return isLike;
            }
        } else {
            reviewLikeRepository.save(new ReviewLike(userId, reviewId, isLike));
            return isLike;
        }
    }

    @Transactional
    public boolean recordView(Long reviewId, Long userId) {
        if (reviewViewRepository.findByUserIdAndReviewId(userId, reviewId).isEmpty()) {
            reviewViewRepository.save(new ReviewView(userId, reviewId));
            return true;
        }
        return false;
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
