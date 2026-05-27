package com.example.prosper.controller;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.prosper.model.Comment;
import com.example.prosper.model.User;
import com.example.prosper.repository.UserRepository;
import com.example.prosper.service.CommentService;

@RestController
@RequestMapping("/api/comments")
public class CommentController {

    @Autowired
    private CommentService commentService;

    @Autowired
    private UserRepository userRepository;

    @GetMapping("/chapter/{chapterId}")
    public ResponseEntity<List<Comment>> getCommentsForChapter(@PathVariable Long chapterId) {
        List<Comment> comments = commentService.getCommentsByChapterId(chapterId);
        return ResponseEntity.ok(comments);
    }

    @GetMapping("/book/{bookId}")
    public ResponseEntity<List<Comment>> getCommentsForBook(@PathVariable Long bookId) {
        List<Comment> comments = commentService.getCommentsByBookId(bookId);
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
}
