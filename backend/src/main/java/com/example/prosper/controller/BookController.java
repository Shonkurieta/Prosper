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
import com.example.prosper.repository.BookRatingRepository;
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

    @Autowired
    private BookRatingRepository bookRatingRepository;

    // Строит Map<bookId, avgRating> за один SQL-запрос
    private Map<Long, Double> loadAvgRatings() {
        return bookRatingRepository.getAverageRatingsForAllBooks()
                .stream()
                .collect(Collectors.toMap(
                        row -> (Long) row[0],
                        row -> Math.round((Double) row[1] * 10.0) / 10.0
                ));
    }

    // Превращает Book в Map и добавляет поле averageRating
    private Map<String, Object> toMap(Book book, Map<Long, Double> avgRatings) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id",            book.getId());
        m.put("title",         book.getTitle());
        m.put("author",        book.getAuthor());
        m.put("description",   book.getDescription());
        m.put("coverUrl",      book.getCoverUrl());
        m.put("genres",        book.getGenres());
        m.put("averageRating", avgRatings.getOrDefault(book.getId(), 0.0));
        return m;
    }

    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> getAllBooks(
            @RequestParam(defaultValue = "rating") String sort) {
        List<Book> books;
        switch (sort) {
            case "chapters":   books = bookRepository.findAllOrderByChapterCountDesc(); break;
            case "title_asc":  books = bookRepository.findAllByOrderByTitleAsc();       break;
            case "title_desc": books = bookRepository.findAllByOrderByTitleDesc();      break;
            default:           books = bookRepository.findAllOrderByAvgRatingDesc();    break;
        }
        Map<Long, Double> avgRatings = loadAvgRatings();
        return ResponseEntity.ok(books.stream()
                .map(b -> toMap(b, avgRatings))
                .collect(Collectors.toList()));
    }

    @GetMapping("/newest")
    public ResponseEntity<List<Map<String, Object>>> getNewestBooks(
            @RequestParam(defaultValue = "6") int limit) {
        List<Book> books = bookRepository.findAllByOrderByIdDesc(PageRequest.of(0, limit));
        Map<Long, Double> avgRatings = loadAvgRatings();
        return ResponseEntity.ok(books.stream()
                .map(b -> toMap(b, avgRatings))
                .collect(Collectors.toList()));
    }

    @GetMapping("/search")
    public ResponseEntity<List<Map<String, Object>>> searchBooks(
            @RequestParam(required = false, defaultValue = "") String query) {
        List<Book> books = (query == null || query.trim().isEmpty())
                ? bookRepository.findAll()
                : bookRepository.searchByTitleOrAuthor(query);
        Map<Long, Double> avgRatings = loadAvgRatings();
        return ResponseEntity.ok(books.stream()
                .map(b -> toMap(b, avgRatings))
                .collect(Collectors.toList()));
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
        List<RecentChapterDTO> all = chapterRepository.findAllSummariesOrderByIdDesc();
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
