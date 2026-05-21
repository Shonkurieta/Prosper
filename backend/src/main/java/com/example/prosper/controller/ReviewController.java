package com.example.prosper.controller;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.prosper.model.Book;
import com.example.prosper.model.Review;
import com.example.prosper.model.User;
import com.example.prosper.repository.BookRepository;
import com.example.prosper.repository.UserRepository;
import com.example.prosper.service.ReviewService;

@RestController
@RequestMapping("/api/reviews")
public class ReviewController {

    @Autowired
    private ReviewService reviewService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private BookRepository bookRepository;

    @GetMapping("/book/{bookId}")
    public List<Review> getReviews(@PathVariable Long bookId) {
        return reviewService.getReviewsByBook(bookId);
    }

    @PostMapping
    public ResponseEntity<?> createReview(
            @RequestBody Map<String, Object> payload,
            Authentication authentication) {
        try {
            String nickname = authentication.getName();
            User user = userRepository.findByNickname(nickname)
                    .orElseThrow(() -> new RuntimeException("User not found: " + nickname));

            Object rawBookId = payload.get("bookId");
            if (rawBookId == null) {
                return ResponseEntity.badRequest().body(Map.of("message", "bookId is required"));
            }
            Long bookId = Long.valueOf(rawBookId.toString());
            Book book = bookRepository.findById(bookId)
                    .orElseThrow(() -> new RuntimeException("Book not found: " + bookId));

            Review review = new Review();
            review.setUser(user);
            review.setBook(book);
            review.setContent((String) payload.get("content"));

            if (payload.containsKey("parentId") && payload.get("parentId") != null) {
                Long parentId = Long.valueOf(payload.get("parentId").toString());
                Review parent = reviewService.getReviewById(parentId)
                        .orElseThrow(() -> new RuntimeException("Parent review not found: " + parentId));
                review.setParentReview(parent);
                review.setType(parent.getType());
                review.setRating(0);
                review.setSentiment(Review.Sentiment.NEUTRAL);
            } else {
                Object rawType = payload.get("type");
                Object rawRating = payload.get("rating");
                Object rawSentiment = payload.get("sentiment");

                if (rawType == null || rawRating == null || rawSentiment == null) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("message", "type, rating and sentiment are required"));
                }

                review.setType(Review.ReviewType.valueOf(rawType.toString()));
                review.setRating(Integer.valueOf(rawRating.toString()));
                review.setSentiment(Review.Sentiment.valueOf(rawSentiment.toString()));
            }

            return ResponseEntity.ok(reviewService.createReview(review));

        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", "Invalid enum value: " + e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteReview(
            @PathVariable Long id,
            Authentication authentication) {
        try {
            String nickname = authentication.getName();
            User user = userRepository.findByNickname(nickname)
                    .orElseThrow(() -> new RuntimeException("User not found: " + nickname));

            Review review = reviewService.getReviewById(id)
                    .orElseThrow(() -> new RuntimeException("Review not found: " + id));

            if (!review.getUser().getId().equals(user.getId())) {
                return ResponseEntity.status(403)
                        .body(Map.of("message", "You can only delete your own reviews"));
            }

            reviewService.deleteReview(id);
            return ResponseEntity.ok(Map.of("message", "Deleted successfully"));

        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }
}