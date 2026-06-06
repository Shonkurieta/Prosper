package com.example.prosper.repository;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.prosper.model.Book;

import java.util.List;

@Repository
public interface BookRepository extends JpaRepository<Book, Long> {
    List<Book> findByTitleContainingIgnoreCase(String title);

    List<Book> findAllByOrderByIdDesc(Pageable pageable);

    @Query("SELECT b FROM Book b WHERE LOWER(b.title) LIKE LOWER(CONCAT('%', :query, '%')) OR LOWER(b.author) LIKE LOWER(CONCAT('%', :query, '%'))")
    List<Book> searchByTitleOrAuthor(@Param("query") String query);

    @Query("SELECT b FROM Book b ORDER BY COALESCE((SELECT AVG(r.rating) FROM BookRating r WHERE r.book = b), 0.0) DESC")
    List<Book> findAllOrderByAvgRatingDesc();

    @Query("SELECT b FROM Book b ORDER BY (SELECT COUNT(c) FROM Chapter c WHERE c.book = b) DESC")
    List<Book> findAllOrderByChapterCountDesc();

    List<Book> findAllByOrderByTitleAsc();

    List<Book> findAllByOrderByTitleDesc();

    @Query(value = "SELECT * FROM books WHERE similarity(title, :query) > 0.25 ORDER BY similarity(title, :query) DESC LIMIT 1", nativeQuery = true)
    List<Book> findByTitleSimilarity(@Param("query") String query);
}
