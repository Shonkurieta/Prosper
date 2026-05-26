package com.example.prosper.controller;

import com.example.prosper.service.AiService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/ai")
public class AiController {

    @Autowired
    private AiService aiService;

    @PostMapping("/chat")
    public ResponseEntity<Map<String, Object>> chat(@RequestBody Map<String, Object> request) {
        String question = (String) request.get("question");
        String bookTitle = (String) request.get("bookTitle");
        Object chapterNumObj = request.get("chapterNumber");
        Integer chapterNumber = null;
        
        if (chapterNumObj instanceof Number) {
            chapterNumber = ((Number) chapterNumObj).intValue();
        } else if (chapterNumObj instanceof String) {
            try {
                chapterNumber = Integer.parseInt((String) chapterNumObj);
            } catch (NumberFormatException ignored) {}
        }

        if (question == null || bookTitle == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "question and bookTitle are required"));
        }

        Map<String, Object> response = aiService.getChatResponse(question, bookTitle, chapterNumber);
        return ResponseEntity.ok(response);
    }
}
