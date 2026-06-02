package com.example.prosper.model;

import jakarta.persistence.*;

@Entity
@Table(name = "comment_likes")
@IdClass(CommentLikePK.class)
public class CommentLike {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Id
    @Column(name = "comment_id")
    private Long commentId;

    @Column(name = "is_like", nullable = false)
    private boolean liked;

    public CommentLike() {}

    public CommentLike(Long userId, Long commentId, boolean liked) {
        this.userId = userId;
        this.commentId = commentId;
        this.liked = liked;
    }

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public Long getCommentId() { return commentId; }
    public void setCommentId(Long commentId) { this.commentId = commentId; }

    public boolean isLiked() { return liked; }
    public void setLiked(boolean liked) { this.liked = liked; }
}
