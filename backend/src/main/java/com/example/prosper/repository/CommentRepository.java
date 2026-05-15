package com.example.prosper.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.prosper.model.Comment;

@Repository
public interface CommentRepository extends JpaRepository<Comment, Long> {
    List<Comment> findByChapterIdOrderByCreatedAtAsc(Long chapterId);
    List<Comment> findByChapterIdAndParentCommentIsNullOrderByCreatedAtAsc(Long chapterId);
    List<Comment> findByParentCommentIdOrderByCreatedAtAsc(Long parentCommentId);
}
