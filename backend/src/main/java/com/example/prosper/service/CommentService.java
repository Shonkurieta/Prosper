package com.example.prosper.service;

import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.prosper.model.Book;
import com.example.prosper.model.Chapter;
import com.example.prosper.model.Comment;
import com.example.prosper.model.Notification;
import com.example.prosper.model.NotificationType;
import com.example.prosper.model.User;
import com.example.prosper.repository.BookRepository;
import com.example.prosper.repository.ChapterRepository;
import com.example.prosper.repository.CommentRepository;
import com.example.prosper.repository.NotificationRepository;
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

    @Autowired
    private NotificationRepository notificationRepository;

    public List<Comment> getCommentsByChapterId(Long chapterId) {
        return commentRepository.findByChapterIdOrderByCreatedAtAsc(chapterId);
    }

    public List<Comment> getCommentsByBookId(Long bookId) {
        return commentRepository.findByBookIdAndChapterIsNullOrderByCreatedAtAsc(bookId);
    }

    public Optional<Comment> getCommentById(Long commentId) {
        return commentRepository.findById(commentId);
    }

    @Transactional
    public Comment addComment(Long userId, Long bookId, Long chapterId, Long parentCommentId, String content, String replyToNickname) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Book book = bookRepository.findById(bookId)
                .orElseThrow(() -> new RuntimeException("Book not found"));

        Chapter chapter = null;
        if (chapterId != null) {
            chapter = chapterRepository.findById(chapterId)
                    .orElseThrow(() -> new RuntimeException("Chapter not found"));
        }

        Comment parentComment = null;
        if (parentCommentId != null) {
            parentComment = commentRepository.findById(parentCommentId)
                    .orElseThrow(() -> new RuntimeException("Parent comment not found"));
        }

        Comment newComment = new Comment(user, book, chapter, parentComment, content);
        if (replyToNickname != null && !replyToNickname.isBlank()) {
            newComment.setReplyToNickname(replyToNickname);
        }
        Comment savedComment = commentRepository.save(newComment);

        if (parentComment != null) {
            // Notify the person being replied to: replyToNickname if set (reply-to-reply),
            // otherwise the root comment author.
            User notifyUser = parentComment.getUser();
            if (replyToNickname != null && !replyToNickname.isBlank()) {
                notifyUser = userRepository.findByNickname(replyToNickname).orElse(notifyUser);
            }
            if (!notifyUser.getId().equals(userId)) {
                Notification notification = new Notification();
                notification.setRecipient(notifyUser);
                notification.setType(NotificationType.COMMENT_REPLY);
                notification.setTitle("Новый ответ!");
                notification.setMessage(user.getNickname() + " ответил на ваш комментарий");
                notification.setBook(book);
                notification.setComment(savedComment);
                notificationRepository.save(notification);
            }
        }

        return savedComment;
    }

    @Transactional
    public void deleteComment(Long commentId, Long userId) {
        Comment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new RuntimeException("Comment not found"));

        if (!comment.getUser().getId().equals(userId)) {
            throw new RuntimeException("Not authorized to delete this comment");
        }

        // No longer need to manually delete notifications if cascade delete is not used, 
        // but let's just delete by comment for safety if needed. 
        // Actually, let's keep it simple and just remove the old repository calls.

        commentRepository.delete(comment);
    }

    public List<Comment> getRepliesForComment(Long parentCommentId) {
        return commentRepository.findByParentCommentIdOrderByCreatedAtAsc(parentCommentId);
    }
}