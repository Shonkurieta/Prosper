package com.example.prosper.controller;

import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.prosper.dto.BookRatingDTO;
import com.example.prosper.model.Book;
import com.example.prosper.model.BookRating;
import com.example.prosper.model.User;
import com.example.prosper.repository.BookRatingRepository;
import com.example.prosper.repository.BookRepository;
import com.example.prosper.repository.UserRepository;

@RestController
@RequestMapping("/api/books/{bookId}/rating")
public class BookRatingController {

    @Autowired
    private BookRatingRepository bookRatingRepository;

    @Autowired
    private BookRepository bookRepository;

    @Autowired
    private UserRepository userRepository;

    @GetMapping
    public ResponseEntity<BookRatingDTO> getRating(
            @PathVariable Long bookId,
            @AuthenticationPrincipal UserDetails userDetails) {

        Double avg = bookRatingRepository.getAverageRatingByBookId(bookId);
        Long count = bookRatingRepository.countByBookId(bookId);

        BookRatingDTO dto = new BookRatingDTO();
        dto.setAverageRating(avg != null ? Math.round(avg * 10.0) / 10.0 : null);
        dto.setRatingCount(count);

        if (userDetails != null) {
            userRepository.findByNickname(userDetails.getUsername()).ifPresent(user -> {
                bookRepository.findById(bookId).ifPresent(book -> {
                    bookRatingRepository.findByUserAndBook(user, book)
                            .ifPresent(r -> dto.setUserRating(r.getRating()));
                });
            });
        }

        return ResponseEntity.ok(dto);
    }

    @PostMapping
    public ResponseEntity<BookRatingDTO> rateBook(
            @PathVariable Long bookId,
            @RequestBody Map<String, Object> payload,
            @AuthenticationPrincipal UserDetails userDetails) {

        if (userDetails == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        int rating = ((Number) payload.get("rating")).intValue();
        if (rating < 1 || rating > 10) {
            return ResponseEntity.badRequest().build();
        }

        User user = userRepository.findByNickname(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));
        Book book = bookRepository.findById(bookId)
                .orElseThrow(() -> new RuntimeException("Book not found"));

        Optional<BookRating> existing = bookRatingRepository.findByUserAndBook(user, book);
        BookRating bookRating = existing.orElseGet(() -> {
            BookRating r = new BookRating();
            r.setUser(user);
            r.setBook(book);
            return r;
        });
        bookRating.setRating(rating);
        bookRatingRepository.save(bookRating);

        Double avg = bookRatingRepository.getAverageRatingByBookId(bookId);
        Long count = bookRatingRepository.countByBookId(bookId);

        BookRatingDTO dto = new BookRatingDTO();
        dto.setAverageRating(avg != null ? Math.round(avg * 10.0) / 10.0 : null);
        dto.setRatingCount(count);
        dto.setUserRating(rating);

        return ResponseEntity.ok(dto);
    }
}
