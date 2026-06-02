package com.example.prosper.model;

import java.io.Serializable;
import java.util.Objects;

public class ReviewViewPK implements Serializable {
    private Long userId;
    private Long reviewId;

    public ReviewViewPK() {}
    public ReviewViewPK(Long userId, Long reviewId) {
        this.userId = userId;
        this.reviewId = reviewId;
    }

    public Long getUserId() { return userId; }
    public Long getReviewId() { return reviewId; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof ReviewViewPK)) return false;
        ReviewViewPK that = (ReviewViewPK) o;
        return Objects.equals(userId, that.userId) && Objects.equals(reviewId, that.reviewId);
    }

    @Override
    public int hashCode() { return Objects.hash(userId, reviewId); }
}
