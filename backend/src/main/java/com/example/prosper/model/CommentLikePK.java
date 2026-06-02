package com.example.prosper.model;

import java.io.Serializable;
import java.util.Objects;

public class CommentLikePK implements Serializable {
    private Long userId;
    private Long commentId;

    public CommentLikePK() {}
    public CommentLikePK(Long userId, Long commentId) {
        this.userId = userId;
        this.commentId = commentId;
    }

    public Long getUserId() { return userId; }
    public Long getCommentId() { return commentId; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof CommentLikePK)) return false;
        CommentLikePK that = (CommentLikePK) o;
        return Objects.equals(userId, that.userId) && Objects.equals(commentId, that.commentId);
    }

    @Override
    public int hashCode() { return Objects.hash(userId, commentId); }
}
