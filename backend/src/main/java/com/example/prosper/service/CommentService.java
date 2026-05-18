package com.example.prosper.service;

import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.prosper.model.Book;
import com.example.prosper.model.Chapter;
import com.example.prosper.model.Comment;
import com.example.prosper.model.User;
import com.example.prosper.repository.BookRepository;
import com.example.prosper.repository.ChapterRepository;
import com.example.prosper.repository.CommentRepository;
import com.example.prosper.repository.UserRepository;

@Service
public class CommentService {

    @Autowired
    private CommentRepository commentRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private BookRepository bookRepository;

    @Autowired
    private ChapterRepository chapterRepository;

    public List<Comment> getCommentsByChapterId(Long chapterId) {
        // Возвращаем ВСЕ комментарии включая ответы
        return commentRepository.findByChapterIdOrderByCreatedAtAsc(chapterId);
    }

    public Optional<Comment> getCommentById(Long commentId) {
        return commentRepository.findById(commentId);
    }

    @Transactional
    public Comment addComment(Long userId, Long bookId, Long chapterId, Long parentCommentId, String content) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Book book = bookRepository.findById(bookId)
                .orElseThrow(() -> new RuntimeException("Book not found"));

        Chapter chapter = chapterRepository.findById(chapterId)
                .orElseThrow(() -> new RuntimeException("Chapter not found"));

        Comment parentComment = null;
        if (parentCommentId != null) {
            parentComment = commentRepository.findById(parentCommentId)
                    .orElseThrow(() -> new RuntimeException("Parent comment not found"));
        }

        Comment comment = new Comment(user, book, chapter, parentComment, content);
        return commentRepository.save(comment);
    }

    @Transactional
    public void deleteComment(Long commentId, Long userId) {
        Comment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new RuntimeException("Comment not found"));

        if (!comment.getUser().getId().equals(userId)) {
            throw new RuntimeException("Not authorized to delete this comment");
        }

        commentRepository.delete(comment);
    }

    public List<Comment> getRepliesForComment(Long parentCommentId) {
        return commentRepository.findByParentCommentIdOrderByCreatedAtAsc(parentCommentId);
    }
}