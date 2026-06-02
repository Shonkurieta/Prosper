package com.example.prosper.repository;

import com.example.prosper.model.CommentLike;
import com.example.prosper.model.CommentLikePK;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CommentLikeRepository extends JpaRepository<CommentLike, CommentLikePK> {
    Optional<CommentLike> findByUserIdAndCommentId(Long userId, Long commentId);
    int countByCommentIdAndLiked(Long commentId, boolean liked);
    void deleteByUserIdAndCommentId(Long userId, Long commentId);

    @Query("SELECT cl.commentId, COUNT(CASE WHEN cl.liked = true THEN 1 END), COUNT(CASE WHEN cl.liked = false THEN 1 END) FROM CommentLike cl WHERE cl.commentId IN :ids GROUP BY cl.commentId")
    List<Object[]> aggregateByCommentIds(@Param("ids") List<Long> ids);

    @Query("SELECT cl FROM CommentLike cl WHERE cl.userId = :userId AND cl.commentId IN :ids")
    List<CommentLike> findByUserIdAndCommentIdIn(@Param("userId") Long userId, @Param("ids") List<Long> ids);
}
