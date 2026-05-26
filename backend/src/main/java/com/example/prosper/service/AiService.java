package com.example.prosper.service;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import com.example.prosper.model.Book;
import com.example.prosper.model.Chapter;
import com.example.prosper.repository.BookRepository;
import com.example.prosper.repository.ChapterRepository;

@Service
public class AiService {

    @Autowired
    private BookRepository bookRepository;

    @Autowired
    private ChapterRepository chapterRepository;

    private final RestTemplate restTemplate = new RestTemplate();
    private final String GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";

    public Map<String, Object> getChatResponse(String question, String bookTitle, Integer chapterNumber) {
        List<Book> books = bookRepository.findByTitleContainingIgnoreCase(bookTitle);
        
        if (books.isEmpty()) {
            return Map.of("answer", "Новелла с таким названием не найдена. Уточни название.", "sources", Collections.emptyList());
        }

        // Берём точное совпадение если есть, иначе первый результат
        Book book = books.stream()
                .filter(b -> b.getTitle().equalsIgnoreCase(bookTitle))
                .findFirst()
                .orElse(books.get(0));

        List<Chapter> relevantChapters = new ArrayList<>();

        if (chapterNumber != null) {
            Optional<Chapter> chapterOpt = chapterRepository.findByBookIdAndChapterOrder(book.getId(), chapterNumber);
            if (chapterOpt.isPresent()) {
                relevantChapters.add(chapterOpt.get());
            } else {
                return Map.of("answer", "Такая глава в этой новелле не найдена. Уточни номер или название.", "sources", Collections.emptyList());
            }
        } else {
            // Prepare query for FTS: join words with &
            String ftsQuery = Arrays.stream(question.split("\\s+"))
                    .filter(s -> s.length() > 2)
                    .collect(Collectors.joining(" & "));
            
            if (ftsQuery.isEmpty()) ftsQuery = question; // Fallback
            
            relevantChapters = chapterRepository.searchChaptersByFts(book.getId(), ftsQuery);
        }

        if (relevantChapters.isEmpty()) {
             // Try a fallback if FTS returned nothing but book exists
             relevantChapters = chapterRepository.findByBookIdOrderByChapterOrderAsc(book.getId()).stream().limit(2).collect(Collectors.toList());
        }

        String context = relevantChapters.stream()
                .map(Chapter::getContent)
                .collect(Collectors.joining("\n\n"));

        if (context.length() > 4000) {
            context = context.substring(0, 4000);
        }

        String answer = callGemini(question, context);

        List<Map<String, Object>> sources = relevantChapters.stream()
                .map(c -> Map.of(
                        "bookTitle", book.getTitle(),
                        "chapterTitle", c.getTitle() != null ? c.getTitle() : "Глава " + c.getchapterOrder(),
                        "chapterId", (Object)c.getId()
                ))
                .collect(Collectors.toList());

        Map<String, Object> response = new HashMap<>();
        response.put("answer", answer);
        response.put("sources", sources);
        return response;
    }

    private String callGemini(String question, String context) {
        String apiKey = System.getenv("GEMINI_API_KEY");
        if (apiKey == null || apiKey.isEmpty()) {
            return "Ошибка: GEMINI_API_KEY не настроен на сервере.";
        }

        String systemPrompt = """
          Ты — ассистент читателей приложения Prosper.
          Твои задачи:
          - Помогать вспомнить события прошлых глав
          - Объяснять мотивацию персонажей
          - Отвечать на вопросы о лоре и мироустройстве

          Строгие правила:
          - Отвечай ТОЛЬКО на основе предоставленного контекста глав
          - Если ответа нет в контексте — скажи: "В этих главах я не нашёл такую информацию"
          - Не придумывай события, имена и детали которых нет в тексте
          - Отвечай на русском языке, кратко и по делу

          Контекст из глав:
          """ + context;

        String url = GEMINI_API_URL + "?key=" + apiKey;

        Map<String, Object> requestBody = Map.of(
                "contents", List.of(
                        Map.of("role", "user", "parts", List.of(
                                Map.of("text", systemPrompt + "\n\nВопрос пользователя: " + question)
                        ))
                )
        );

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);

        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);

        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(url, entity, Map.class);
            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                List<Map> candidates = (List<Map>) response.getBody().get("candidates");
                if (candidates != null && !candidates.isEmpty()) {
                    Map content = (Map) candidates.get(0).get("content");
                    List<Map> parts = (List<Map>) content.get("parts");
                    if (parts != null && !parts.isEmpty()) {
                        return (String) parts.get(0).get("text");
                    }
                }
            }
        } catch (Exception e) {
            return "Ошибка при обращении к Gemini: " + e.getMessage();
        }

        return "Не удалось получить ответ от ИИ.";
    }
}
