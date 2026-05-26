package com.example.prosper.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.prosper.model.CommentNotification;
import com.example.prosper.model.User;

@Repository
public interface CommentNotificationRepository extends JpaRepository<CommentNotification, Long> {
    List<CommentNotification> findByRecipientOrderByCreatedAtDesc(User recipient);
    List<CommentNotification> findByRecipientAndIsReadFalseOrderByCreatedAtDesc(User recipient);
    long countByRecipientAndIsReadFalse(User recipient);
    void deleteByRecipientAndComment(User recipient, Long commentId);
}
