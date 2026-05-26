package com.example.prosper.controller;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.prosper.dto.CommentNotificationDTO;
import com.example.prosper.model.Comment;
import com.example.prosper.model.CommentNotification;
import com.example.prosper.model.User;
import com.example.prosper.repository.CommentNotificationRepository;
import com.example.prosper.repository.CommentRepository;
import com.example.prosper.repository.UserRepository;
import com.example.prosper.security.JwtTokenProvider;

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/api/comment-notifications")
public class CommentNotificationController {

    @Autowired
    private CommentNotificationRepository commentNotificationRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CommentRepository commentRepository;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    private User getCurrentUser(HttpServletRequest request) {
        String token = request.getHeader("Authorization");
        if (token != null && token.startsWith("Bearer ")) {
            token = token.substring(7);
            String username = jwtTokenProvider.getUsernameFromToken(token);
            return userRepository.findByUsername(username).orElse(null);
        }
        return null;
    }

    @GetMapping
    public ResponseEntity<List<CommentNotificationDTO>> getNotifications(HttpServletRequest request) {
        User user = getCurrentUser(request);
        if (user == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        List<CommentNotification> notifications = commentNotificationRepository.findByRecipientOrderByCreatedAtDesc(user);
        List<CommentNotificationDTO> dtos = notifications.stream()
                .map(this::convertToDTO)
                .collect(Collectors.toList());

        return ResponseEntity.ok(dtos);
    }

    @GetMapping("/unread")
    public ResponseEntity<List<CommentNotificationDTO>> getUnreadNotifications(HttpServletRequest request) {
        User user = getCurrentUser(request);
        if (user == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        List<CommentNotification> notifications = commentNotificationRepository.findByRecipientAndIsReadFalseOrderByCreatedAtDesc(user);
        List<CommentNotificationDTO> dtos = notifications.stream()
                .map(this::convertToDTO)
                .collect(Collectors.toList());

        return ResponseEntity.ok(dtos);
    }

    @GetMapping("/unread-count")
    public ResponseEntity<Long> getUnreadCount(HttpServletRequest request) {
        User user = getCurrentUser(request);
        if (user == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        long count = commentNotificationRepository.countByRecipientAndIsReadFalse(user);
        return ResponseEntity.ok(count);
    }

    @PutMapping("/{id}/read")
    public ResponseEntity<Void> markAsRead(@PathVariable Long id, HttpServletRequest request) {
        User user = getCurrentUser(request);
        if (user == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        CommentNotification notification = commentNotificationRepository.findById(id).orElse(null);
        if (notification == null || !notification.getRecipient().getId().equals(user.getId())) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }

        notification.setRead(true);
        commentNotificationRepository.save(notification);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteNotification(@PathVariable Long id, HttpServletRequest request) {
        User user = getCurrentUser(request);
        if (user == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        CommentNotification notification = commentNotificationRepository.findById(id).orElse(null);
        if (notification == null || !notification.getRecipient().getId().equals(user.getId())) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }

        commentNotificationRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }

    private CommentNotificationDTO convertToDTO(CommentNotification notification) {
        Comment comment = notification.getComment();
        Comment parentComment = notification.getParentComment();

        return new CommentNotificationDTO(
                notification.getId(),
                notification.getRecipient().getUsername(),
                comment.getId(),
                comment.getContent(),
                comment.getUser().getUsername(),
                parentComment != null ? parentComment.getId() : null,
                parentComment != null ? parentComment.getContent() : null,
                comment.getBook() != null ? comment.getBook().getId() : null,
                comment.getBook() != null ? comment.getBook().getTitle() : null,
                comment.getBook() != null ? comment.getBook().getCoverUrl() : null,
                notification.isRead(),
                notification.getCreatedAt()
        );
    }
}
