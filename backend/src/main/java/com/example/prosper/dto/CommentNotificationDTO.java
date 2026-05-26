package com.example.prosper.dto;

import java.time.LocalDateTime;

public class CommentNotificationDTO {
    private Long id;
    private String recipientUsername;
    private Long commentId;
    private String commentContent;
    private String commentAuthor;
    private Long parentCommentId;
    private String parentCommentContent;
    private Long bookId;
    private String bookTitle;
    private String bookCoverUrl;
    private boolean isRead;
    private LocalDateTime createdAt;

    public CommentNotificationDTO() {}

    public CommentNotificationDTO(Long id, String recipientUsername, Long commentId, String commentContent,
                                   String commentAuthor, Long parentCommentId, String parentCommentContent,
                                   Long bookId, String bookTitle, String bookCoverUrl, boolean isRead, LocalDateTime createdAt) {
        this.id = id;
        this.recipientUsername = recipientUsername;
        this.commentId = commentId;
        this.commentContent = commentContent;
        this.commentAuthor = commentAuthor;
        this.parentCommentId = parentCommentId;
        this.parentCommentContent = parentCommentContent;
        this.bookId = bookId;
        this.bookTitle = bookTitle;
        this.bookCoverUrl = bookCoverUrl;
        this.isRead = isRead;
        this.createdAt = createdAt;
    }

    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getRecipientUsername() { return recipientUsername; }
    public void setRecipientUsername(String recipientUsername) { this.recipientUsername = recipientUsername; }

    public Long getCommentId() { return commentId; }
    public void setCommentId(Long commentId) { this.commentId = commentId; }

    public String getCommentContent() { return commentContent; }
    public void setCommentContent(String commentContent) { this.commentContent = commentContent; }

    public String getCommentAuthor() { return commentAuthor; }
    public void setCommentAuthor(String commentAuthor) { this.commentAuthor = commentAuthor; }

    public Long getParentCommentId() { return parentCommentId; }
    public void setParentCommentId(Long parentCommentId) { this.parentCommentId = parentCommentId; }

    public String getParentCommentContent() { return parentCommentContent; }
    public void setParentCommentContent(String parentCommentContent) { this.parentCommentContent = parentCommentContent; }

    public Long getBookId() { return bookId; }
    public void setBookId(Long bookId) { this.bookId = bookId; }

    public String getBookTitle() { return bookTitle; }
    public void setBookTitle(String bookTitle) { this.bookTitle = bookTitle; }

    public String getBookCoverUrl() { return bookCoverUrl; }
    public void setBookCoverUrl(String bookCoverUrl) { this.bookCoverUrl = bookCoverUrl; }

    public boolean isRead() { return isRead; }
    public void setRead(boolean read) { isRead = read; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
