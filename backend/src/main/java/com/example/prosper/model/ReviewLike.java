package com.example.prosper.model;

import java.time.LocalDateTime;
import jakarta.persistence.*;

@Entity
@Table(name = "review_likes")
@IdClass(ReviewLikePK.class)
public class ReviewLike {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Id
    @Column(name = "review_id")
    private Long reviewId;

    @Column(name = "is_like", nullable = false)
    private boolean liked;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    public ReviewLike() { this.createdAt = LocalDateTime.now(); }

    public ReviewLike(Long userId, Long reviewId, boolean liked) {
        this.userId = userId;
        this.reviewId = reviewId;
        this.liked = liked;
        this.createdAt = LocalDateTime.now();
    }

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public Long getReviewId() { return reviewId; }
    public void setReviewId(Long reviewId) { this.reviewId = reviewId; }

    public boolean isLiked() { return liked; }
    public void setLiked(boolean liked) { this.liked = liked; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
