package com.example.prosper.controller;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

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

    private Long resolveUserId(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()
                || "anonymousUser".equals(authentication.getPrincipal())) {
            return null;
        }
        return userRepository.findByNickname(authentication.getName())
                .map(User::getId).orElse(null);
    }

    @GetMapping("/book/{bookId}")
    public List<Review> getReviews(@PathVariable Long bookId, Authentication authentication) {
        return reviewService.getReviewsByBook(bookId, resolveUserId(authentication));
    }

    @GetMapping("/recent")
    public List<Review> getRecentReviews(
            @RequestParam(defaultValue = "20") int limit,
            Authentication authentication) {
        return reviewService.getRecentReviews(limit, resolveUserId(authentication));
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

            Object rawType = payload.get("type");
            Object rawRating = payload.get("rating");
            Object rawSentiment = payload.get("sentiment");

            if (rawType == null || rawRating == null || rawSentiment == null) {
                return ResponseEntity.badRequest()
                        .body(Map.of("message", "type, rating and sentiment are required"));
            }

            Review review = new Review();
            review.setUser(user);
            review.setBook(book);
            review.setTitle((String) payload.get("title"));
            review.setContent((String) payload.get("content"));
            review.setType(Review.ReviewType.valueOf(rawType.toString()));
            review.setRating(Integer.valueOf(rawRating.toString()));
            review.setSentiment(Review.Sentiment.valueOf(rawSentiment.toString()));

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

    @PostMapping("/{id}/like")
    public ResponseEntity<?> toggleLike(
            @PathVariable Long id,
            @RequestBody Map<String, Object> payload,
            Authentication authentication) {
        try {
            Long userId = resolveUserId(authentication);
            if (userId == null) return ResponseEntity.status(401).body(Map.of("message", "Unauthorized"));

            boolean isLike = Boolean.parseBoolean(payload.get("isLike").toString());
            Boolean result = reviewService.toggleLike(id, userId, isLike);
            return ResponseEntity.ok(Map.of("userLikeStatus", result == null ? "null" : result.toString()));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/{id}/view")
    public ResponseEntity<?> recordView(
            @PathVariable Long id,
            Authentication authentication) {
        try {
            Long userId = resolveUserId(authentication);
            if (userId == null) return ResponseEntity.status(401).body(Map.of("message", "Unauthorized"));
            boolean isNew = reviewService.recordView(id, userId);
            return ResponseEntity.ok(Map.of("isNew", isNew));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }
}
