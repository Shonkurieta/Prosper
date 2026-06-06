package com.example.prosper.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import com.example.prosper.model.Notification;
import com.example.prosper.model.User;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {
    List<Notification> findByRecipientOrderByCreatedAtDesc(User recipient);
    List<Notification> findByRecipientAndIsReadFalseOrderByCreatedAtDesc(User recipient);
    long countByRecipientAndIsReadFalse(User recipient);
    void deleteByRecipient(User recipient);

    @Modifying
    @Transactional
    @Query("DELETE FROM Notification n WHERE n.book.id = :bookId")
    void deleteByBookId(@Param("bookId") Long bookId);

    @Modifying
    @Transactional
    @Query("DELETE FROM Notification n WHERE n.chapter.id IN :chapterIds")
    void deleteByChapterIdIn(@Param("chapterIds") List<Long> chapterIds);
}
