package com.example.prosper.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import com.example.prosper.model.Book;
import com.example.prosper.model.BookRating;
import com.example.prosper.model.User;

public interface BookRatingRepository extends JpaRepository<BookRating, Long> {

    Optional<BookRating> findByUserAndBook(User user, Book book);

    @Query("SELECT AVG(r.rating) FROM BookRating r WHERE r.book.id = :bookId")
    Double getAverageRatingByBookId(@Param("bookId") Long bookId);

    long countByBookId(Long bookId);

    /** Возвращает [book_id, avg_rating] для всех книг за один запрос */
    @Query("SELECT r.book.id, AVG(r.rating) FROM BookRating r GROUP BY r.book.id")
    List<Object[]> getAverageRatingsForAllBooks();

    @Modifying
    @Transactional
    @Query("DELETE FROM BookRating r WHERE r.book.id = :bookId")
    void deleteByBookId(@Param("bookId") Long bookId);
}
