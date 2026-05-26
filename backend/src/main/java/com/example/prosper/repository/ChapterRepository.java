package com.example.prosper.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.prosper.model.Chapter;

@Repository
public interface ChapterRepository extends JpaRepository<Chapter, Long> {
    List<Chapter> findByBookIdOrderByChapterOrderAsc(Long bookId);
    Optional<Chapter> findByBookIdAndChapterOrder(Long bookId, int chapterOrder);

    @Query(value = "SELECT * FROM chapters WHERE book_id = :bookId AND search_vector @@ to_tsquery('russian', :query) ORDER BY ts_rank(search_vector, to_tsquery('russian', :query)) DESC LIMIT 5", nativeQuery = true)
    List<Chapter> searchChaptersByFts(@Param("bookId") Long bookId, @Param("query") String query);
}