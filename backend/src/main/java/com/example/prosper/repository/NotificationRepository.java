package com.example.prosper.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.prosper.model.Notification;
import com.example.prosper.model.User;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {
    List<Notification> findByRecipientOrderByCreatedAtDesc(User recipient);
    List<Notification> findByRecipientAndIsReadFalseOrderByCreatedAtDesc(User recipient);
    long countByRecipientAndIsReadFalse(User recipient);
    void deleteByRecipient(User recipient);
}
