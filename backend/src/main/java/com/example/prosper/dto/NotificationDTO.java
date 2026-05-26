package com.example.prosper.dto;

import java.time.LocalDateTime;

import com.example.prosper.model.NotificationType;

public class NotificationDTO {
    private Long id;
    private NotificationType type;
    private String title;
    private String message;
    private Long bookId;
    private String bookTitle;
    private String bookCoverUrl;
    private Long chapterId;
    private Integer chapterOrder;
    private Long commentId;
    private String commentAuthor;
    private boolean isRead;
    private LocalDateTime createdAt;

    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public NotificationType getType() { return type; }
    public void setType(NotificationType type) { this.type = type; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public Long getBookId() { return bookId; }
    public void setBookId(Long bookId) { this.bookId = bookId; }

    public String getBookTitle() { return bookTitle; }
    public void setBookTitle(String bookTitle) { this.bookTitle = bookTitle; }

    public String getBookCoverUrl() { return bookCoverUrl; }
    public void setBookCoverUrl(String bookCoverUrl) { this.bookCoverUrl = bookCoverUrl; }

    public Long getChapterId() { return chapterId; }
    public void setChapterId(Long chapterId) { this.chapterId = chapterId; }

    public Integer getChapterOrder() { return chapterOrder; }
    public void setChapterOrder(Integer chapterOrder) { this.chapterOrder = chapterOrder; }

    public Long getCommentId() { return commentId; }
    public void setCommentId(Long commentId) { this.commentId = commentId; }

    public String getCommentAuthor() { return commentAuthor; }
    public void setCommentAuthor(String commentAuthor) { this.commentAuthor = commentAuthor; }

    public boolean isRead() { return isRead; }
    public void setRead(boolean read) { isRead = read; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
