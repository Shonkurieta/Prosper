package com.example.prosper.model;

import java.io.Serializable;
import java.util.Objects;

public class ReviewLikePK implements Serializable {
    private Long userId;
    private Long reviewId;

    public ReviewLikePK() {}
    public ReviewLikePK(Long userId, Long reviewId) {
        this.userId = userId;
        this.reviewId = reviewId;
    }

    public Long getUserId() { return userId; }
    public Long getReviewId() { return reviewId; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof ReviewLikePK)) return false;
        ReviewLikePK that = (ReviewLikePK) o;
        return Objects.equals(userId, that.userId) && Objects.equals(reviewId, that.reviewId);
    }

    @Override
    public int hashCode() { return Objects.hash(userId, reviewId); }
}
