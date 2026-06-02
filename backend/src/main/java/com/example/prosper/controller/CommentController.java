package com.example.prosper.controller;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import com.example.prosper.model.Comment;
import com.example.prosper.model.CommentLike;
import com.example.prosper.model.User;
import com.example.prosper.repository.CommentLikeRepository;
import com.example.prosper.repository.UserRepository;
import com.example.prosper.service.CommentService;

@RestController
@RequestMapping("/api/comments")
public class CommentController {

    @Autowired
    private CommentService commentService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CommentLikeRepository commentLikeRepository;

    private Long resolveUserId(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()
                || "anonymousUser".equals(authentication.getPrincipal())) {
            return null;
        }
        return userRepository.findByNickname(authentication.getName())
                .map(User::getId).orElse(null);
    }

    private void enrichComments(List<Comment> comments, Long userId) {
        if (comments.isEmpty()) return;

        List<Long> ids = comments.stream().map(Comment::getId).collect(Collectors.toList());

        Map<Long, long[]> counts = new HashMap<>();
        for (Object[] row : commentLikeRepository.aggregateByCommentIds(ids)) {
            long commentId = ((Number) row[0]).longValue();
            long likes = ((Number) row[1]).longValue();
            long dislikes = ((Number) row[2]).longValue();
            counts.put(commentId, new long[]{likes, dislikes});
        }

        Map<Long, Boolean> userReactions = new HashMap<>();
        if (userId != null) {
            commentLikeRepository.findByUserIdAndCommentIdIn(userId, ids)
                .forEach(cl -> userReactions.put(cl.getCommentId(), cl.isLiked()));
        }

        for (Comment c : comments) {
            long[] cnt = counts.getOrDefault(c.getId(), new long[]{0, 0});
            c.setLikeCount((int) cnt[0]);
            c.setDislikeCount((int) cnt[1]);
            if (userId != null) {
                c.setUserLikeStatus(userReactions.getOrDefault(c.getId(), null));
            }
        }
    }

    @GetMapping("/chapter/{chapterId}")
    public ResponseEntity<List<Comment>> getCommentsForChapter(
            @PathVariable Long chapterId, Authentication authentication) {
        List<Comment> comments = commentService.getCommentsByChapterId(chapterId);
        enrichComments(comments, resolveUserId(authentication));
        return ResponseEntity.ok(comments);
    }

    @GetMapping("/book/{bookId}")
    public ResponseEntity<List<Comment>> getCommentsForBook(
            @PathVariable Long bookId, Authentication authentication) {
        List<Comment> comments = commentService.getCommentsByBookId(bookId);
        enrichComments(comments, resolveUserId(authentication));
        return ResponseEntity.ok(comments);
    }

    @PostMapping
    public ResponseEntity<Comment> addComment(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody Map<String, Object> payload) {
        User user = userRepository.findByNickname(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));

        Long bookId = ((Number) payload.get("bookId")).longValue();
        Long chapterId = payload.get("chapterId") != null ? ((Number) payload.get("chapterId")).longValue() : null;
        String content = (String) payload.get("content");
        Long parentCommentId = payload.get("parentCommentId") != null ? ((Number) payload.get("parentCommentId")).longValue() : null;
        String replyToNickname = payload.get("replyToNickname") != null ? (String) payload.get("replyToNickname") : null;

        Comment newComment = commentService.addComment(user.getId(), bookId, chapterId, parentCommentId, content, replyToNickname);
        return new ResponseEntity<>(newComment, HttpStatus.CREATED);
    }

    @DeleteMapping("/{commentId}")
    public ResponseEntity<Void> deleteComment(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long commentId) {
        User user = userRepository.findByNickname(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));

        commentService.deleteComment(commentId, user.getId());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/like")
    @Transactional
    public ResponseEntity<?> toggleLike(
            @PathVariable Long id,
            @RequestBody Map<String, Object> payload,
            Authentication authentication) {
        try {
            Long userId = resolveUserId(authentication);
            if (userId == null) return ResponseEntity.status(401).body(Map.of("message", "Unauthorized"));

            boolean isLike = Boolean.parseBoolean(payload.get("isLike").toString());
            Optional<CommentLike> existing = commentLikeRepository.findByUserIdAndCommentId(userId, id);

            if (existing.isPresent()) {
                CommentLike cl = existing.get();
                if (cl.isLiked() == isLike) {
                    commentLikeRepository.deleteByUserIdAndCommentId(userId, id);
                    return ResponseEntity.ok(Map.of("userLikeStatus", "null"));
                } else {
                    cl.setLiked(isLike);
                    commentLikeRepository.save(cl);
                    return ResponseEntity.ok(Map.of("userLikeStatus", String.valueOf(isLike)));
                }
            } else {
                commentLikeRepository.save(new CommentLike(userId, id, isLike));
                return ResponseEntity.ok(Map.of("userLikeStatus", String.valueOf(isLike)));
            }
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }
}
