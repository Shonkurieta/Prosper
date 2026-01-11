package com.example.prosper.controller;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.prosper.dto.ChapterDTO;
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

    // Получить все новеллы
    @GetMapping
    public ResponseEntity<List<Book>> getAllBooks() {
        return ResponseEntity.ok(bookRepository.findAll());
    }

    // Поиск новелл по названию (параметр query теперь необязательный)
    @GetMapping("/search")
    public ResponseEntity<List<Book>> searchBooks(
            @RequestParam(required = false, defaultValue = "") String query) {
        
        // Если запрос пустой, возвращаем все новеллы
        if (query == null || query.trim().isEmpty()) {
            return ResponseEntity.ok(bookRepository.findAll());
        }

        // Поиск новелл по названию или автору
        List<Book> books = bookRepository.findAll().stream()
                .filter(book -> 
                    book.getTitle().toLowerCase().contains(query.toLowerCase()) ||
                    book.getAuthor().toLowerCase().contains(query.toLowerCase()))
                .collect(Collectors.toList());
        
        return ResponseEntity.ok(books);
    }

    // Получить новеллу по ID с полной информацией
    @GetMapping("/{id}")
    public ResponseEntity<Book> getBookById(@PathVariable Long id) {
        return bookRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    // Получить все главы новеллы
    @GetMapping("/{bookId}/chapters")
    public ResponseEntity<List<ChapterDTO>> getBookChapters(@PathVariable Long bookId) {
        List<Chapter> chapters = chapterRepository.findByBookIdOrderByChapterOrderAsc(bookId);
        List<ChapterDTO> chapterDTOs = chapters.stream()
                .map(ch -> new ChapterDTO(
                        ch.getId(),
                        ch.getchapterOrder(),
                        ch.getTitle(),
                        null // Не отдаём контент в списке глав
                ))
                .collect(Collectors.toList());
        return ResponseEntity.ok(chapterDTOs);
    }

    // Получить конкретную главу с контентом
    @GetMapping("/{bookId}/chapters/{chapterOrder}")
    public ResponseEntity<ChapterDTO> getChapter(
            @PathVariable Long bookId,
            @PathVariable int chapterOrder) {
        return chapterRepository.findByBookIdAndChapterOrder(bookId, chapterOrder)
                .map(ch -> ResponseEntity.ok(new ChapterDTO(
                        ch.getId(),
                        ch.getchapterOrder(),
                        ch.getTitle(),
                        ch.getContent()
                )))
                .orElse(ResponseEntity.notFound().build());
    }
}