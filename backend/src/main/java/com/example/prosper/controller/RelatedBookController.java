package com.example.prosper.controller;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.prosper.dto.RelatedBookDTO;
import com.example.prosper.model.Book;
import com.example.prosper.model.RelatedBook;
import com.example.prosper.model.RelatedBook.RelationType;
import com.example.prosper.repository.BookRepository;
import com.example.prosper.repository.RelatedBookRepository;

@RestController
@RequestMapping("/api/related-books")
@CrossOrigin(origins = "*")
public class RelatedBookController {

    @Autowired
    private RelatedBookRepository relatedBookRepository;

    @Autowired
    private BookRepository bookRepository;

    @GetMapping("/{bookId}")
    public ResponseEntity<List<RelatedBookDTO>> getRelatedBooks(@PathVariable Long bookId) {
        List<RelatedBook> relatedBooks = relatedBookRepository.findByBookId(bookId);
        List<RelatedBookDTO> dtos = relatedBooks.stream()
                .map(RelatedBookDTO::new)
                .collect(Collectors.toList());
        return ResponseEntity.ok(dtos);
    }

    @PostMapping
    public ResponseEntity<?> createRelatedBook(
            @RequestBody RelatedBookDTO dto) {
        try {
            Book book = bookRepository.findById(dto.getBookId())
                    .orElseThrow(() -> new RuntimeException("Book not found: " + dto.getBookId()));
            Book relatedBook = bookRepository.findById(dto.getRelatedBookId())
                    .orElseThrow(() -> new RuntimeException("Related book not found: " + dto.getRelatedBookId()));

            RelationType relationType = RelationType.valueOf(dto.getRelationType());
            
            RelatedBook newRelation = new RelatedBook(book, relatedBook, relationType);
            RelatedBook saved = relatedBookRepository.save(newRelation);
            
            return ResponseEntity.status(HttpStatus.CREATED).body(new RelatedBookDTO(saved));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @DeleteMapping("/{bookId}/{relatedBookId}")
    public ResponseEntity<?> deleteRelatedBook(
            @PathVariable Long bookId,
            @PathVariable Long relatedBookId) {
        try {
            relatedBookRepository.deleteByBookIdAndRelatedBookId(bookId, relatedBookId);
            return ResponseEntity.ok("Related book deleted successfully");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }


    @PutMapping("/{id}")
    public ResponseEntity<?> updateRelatedBook(
            @PathVariable Long id,
            @RequestBody RelatedBookDTO dto) {
        try {
            RelatedBook relatedBook = relatedBookRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("Related book not found"));
            
            RelationType relationType = RelationType.valueOf(dto.getRelationType());
            relatedBook.setRelationType(relationType);
            
            RelatedBook updated = relatedBookRepository.save(relatedBook);
            return ResponseEntity.ok(new RelatedBookDTO(updated));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }
}
