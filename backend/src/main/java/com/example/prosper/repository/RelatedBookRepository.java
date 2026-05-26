package com.example.prosper.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.prosper.model.RelatedBook;

import java.util.List;

@Repository
public interface RelatedBookRepository extends JpaRepository<RelatedBook, Long> {
    List<RelatedBook> findByBookId(Long bookId);
    List<RelatedBook> findByRelatedBookId(Long relatedBookId);
    void deleteByBookIdAndRelatedBookId(Long bookId, Long relatedBookId);
}
