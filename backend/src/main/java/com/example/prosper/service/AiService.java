package com.example.prosper.service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
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
    private final String GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

    @Value("${GEMINI_API_KEY:}")
    private String geminiApiKey;

    public Map<String, Object> getChatResponse(String question) {
        // Шаг 1: Gemini извлекает название книги и номер главы из вопроса
        String extractionPrompt = "Из вопроса пользователя извлеки название новеллы/книги и номер главы (если упомянуты).\n"
                + "Верни ТОЛЬКО JSON без лишнего текста, без markdown, без пояснений.\n"
                + "Формат: {\"bookTitle\": \"название или пустая строка\", \"chapterNumber\": число или null}\n\n"
                + "Примеры:\n"
                + "Вопрос: \"Что произошло в 1 главе новеллы Преподобный Гу?\"\n"
                + "Ответ: {\"bookTitle\": \"Преподобный Гу\", \"chapterNumber\": 1}\n\n"
                + "Вопрос: \"Кто такой Фан Юань из Преподобного Гу?\"\n"
                + "Ответ: {\"bookTitle\": \"Преподобный Гу\", \"chapterNumber\": null}\n\n"
                + "Вопрос пользователя: " + question;

        String extractionResult = callGeminiRaw(extractionPrompt);
        System.out.println("Extraction result: " + extractionResult);

        String bookTitle = "";
        Integer chapterNumber = null;

        try {
            String cleaned = extractionResult.trim()
                    .replaceAll("```json", "").replaceAll("```", "").trim();

            Matcher titleMatcher = Pattern.compile("\"bookTitle\"\\s*:\\s*\"([^\"]+)\"").matcher(cleaned);
            if (titleMatcher.find()) {
                bookTitle = titleMatcher.group(1).trim();
            }

            Matcher chapterMatcher = Pattern.compile("\"chapterNumber\"\\s*:\\s*(\\d+)").matcher(cleaned);
            if (chapterMatcher.find()) {
                chapterNumber = Integer.parseInt(chapterMatcher.group(1));
            }
        } catch (Exception e) {
            System.out.println("Failed to parse extraction result: " + e.getMessage());
        }

        System.out.println("Extracted bookTitle: [" + bookTitle + "], chapterNumber: [" + chapterNumber + "]");

        if (bookTitle.isEmpty()) {
            return Map.of("answer", "Не смог определить название новеллы. Уточни, пожалуйста.", "sources", Collections.emptyList());
        }

        // Шаг 2: Ищем книгу
        List<Book> books = bookRepository.findByTitleContainingIgnoreCase(bookTitle);
        if (books.isEmpty()) {
            return Map.of("answer", "Новелла \"" + bookTitle + "\" не найдена. Уточни название.", "sources", Collections.emptyList());
        }

        final String finalBookTitle = bookTitle;
        Book book = books.stream()
                .filter(b -> b.getTitle().equalsIgnoreCase(finalBookTitle))
                .findFirst()
                .orElse(books.get(0));

        System.out.println("Found book: " + book.getTitle() + " (id=" + book.getId() + ")");

        // Шаг 3: Ищем главы
        List<Chapter> relevantChapters = new ArrayList<>();

        if (chapterNumber != null) {
            Optional<Chapter> chapterOpt = chapterRepository.findByBookIdAndChapterTitleNumber(book.getId(), chapterNumber);
            if (chapterOpt.isPresent()) {
                relevantChapters.add(chapterOpt.get());
                System.out.println("Found chapter by title number: " + chapterOpt.get().getTitle());
            } else {
                Optional<Chapter> byOrder = chapterRepository.findByBookIdAndChapterOrder(book.getId(), chapterNumber);
                byOrder.ifPresent(relevantChapters::add);
            }
        }

        if (relevantChapters.isEmpty()) {
            String ftsQuery = java.util.Arrays.stream(question.split("\\s+"))
                    .filter(s -> s.length() > 2)
                    .collect(Collectors.joining(" & "));
            if (!ftsQuery.isEmpty()) {
                relevantChapters = chapterRepository.searchChaptersByFts(book.getId(), ftsQuery);
            }
        }

        if (relevantChapters.isEmpty()) {
            relevantChapters = chapterRepository.findByBookIdOrderByChapterOrderAsc(book.getId())
                    .stream().limit(2).collect(Collectors.toList());
        }

        String context = relevantChapters.stream()
                .map(Chapter::getContent)
                .collect(Collectors.joining("\n\n"));

        if (context.length() > 4000) {
            context = context.substring(0, 4000);
        }

        // Шаг 4: Gemini отвечает на вопрос
        String answer = callGemini(question, context);

        List<Map<String, Object>> sources = relevantChapters.stream()
                .map(c -> Map.of(
                        "bookTitle", book.getTitle(),
                        "chapterTitle", c.getTitle() != null ? c.getTitle() : "Глава " + c.getchapterOrder(),
                        "chapterId", (Object) c.getId()
                ))
                .collect(Collectors.toList());

        Map<String, Object> response = new HashMap<>();
        response.put("answer", answer);
        response.put("sources", sources);
        return response;
    }

    private String callGeminiRaw(String prompt) {
        String apiKey = geminiApiKey;
        if (apiKey == null || apiKey.isEmpty()) {
            apiKey = System.getenv("GEMINI_API_KEY");
        }
        if (apiKey == null || apiKey.isEmpty()) return "{}";

        String url = GEMINI_API_URL + "?key=" + apiKey;

        Map<String, Object> requestBody = Map.of(
                "contents", List.of(
                        Map.of("role", "user", "parts", List.of(
                                Map.of("text", prompt)
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
            System.out.println("Gemini extraction error: " + e.getMessage());
        }
        return "{}";
    }

    private String callGemini(String question, String context) {
        String apiKey = geminiApiKey;
        if (apiKey == null || apiKey.isEmpty()) {
            apiKey = System.getenv("GEMINI_API_KEY");
        }

        if (apiKey == null || apiKey.isEmpty()) {
            return "Ошибка: GEMINI_API_KEY не настроен на сервере.";
        }

        String systemPrompt = "Ты — ассистент читателей приложения Prosper.\n"
                + "Твои задачи:\n"
                + "- Помогать вспомнить события прошлых глав\n"
                + "- Объяснять мотивацию персонажей\n"
                + "- Отвечать на вопросы о лоре и мироустройстве\n\n"
                + "Строгие правила:\n"
                + "- Отвечай ТОЛЬКО на основе предоставленного контекста глав\n"
                + "- Если ответа нет в контексте — скажи: \"В этих главах я не нашёл такую информацию\"\n"
                + "- Не придумывай события, имена и детали которых нет в тексте\n"
                + "- Отвечай на русском языке, кратко и по делу\n\n"
                + "Контекст из глав:\n" + context;

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