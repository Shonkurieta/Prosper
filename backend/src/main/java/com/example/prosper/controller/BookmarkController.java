package com.example.prosper.controller;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.prosper.model.Book;
import com.example.prosper.model.BookmarkStatus;
import com.example.prosper.model.User;
import com.example.prosper.model.UserBook;
import com.example.prosper.repository.BookRepository;
import com.example.prosper.repository.UserBookRepository;
import com.example.prosper.repository.UserRepository;

@RestController
@RequestMapping("/api/bookmarks")
public class BookmarkController {

    @Autowired
    private UserBookRepository userBookRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private BookRepository bookRepository;

    /**
     * Get all bookmarks for current user
     */
    @GetMapping
    public ResponseEntity<List<UserBook>> getBookmarks(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) BookmarkStatus status
    ) {
        User user = userRepository.findByNickname(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (status != null) {
            return ResponseEntity.ok(userBookRepository.findByUserAndStatusAndBookmarkedTrue(user, status));
        }
        return ResponseEntity.ok(userBookRepository.findByUserAndBookmarkedTrue(user));
    }

    /**
     * Get bookmark progress for specific book
     */
    @GetMapping("/progress/{bookId}")
    public ResponseEntity<Map<String, Object>> getProgress(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long bookId
    ) {
        User user = userRepository.findByNickname(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));
        Book book = bookRepository.findById(bookId)
                .orElseThrow(() -> new RuntimeException("Book not found"));

        UserBook userBook = userBookRepository.findByUserAndBook(user, book).orElse(null);

        Map<String, Object> response = new HashMap<>();
        if (userBook != null && userBook.isBookmarked()) {
            response.put("isBookmarked", true);
            response.put("currentChapter", userBook.getCurrentChapter());
            response.put("status", userBook.getStatus().name());
        } else {
            response.put("isBookmarked", false);
            response.put("currentChapter", 1);
            response.put("status", BookmarkStatus.READING.name());
        }
        return ResponseEntity.ok(response);
    }

    /**
     * Add or update bookmark
     */
    @PostMapping("/{bookId}")
    public ResponseEntity<UserBook> addBookmark(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long bookId
    ) {
        User user = userRepository.findByNickname(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));
        Book book = bookRepository.findById(bookId)
                .orElseThrow(() -> new RuntimeException("Book not found"));

        UserBook userBook = userBookRepository.findByUserAndBook(user, book)
                .orElseGet(() -> {
                    UserBook newUserBook = new UserBook();
                    newUserBook.setUser(user);
                    newUserBook.setBook(book);
                    newUserBook.setCurrentChapter(1);
                    newUserBook.setStatus(BookmarkStatus.READING);
                    return newUserBook;
                });

        userBook.setBookmarked(true);
        return ResponseEntity.ok(userBookRepository.save(userBook));
    }

    /**
     * Update bookmark status (READING, COMPLETED, FAVORITE, DROPPED, PLANNED)
     */
    @PutMapping("/{bookmarkId}/status")
    public ResponseEntity<UserBook> updateStatus(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long bookmarkId,
            @RequestBody Map<String, String> request
    ) {
        User user = userRepository.findByNickname(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        UserBook userBook = userBookRepository.findById(bookmarkId)
                .orElseThrow(() -> new RuntimeException("Bookmark not found"));

        if (!userBook.getUser().getId().equals(user.getId())) {
            throw new RuntimeException("Not authorized to update this bookmark");
        }

        String statusStr = request.get("status");
        BookmarkStatus status = BookmarkStatus.valueOf(statusStr);
        userBook.setStatus(status);
        
        return ResponseEntity.ok(userBookRepository.save(userBook));
    }

    /**
     * Update reading progress (создаёт закладку автоматически, если её нет)
     */
    @PutMapping("/{bookId}/progress")
    public ResponseEntity<UserBook> updateProgress(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long bookId,
            @RequestBody(required = false) Map<String, Integer> request
    ) {
        User user = userRepository.findByNickname(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));
        Book book = bookRepository.findById(bookId)
                .orElseThrow(() -> new RuntimeException("Book not found"));

        // Получить существующую закладку или создать новую
        UserBook userBook = userBookRepository.findByUserAndBook(user, book)
                .orElseGet(() -> {
                    System.out.println("📚 Creating new bookmark for user: " + user.getNickname() + ", book: " + book.getTitle());
                    UserBook newUserBook = new UserBook();
                    newUserBook.setUser(user);
                    newUserBook.setBook(book);
                    newUserBook.setBookmarked(true);  // Автоматически добавляем в закладки
                    newUserBook.setStatus(BookmarkStatus.READING);
                    newUserBook.setCurrentChapter(1);
                    return newUserBook;
                });

        // Обновить главу, если передана в запросе
        if (request != null && request.containsKey("currentChapter")) {
            Integer currentChapter = request.get("currentChapter");
            if (currentChapter != null && currentChapter > 0) {
                System.out.println("📖 Updating progress: chapter " + currentChapter);
                userBook.setCurrentChapter(currentChapter);
            }
        } else {
            System.out.println("⚠️ Warning: No currentChapter in request body");
        }
        
        UserBook saved = userBookRepository.save(userBook);
        System.out.println("✅ Progress saved successfully");
        
        return ResponseEntity.ok(saved);
    }

    /**
     * Remove bookmark
     */
    @DeleteMapping("/{bookId}")
    public ResponseEntity<Void> removeBookmark(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long bookId
    ) {
        User user = userRepository.findByNickname(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));
        Book book = bookRepository.findById(bookId)
                .orElseThrow(() -> new RuntimeException("Book not found"));

        UserBook userBook = userBookRepository.findByUserAndBook(user, book)
                .orElseThrow(() -> new RuntimeException("Bookmark not found"));

        userBook.setBookmarked(false);
        userBookRepository.save(userBook);
        
        return ResponseEntity.ok().build();
    }
}