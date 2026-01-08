package com.example.prosper.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.prosper.model.Book;
import com.example.prosper.model.BookmarkStatus;
import com.example.prosper.model.User;
import com.example.prosper.model.UserBook;

@Repository
public interface UserBookRepository extends JpaRepository<UserBook, Long> {
    
    Optional<UserBook> findByUserIdAndBookId(Long userId, Long bookId);
    
    List<UserBook> findByUserIdAndBookmarkedTrue(Long userId);
    
    List<UserBook> findByUserIdAndStatusAndBookmarkedTrue(Long userId, BookmarkStatus status);
    
    // Для совместимости со старым кодом
    Optional<UserBook> findByUserAndBook(User user, Book book);
    
    List<UserBook> findByUserAndBookmarkedTrue(User user);
    
    List<UserBook> findByUserAndStatusAndBookmarkedTrue(User user, BookmarkStatus status);
}