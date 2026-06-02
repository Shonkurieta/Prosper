package com.example.prosper.controller;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.prosper.dto.ChapterDTO;
import com.example.prosper.dto.RecentChapterDTO;
import com.example.prosper.model.Book;
import com.example.prosper.model.Chapter;
import com.example.prosper.repository.BookRepository;
import com.example.prosper.repository.ChapterRepository;

@RestController
@RequestMapping("/api/books")
@CrossOrigin(origins = "*")
public class BookController {

    @Autowired
    private BookRepository bookRepository;

    @Autowired
    private ChapterRepository chapterRepository;

    @GetMapping
    public ResponseEntity<List<Book>> getAllBooks() {
        return ResponseEntity.ok(bookRepository.findAll());
    }

    @GetMapping("/newest")
    public ResponseEntity<List<Book>> getNewestBooks(
            @RequestParam(defaultValue = "6") int limit) {
        return ResponseEntity.ok(bookRepository.findAllByOrderByIdDesc(PageRequest.of(0, limit)));
    }

    @GetMapping("/search")
    public ResponseEntity<List<Book>> searchBooks(
            @RequestParam(required = false, defaultValue = "") String query) {
        if (query == null || query.trim().isEmpty()) {
            return ResponseEntity.ok(bookRepository.findAll());
        }
        return ResponseEntity.ok(bookRepository.searchByTitleOrAuthor(query));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Book> getBookById(@PathVariable Long id) {
        return bookRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{bookId}/chapters")
    public ResponseEntity<List<ChapterDTO>> getBookChapters(@PathVariable Long bookId) {
        List<Chapter> chapters = chapterRepository.findByBookIdOrderByChapterOrderAsc(bookId);
        List<ChapterDTO> chapterDTOs = chapters.stream()
                .map(ch -> new ChapterDTO(ch.getId(), ch.getchapterOrder(), ch.getTitle(), null))
                .collect(Collectors.toList());
        return ResponseEntity.ok(chapterDTOs);
    }

    @GetMapping("/{bookId}/chapters/{chapterOrder}")
    public ResponseEntity<ChapterDTO> getChapter(
            @PathVariable Long bookId,
            @PathVariable int chapterOrder) {
        return chapterRepository.findByBookIdAndChapterOrder(bookId, chapterOrder)
                .map(ch -> ResponseEntity.ok(new ChapterDTO(
                        ch.getId(), ch.getchapterOrder(), ch.getTitle(), ch.getContent())))
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/chapters/recent")
    public ResponseEntity<List<RecentChapterDTO>> getRecentChapters(
            @RequestParam(defaultValue = "20") int limit) {
        // JPQL query fetches only summary fields (no content), sorted by id desc
        List<RecentChapterDTO> all = chapterRepository.findAllSummariesOrderByIdDesc();

        // Keep only the latest chapter per book (first occurrence wins — already sorted by id desc)
        Map<Long, RecentChapterDTO> latestByBook = new LinkedHashMap<>();
        for (RecentChapterDTO ch : all) {
            latestByBook.putIfAbsent(ch.getBookId(), ch);
        }

        List<RecentChapterDTO> result = latestByBook.values().stream()
                .limit(limit)
                .collect(Collectors.toList());
        return ResponseEntity.ok(result);
    }
}
