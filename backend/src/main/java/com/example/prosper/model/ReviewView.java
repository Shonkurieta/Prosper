package com.example.prosper.model;

import java.time.LocalDateTime;
import jakarta.persistence.*;

@Entity
@Table(name = "review_views")
@IdClass(ReviewViewPK.class)
public class ReviewView {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Id
    @Column(name = "review_id")
    private Long reviewId;

    @Column(name = "viewed_at")
    private LocalDateTime viewedAt;

    public ReviewView() { this.viewedAt = LocalDateTime.now(); }

    public ReviewView(Long userId, Long reviewId) {
        this.userId = userId;
        this.reviewId = reviewId;
        this.viewedAt = LocalDateTime.now();
    }

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public Long getReviewId() { return reviewId; }
    public void setReviewId(Long reviewId) { this.reviewId = reviewId; }

    public LocalDateTime getViewedAt() { return viewedAt; }
    public void setViewedAt(LocalDateTime viewedAt) { this.viewedAt = viewedAt; }
}
