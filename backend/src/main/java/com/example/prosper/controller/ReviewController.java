package com.example.prosper.controller;

import com.example.prosper.model.Review;
import com.example.prosper.model.User;
import com.example.prosper.model.Book;
import com.example.prosper.service.ReviewService;
import com.example.prosper.repository.UserRepository;
import com.example.prosper.repository.BookRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

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
    public ResponseEntity<?> createReview(@RequestBody Map<String, Object> payload, Authentication authentication) {
        try {
            String email = authentication.getName();
            User user = userRepository.findByEmail(email).orElseThrow();
            
            Long bookId = Long.valueOf(payload.get("bookId").toString());
            Book book = bookRepository.findById(bookId).orElseThrow();

            Review review = new Review();
            review.setUser(user);
            review.setBook(book);
            review.setContent((String) payload.get("content"));
            
            if (payload.containsKey("parentId") && payload.get("parentId") != null) {
                Long parentId = Long.valueOf(payload.get("parentId").toString());
                Review parent = reviewService.getReviewById(parentId).orElseThrow();
                review.setParentReview(parent);
                // Replies inherit type/rating/sentiment or have defaults? 
                // Usually replies don't have rating.
                review.setType(parent.getType());
                review.setRating(0);
                review.setSentiment(Review.Sentiment.NEUTRAL);
            } else {
                review.setType(Review.ReviewType.valueOf((String) payload.get("type")));
                review.setRating((Integer) payload.get("rating"));
                review.setSentiment(Review.Sentiment.valueOf((String) payload.get("sentiment")));
            }

            return ResponseEntity.ok(reviewService.createReview(review));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteReview(@PathVariable Long id, Authentication authentication) {
        try {
            String email = authentication.getName();
            User user = userRepository.findByEmail(email).orElseThrow();
            Review review = reviewService.getReviewById(id).orElseThrow();
            
            if (!review.getUser().getId().equals(user.getId())) {
                return ResponseEntity.status(403).body("You can only delete your own reviews");
            }
            
            reviewService.deleteReview(id);
            return ResponseEntity.ok().build();
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }
}
