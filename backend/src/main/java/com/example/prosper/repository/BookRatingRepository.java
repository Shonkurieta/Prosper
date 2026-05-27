package com.example.prosper.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.example.prosper.model.Book;
import com.example.prosper.model.BookRating;
import com.example.prosper.model.User;

public interface BookRatingRepository extends JpaRepository<BookRating, Long> {

    Optional<BookRating> findByUserAndBook(User user, Book book);

    @Query("SELECT AVG(r.rating) FROM BookRating r WHERE r.book.id = :bookId")
    Double getAverageRatingByBookId(@Param("bookId") Long bookId);

    long countByBookId(Long bookId);
}
