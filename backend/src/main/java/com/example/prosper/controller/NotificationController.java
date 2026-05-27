package com.example.prosper.controller;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.prosper.dto.NotificationDTO;
import com.example.prosper.model.Notification;
import com.example.prosper.model.User;
import com.example.prosper.repository.NotificationRepository;
import com.example.prosper.repository.UserRepository;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private UserRepository userRepository;

    private User getCurrentUser(UserDetails userDetails) {
        if (userDetails == null) return null;
        return userRepository.findByNickname(userDetails.getUsername()).orElse(null);
    }

    @GetMapping
    @Transactional(readOnly = true)
    public ResponseEntity<List<NotificationDTO>> getNotifications(@AuthenticationPrincipal UserDetails userDetails) {
        User user = getCurrentUser(userDetails);
        if (user == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        return ResponseEntity.ok(notificationRepository.findByRecipientOrderByCreatedAtDesc(user)
                .stream().map(this::convertToDTO).collect(Collectors.toList()));
    }

    @GetMapping("/unread-count")
    public ResponseEntity<Long> getUnreadCount(@AuthenticationPrincipal UserDetails userDetails) {
        User user = getCurrentUser(userDetails);
        if (user == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        return ResponseEntity.ok(notificationRepository.countByRecipientAndIsReadFalse(user));
    }

    @PutMapping("/{id}/read")
    public ResponseEntity<Void> markAsRead(@PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails) {
        User user = getCurrentUser(userDetails);
        if (user == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        Notification notification = notificationRepository.findById(id).orElse(null);
        if (notification == null || !notification.getRecipient().getId().equals(user.getId())) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }

        notification.setRead(true);
        notificationRepository.save(notification);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/read-all")
    @Transactional
    public ResponseEntity<Void> markAllAsRead(@AuthenticationPrincipal UserDetails userDetails) {
        User user = getCurrentUser(userDetails);
        if (user == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        List<Notification> notifications = notificationRepository.findByRecipientAndIsReadFalseOrderByCreatedAtDesc(user);
        notifications.forEach(n -> n.setRead(true));
        notificationRepository.saveAll(notifications);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteNotification(@PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails) {
        User user = getCurrentUser(userDetails);
        if (user == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        Notification notification = notificationRepository.findById(id).orElse(null);
        if (notification == null || !notification.getRecipient().getId().equals(user.getId())) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }

        notificationRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/all")
    @Transactional
    public ResponseEntity<Void> deleteAllNotifications(@AuthenticationPrincipal UserDetails userDetails) {
        User user = getCurrentUser(userDetails);
        if (user == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        notificationRepository.deleteByRecipient(user);
        return ResponseEntity.ok().build();
    }

    private NotificationDTO convertToDTO(Notification n) {
        NotificationDTO dto = new NotificationDTO();
        dto.setId(n.getId());
        dto.setType(n.getType());
        dto.setTitle(n.getTitle());
        dto.setMessage(n.getMessage());
        dto.setRead(n.isRead());
        dto.setCreatedAt(n.getCreatedAt());
        
        if (n.getBook() != null) {
            dto.setBookId(n.getBook().getId());
            dto.setBookTitle(n.getBook().getTitle());
            dto.setBookCoverUrl(n.getBook().getCoverUrl());
        }
        
        if (n.getChapter() != null) {
            dto.setChapterId(n.getChapter().getId());
            dto.setChapterOrder(n.getChapter().getchapterOrder());
        }
        
        if (n.getComment() != null) {
            dto.setCommentId(n.getComment().getId());
            dto.setCommentAuthor(n.getComment().getUser().getNickname());
        }
        
        return dto;
    }
}
