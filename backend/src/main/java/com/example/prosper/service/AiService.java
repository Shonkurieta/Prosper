package com.example.prosper.service;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
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
import org.springframework.http.client.SimpleClientHttpRequestFactory;
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

    // Separate timeouts: Gemini can be slower, ML service should respond fast
    private final RestTemplate geminiRestTemplate = buildRestTemplate(5000, 25000);
    private final RestTemplate mlRestTemplate     = buildRestTemplate(3000, 15000);

    // Thread pool for parallel exact phrase + FTS + ILIKE + Semantic searches
    private final ExecutorService searchExecutor = Executors.newFixedThreadPool(5);

    private static final String GEMINI_API_URL =
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent";

    @Value("${GEMINI_API_KEY:}")
    private String geminiApiKey;

    @Value("${ML_SERVICE_URL:http://ml-service:8001}")
    private String mlServiceUrl;

    private static final String SYSTEM_PROMPT =
            "Ты — умный помощник по книгам и новеллам. Отвечай только на вопросы связанные с новеллами, книгами, персонажами, сюжетом, магическими системами, предметами и событиями из книг.\n\n"
            + "Тебе будет предоставлен контекст из глав книги. Используй ТОЛЬКО этот контекст для ответа.\n\n"
            + "Правила:\n"
            + "- Отвечай развёрнуто и интересно, как хороший рассказчик\n"
            + "- Если в контексте есть информация о рецепте, легенде, предмете или персонаже — опиши подробно\n"
            + "- Если информация в контексте неполная — скажи что нашёл и добавь что информация может быть в других главах\n"
            + "- Если вопрос вообще не про книги или новеллы — вежливо откажись отвечать\n"
            + "- Если контекст не содержит ответа на вопрос — скажи что не нашёл такой информации в доступных главах\n"
            + "- Никогда не придумывай информацию которой нет в контексте\n"
            + "- Отвечай на том же языке на котором задан вопрос";

    // ─────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────

    public Map<String, Object> getChatResponse(String question) {

        // ── Step 1: Single Gemini call — extract bookTitle + chapterNumber + keywords ──
        String[] extracted    = extractAllFromQuestion(question);
        String bookTitle      = extracted[0];                    // empty string if not found
        Integer chapterNumber = extracted[1] != null ? Integer.parseInt(extracted[1]) : null;
        String geminiKeywords = extracted[2];                    // space-separated keywords

        System.out.println("[AI] bookTitle=[" + bookTitle + "] chapter=[" + chapterNumber + "] keywords=[" + geminiKeywords + "]");

        // ── Step 2: Find candidate books ──
        List<Book> candidateBooks = findCandidateBooks(bookTitle, question);

        if (candidateBooks.isEmpty()) {
            String msg = bookTitle.isEmpty()
                    ? "Уточни, пожалуйста, название новеллы в вопросе."
                    : "Новелла \"" + bookTitle + "\" не найдена. Уточни название.";
            return Map.of("answer", msg, "sources", Collections.emptyList());
        }

        // ── Step 3: Build search terms (Gemini keywords + original question words, cleaned) ──
        Set<String> allKeywords = buildKeywordSet(geminiKeywords, question);
        String ftsQuery = String.join(" | ", allKeywords);

        System.out.println("[AI] ftsQuery=[" + ftsQuery + "]");

        List<Long> bookIds = candidateBooks.stream().map(Book::getId).collect(Collectors.toList());

        // ── Step 4: Collect chapters — specific chapter first, then parallel search ──
        Map<Long, Chapter> chaptersById = new LinkedHashMap<>();

        if (chapterNumber != null) {
            Book primary = candidateBooks.get(0);
            chapterRepository.findByBookIdAndChapterTitleNumber(primary.getId(), chapterNumber)
                    .or(() -> chapterRepository.findByBookIdAndChapterOrder(primary.getId(), chapterNumber))
                    .ifPresent(c -> chaptersById.put(c.getId(), c));
        }

        // Exact phrase search for capitalized entity names (e.g. "Зелья Взяточника") — highest priority
        List<String> exactPhrases = extractCapitalizedPhrases(question);

        CompletableFuture<List<Chapter>> exactPhraseFuture = CompletableFuture.supplyAsync(
                () -> runExactPhraseSearch(bookIds, exactPhrases), searchExecutor);

        CompletableFuture<List<Chapter>> ftsFuture = CompletableFuture.supplyAsync(
                () -> runFtsSearch(bookIds, ftsQuery), searchExecutor);

        // ILIKE uses only Gemini-extracted keywords (not raw question words) to avoid
        // title/noisy words like "Повелитель" crowding out specific content terms.
        Set<String> geminiKeywordSet = buildKeywordSet(geminiKeywords, "");
        CompletableFuture<List<Chapter>> ilikeFuture = CompletableFuture.supplyAsync(
                () -> runIlikeSearch(bookIds, geminiKeywordSet), searchExecutor);

        CompletableFuture<List<Chapter>> semanticFuture = CompletableFuture.supplyAsync(
                () -> runSemanticSearch(candidateBooks, question), searchExecutor);

        try {
            CompletableFuture.allOf(exactPhraseFuture, ftsFuture, ilikeFuture, semanticFuture)
                    .get(15, TimeUnit.SECONDS);
        } catch (TimeoutException e) {
            System.out.println("[AI] Parallel search timed out at 15s — using available results");
        } catch (Exception e) {
            System.out.println("[AI] Parallel search error: " + e.getMessage());
        }

        // Merge in priority: exactPhrase first (putIfAbsent keeps first insertion = highest priority)
        for (CompletableFuture<List<Chapter>> future : List.of(exactPhraseFuture, ftsFuture, ilikeFuture, semanticFuture)) {
            if (future.isDone() && !future.isCompletedExceptionally()) {
                future.getNow(Collections.emptyList())
                        .forEach(c -> chaptersById.putIfAbsent(c.getId(), c));
            }
        }

        // Fallback: first 2 chapters of primary book if nothing found
        if (chaptersById.isEmpty()) {
            chapterRepository.findByBookIdOrderByChapterOrderAsc(candidateBooks.get(0).getId())
                    .stream().limit(2)
                    .forEach(c -> chaptersById.put(c.getId(), c));
        }

        // ── Step 5: Build context (max 80000 chars, per-chapter cap 3000) ──
        List<Chapter> relevantChapters = new ArrayList<>(chaptersById.values());

        String chapterLog = relevantChapters.stream()
                .map(c -> c.getId() + (c.getchapterOrder() != null ? "(гл." + c.getchapterOrder() + ")" : ""))
                .collect(Collectors.joining(", "));
        System.out.println("[AI] Context chapters (" + relevantChapters.size() + "): " + chapterLog);

        long[] truncatedCount = {0};
        String context = relevantChapters.stream()
                .map(c -> {
                    String ct = c.getContent();
                    if (ct == null || ct.isEmpty()) return null;
                    // ILIKE chapters already have keyword-windowed content (set in runIlikeSearch).
                    // For other chapters, cap at 2000 chars so no single chapter dominates context.
                    String snippet;
                    if (ct.length() > 2000) {
                        snippet = ct.substring(0, 2000);
                        truncatedCount[0]++;
                    } else {
                        snippet = ct;
                    }
                    // Prefix with readable chapter number so Gemini can cite correctly.
                    String header = c.getchapterOrder() != null
                            ? "[Глава " + c.getchapterOrder() + "]\n"
                            : (c.getTitle() != null ? "[" + c.getTitle() + "]\n" : "");
                    String entry = header + snippet;
                    if (Long.valueOf(4269L).equals(c.getId())) {
                        System.out.println("[AI] Chapter 4269 -> Gemini first100=[" +
                                entry.substring(0, Math.min(100, entry.length())) + "]");
                    }
                    return entry;
                })
                .filter(c -> c != null && !c.isEmpty())
                .collect(Collectors.joining("\n\n---\n\n"));

        int contextBeforeCap = context.length();
        if (context.length() > 200000) context = context.substring(0, 200000);
        int droppedByGlobalCap = contextBeforeCap > 200000
                ? (int) Math.ceil((contextBeforeCap - 200000) / 3000.0) : 0;
        System.out.println("[AI] Context size=" + contextBeforeCap + " -> sent=" + context.length() +
                " chars, per-chapter-truncated=" + truncatedCount[0] +
                "/" + relevantChapters.size() + ", ~dropped_by_global_cap=" + droppedByGlobalCap);

        // ── Step 6: Final Gemini answer ──
        String answer = callGemini(question, context);

        List<Map<String, Object>> sources = relevantChapters.stream()
                .map(c -> {
                    Map<String, Object> s = new HashMap<>();
                    s.put("bookTitle", c.getBook() != null ? c.getBook().getTitle() : "");
                    String label = c.getTitle() != null ? c.getTitle()
                            : (c.getchapterOrder() != null ? "Глава " + c.getchapterOrder() : "Глава");
                    s.put("chapterTitle", label);
                    s.put("chapterId", c.getId());
                    return s;
                })
                .collect(Collectors.toList());

        Map<String, Object> response = new HashMap<>();
        response.put("answer", answer);
        response.put("sources", sources);
        return response;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Extraction — single Gemini call for title + chapter + keywords
    // ─────────────────────────────────────────────────────────────────────────

    private String[] extractAllFromQuestion(String question) {
        String prompt =
                "Из вопроса пользователя извлеки:\n"
                + "1. Название новеллы/книги (если упомянуто — точно как в вопросе, иначе пустая строка)\n"
                + "2. Номер главы (если упомянут, иначе null)\n"
                + "3. 3-5 ключевых слов на русском для поиска по тексту книги\n\n"
                + "Верни ТОЛЬКО JSON без markdown, без пояснений:\n"
                + "{\"bookTitle\": \"название или пустая строка\", \"chapterNumber\": число или null, \"keywords\": \"слово1 слово2 слово3\"}\n\n"
                + "Примеры:\n"
                + "Вопрос: \"Что произошло в 1 главе Преподобного Гу?\"\n"
                + "Ответ: {\"bookTitle\": \"Преподобный Гу\", \"chapterNumber\": 1, \"keywords\": \"события начало герой\"}\n\n"
                + "Вопрос: \"Какой рецепт у Зелья Взяточника?\"\n"
                + "Ответ: {\"bookTitle\": \"\", \"chapterNumber\": null, \"keywords\": \"зелье взяточник рецепт ингредиенты состав\"}\n\n"
                + "Вопрос пользователя: " + question;

        String raw = callGeminiRaw(prompt);
        String bookTitle  = "";
        String chapterStr = null;
        String keywords   = "";

        try {
            String cleaned = raw.trim().replaceAll("```json", "").replaceAll("```", "").trim();
            Matcher m;
            m = Pattern.compile("\"bookTitle\"\\s*:\\s*\"([^\"]*)\"").matcher(cleaned);
            if (m.find()) bookTitle = m.group(1).trim();

            m = Pattern.compile("\"chapterNumber\"\\s*:\\s*(\\d+)").matcher(cleaned);
            if (m.find()) chapterStr = m.group(1);

            m = Pattern.compile("\"keywords\"\\s*:\\s*\"([^\"]*)\"").matcher(cleaned);
            if (m.find()) keywords = m.group(1).trim();
        } catch (Exception e) {
            System.out.println("[AI] Extraction parse error: " + e.getMessage());
        }

        return new String[]{bookTitle, chapterStr, keywords};
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Book finding
    // ─────────────────────────────────────────────────────────────────────────

    private List<Book> findCandidateBooks(String bookTitle, String question) {
        if (!bookTitle.isEmpty()) {
            Book book = findBook(bookTitle);
            return book != null ? List.of(book) : Collections.emptyList();
        }
        // Problem 2 fix: no title — trigram search using each word from the question
        return findBooksByQuestionWords(question);
    }

    private Book findBook(String title) {
        List<Book> exact = bookRepository.findByTitleContainingIgnoreCase(title);
        if (!exact.isEmpty()) {
            return exact.stream()
                    .filter(b -> b.getTitle().equalsIgnoreCase(title))
                    .findFirst()
                    .orElse(exact.get(0));
        }
        try {
            List<Book> fuzzy = bookRepository.findByTitleSimilarity(title);
            if (!fuzzy.isEmpty()) {
                System.out.println("[AI] Trigram match: [" + title + "] → [" + fuzzy.get(0).getTitle() + "]");
                return fuzzy.get(0);
            }
        } catch (Exception e) {
            System.out.println("[AI] Trigram search error: " + e.getMessage());
        }
        return null;
    }

    /**
     * When no book title is given: iterate over words in the question,
     * try findByTitleSimilarity for each, collect up to 3 distinct books.
     */
    private List<Book> findBooksByQuestionWords(String question) {
        Map<Long, Book> found = new LinkedHashMap<>();
        for (String raw : question.split("\\s+")) {
            if (found.size() >= 3) break;
            String word = raw.replaceAll("[^\\p{L}\\p{N}]", "");
            if (word.length() < 4) continue;
            try {
                bookRepository.findByTitleSimilarity(word)
                        .forEach(b -> found.putIfAbsent(b.getId(), b));
            } catch (Exception ignored) {}
        }
        if (!found.isEmpty()) {
            System.out.println("[AI] Cross-book candidates: " +
                    found.values().stream().map(Book::getTitle).collect(Collectors.joining(", ")));
        }
        return new ArrayList<>(found.values());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Keyword building — Problem 3 + 10 fix
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Combines Gemini-extracted keywords with original question words.
     * Each word is cleaned of all non-letter/digit chars (fixes punctuation problem).
     * Order: Gemini keywords first (semantic), then question words (author vocabulary).
     */
    private Set<String> buildKeywordSet(String geminiKeywords, String question) {
        Set<String> keywords = new LinkedHashSet<>();

        if (!geminiKeywords.isEmpty()) {
            Arrays.stream(geminiKeywords.split("\\s+"))
                    .map(w -> w.replaceAll("[^\\p{L}\\p{N}]", ""))
                    .filter(w -> w.length() > 2)
                    .forEach(keywords::add);
        }
        // Append original question words — covers author-specific vocabulary Gemini might miss
        Arrays.stream(question.split("\\s+"))
                .map(w -> w.replaceAll("[^\\p{L}\\p{N}]", ""))
                .filter(w -> w.length() > 2)
                .forEach(keywords::add);

        return keywords;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Parallel search methods
    // ─────────────────────────────────────────────────────────────────────────

    private List<Chapter> runFtsSearch(List<Long> bookIds, String ftsQuery) {
        if (ftsQuery.isEmpty() || bookIds.isEmpty()) return Collections.emptyList();
        try {
            List<Chapter> results = chapterRepository.searchChaptersByFtsForBooks(bookIds, ftsQuery);
            System.out.println("[AI] FTS found " + results.size() + " chapters");
            return results;
        } catch (Exception e) {
            System.out.println("[AI] FTS search failed: " + e.getMessage());
            return Collections.emptyList();
        }
    }

    private List<Chapter> runIlikeSearch(List<Long> bookIds, Set<String> keywords) {
        if (keywords.isEmpty() || bookIds.isEmpty()) return Collections.emptyList();
        Map<Long, Chapter> found = new LinkedHashMap<>();
        // Track the keyword that matched each chapter so we can window around it.
        Map<Long, String> matchedKeyword = new LinkedHashMap<>();
        List<String> top3 = keywords.stream()
                .filter(k -> k.length() >= 4)
                .sorted(Comparator.comparingInt(String::length).reversed())
                .limit(3)
                .collect(Collectors.toList());
        System.out.println("[AI] ILIKE keywords (top3): " + top3);
        top3.forEach(keyword -> {
            try {
                List<Chapter> hits = chapterRepository.searchChaptersByIlikeForBooks(bookIds, "%" + keyword + "%");
                List<Long> hitIds = hits.stream().map(Chapter::getId).collect(Collectors.toList());
                System.out.println("[AI] ILIKE keyword=[" + keyword + "] hits=" + hitIds);
                hits.forEach(c -> {
                    if (found.putIfAbsent(c.getId(), c) == null) {
                        matchedKeyword.put(c.getId(), keyword);
                    }
                });
            } catch (Exception e) {
                System.out.println("[AI] ILIKE search failed for [" + keyword + "]: " + e.getMessage());
            }
        });

        // Replace full content with keyword-centered window.
        // Strategy: find ALL occurrences of keyword, pick the one nearest to recipe-indicator
        // words ("ингредиент", "состав", "рецепт", "последовательност", "капл", " мл", "унц").
        // If none found near a recipe, merge windows around all occurrences (limit 3000 chars).
        List<String> recipeWords = List.of("ингредиент", "состав", "рецепт",
                "последовательност", "капл", " мл", "унц");
        found.values().forEach(c -> {
            String content = c.getContent();
            if (content == null) return;
            String kw = matchedKeyword.get(c.getId());
            if (kw == null) return;
            String contentLower = content.toLowerCase();
            String kwLower = kw.toLowerCase();

            // Collect all occurrence positions.
            List<Integer> positions = new ArrayList<>();
            int searchFrom = 0;
            while (true) {
                int p = contentLower.indexOf(kwLower, searchFrom);
                if (p < 0) break;
                positions.add(p);
                searchFrom = p + 1;
            }
            if (positions.isEmpty()) return;

            // For each occurrence find min distance to nearest recipe word within ±5000 chars.
            // Pick the occurrence with smallest distance (closest to a recipe word).
            int bestPos = -1;
            int bestDist = Integer.MAX_VALUE;
            List<Integer> distances = new ArrayList<>();
            for (int p : positions) {
                int vicinityStart = Math.max(0, p - 5000);
                int vicinityEnd   = Math.min(contentLower.length(), p + 5000);
                String vicinity   = contentLower.substring(vicinityStart, vicinityEnd);
                int minDist = Integer.MAX_VALUE;
                for (String rw : recipeWords) {
                    int idx = vicinity.indexOf(rw);
                    while (idx >= 0) {
                        // distance in original content coords
                        int absIdx = vicinityStart + idx;
                        int dist = Math.abs(absIdx - p);
                        if (dist < minDist) minDist = dist;
                        idx = vicinity.indexOf(rw, idx + 1);
                    }
                }
                distances.add(minDist == Integer.MAX_VALUE ? -1 : minDist);
                if (minDist < bestDist) {
                    bestDist = minDist;
                    bestPos  = p;
                }
            }
            // If no recipe word found anywhere, treat as not found.
            if (bestDist == Integer.MAX_VALUE) bestPos = -1;

            String window;
            if (bestPos >= 0) {
                int start = Math.max(0, bestPos - 1000);
                int end   = Math.min(content.length(), bestPos + 2000);
                window = content.substring(start, end);
            } else {
                // No recipe context — merge snippets around each occurrence.
                StringBuilder sb = new StringBuilder();
                int lastEnd = -1;
                for (int p : positions) {
                    int start = Math.max(0, p - 300);
                    int end   = Math.min(content.length(), p + 700);
                    if (start < lastEnd) start = lastEnd;
                    if (start >= end) continue;
                    if (sb.length() > 0) sb.append("\n…\n");
                    sb.append(content, start, end);
                    lastEnd = end;
                    if (sb.length() >= 3000) break;
                }
                window = sb.length() > 3000 ? sb.substring(0, 3000) : sb.toString();
            }

            c.setContent(window);
            if (Long.valueOf(4269L).equals(c.getId())) {
                System.out.println("[AI] Chapter 4269 ILIKE keyword=[" + kw +
                        "] occurrences=" + positions + " distances=" + distances +
                        " best_pos=" + bestPos +
                        (bestPos >= 0 ? " (recipe-adjacent)" : " (no recipe found)"));
            }
        });

        System.out.println("[AI] ILIKE found " + found.size() + " chapters");
        return new ArrayList<>(found.values());
    }

    private List<Chapter> runSemanticSearch(List<Book> books, String question) {
        List<Chapter> results = new ArrayList<>();
        for (Book book : books) {
            try {
                List<Map<String, Object>> sr = callSemanticSearch(question, book.getId(), 5);
                for (Map<String, Object> s : sr) {
                    Chapter c = new Chapter();
                    c.setId(((Number) s.get("chapter_id")).longValue());
                    c.setTitle((String) s.get("title"));
                    c.setContent((String) s.get("content"));
                    c.setBook(book);
                    results.add(c);
                }
            } catch (Exception e) {
                System.out.println("[AI] Semantic search failed for book " + book.getId() + ": " + e.getMessage());
            }
        }
        System.out.println("[AI] Semantic found " + results.size() + " chapters");
        return results;
    }

    /**
     * Extracts consecutive runs of capitalized words from the question (skipping the first word
     * which is a sentence opener). These represent entity names like "Зелья Взяточника" or "Фан Юань".
     * Used for exact ILIKE phrase search to guarantee the relevant chapter ranks first.
     */
    private List<String> extractCapitalizedPhrases(String question) {
        String[] words = question.split("\\s+");
        List<String> phrases = new ArrayList<>();
        List<String> current = new ArrayList<>();
        for (int i = 1; i < words.length; i++) {
            String word = words[i].replaceAll("[^\\p{L}\\p{N}]", "");
            if (!word.isEmpty() && Character.isUpperCase(word.charAt(0)) && word.length() > 1) {
                current.add(word);
            } else {
                if (!current.isEmpty()) {
                    phrases.add(String.join(" ", current));
                    current.clear();
                }
            }
        }
        if (!current.isEmpty()) phrases.add(String.join(" ", current));
        List<String> result = phrases.stream().filter(p -> p.length() > 3).collect(Collectors.toList());
        if (!result.isEmpty()) System.out.println("[AI] Exact phrases extracted: " + result);
        return result;
    }

    private List<Chapter> runExactPhraseSearch(List<Long> bookIds, List<String> phrases) {
        if (phrases.isEmpty() || bookIds.isEmpty()) return Collections.emptyList();
        Map<Long, Chapter> found = new LinkedHashMap<>();
        for (String phrase : phrases) {
            try {
                chapterRepository.searchChaptersByIlikeForBooks(bookIds, "%" + phrase + "%")
                        .forEach(c -> found.putIfAbsent(c.getId(), c));
            } catch (Exception e) {
                System.out.println("[AI] Exact phrase search failed for [" + phrase + "]: " + e.getMessage());
            }
        }
        System.out.println("[AI] Exact phrase found " + found.size() + " chapters for: " + phrases);
        return new ArrayList<>(found.values());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ML service
    // ─────────────────────────────────────────────────────────────────────────

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> callSemanticSearch(String question, Long bookId, int topK) {
        String url = mlServiceUrl + "/semantic-search";
        Map<String, Object> body = Map.of("question", question, "book_id", bookId, "top_k", topK);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);

        ResponseEntity<Map> response = mlRestTemplate.postForEntity(
                url, new HttpEntity<>(body, headers), Map.class);

        if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
            Object chapters = response.getBody().get("chapters");
            if (chapters instanceof List) return (List<Map<String, Object>>) chapters;
        }
        return Collections.emptyList();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Gemini helpers
    // ─────────────────────────────────────────────────────────────────────────

    private String callGeminiRaw(String prompt) {
        String apiKey = resolveApiKey();
        if (apiKey == null) return "{}";
        String url = GEMINI_API_URL + "?key=" + apiKey;
        Map<String, Object> body = Map.of(
                "contents", List.of(Map.of("role", "user", "parts", List.of(Map.of("text", prompt)))));
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        try {
            ResponseEntity<Map> response = geminiRestTemplate.postForEntity(
                    url, new HttpEntity<>(body, headers), Map.class);
            return extractGeminiText(response);
        } catch (Exception e) {
            System.out.println("[AI] Gemini raw error: " + e.getMessage());
            return "{}";
        }
    }

    private String callGemini(String question, String context) {
        String apiKey = resolveApiKey();
        if (apiKey == null) return "Ошибка: GEMINI_API_KEY не настроен.";
        String url = GEMINI_API_URL + "?key=" + apiKey;
        String fullPrompt = SYSTEM_PROMPT + "\n\nКонтекст из глав:\n" + context + "\n\nВопрос: " + question;
        Map<String, Object> body = Map.of(
                "contents", List.of(Map.of("role", "user", "parts", List.of(Map.of("text", fullPrompt)))));
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        try {
            ResponseEntity<Map> response = geminiRestTemplate.postForEntity(
                    url, new HttpEntity<>(body, headers), Map.class);
            String result = extractGeminiText(response);
            if (!result.equals("{}")) return result;
        } catch (Exception e) {
            return "Ошибка при обращении к Gemini: " + e.getMessage();
        }
        return "Не удалось получить ответ от ИИ.";
    }

    private String resolveApiKey() {
        if (geminiApiKey != null && !geminiApiKey.isEmpty()) return geminiApiKey;
        String env = System.getenv("GEMINI_API_KEY");
        return (env != null && !env.isEmpty()) ? env : null;
    }

    @SuppressWarnings("unchecked")
    private String extractGeminiText(ResponseEntity<Map> response) {
        if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
            List<Map> candidates = (List<Map>) response.getBody().get("candidates");
            if (candidates != null && !candidates.isEmpty()) {
                Map content = (Map) candidates.get(0).get("content");
                if (content != null) {
                    List<Map> parts = (List<Map>) content.get("parts");
                    if (parts != null && !parts.isEmpty()) {
                        String text = (String) parts.get(0).get("text");
                        return text != null ? text : "{}";
                    }
                }
            }
        }
        return "{}";
    }

    private static RestTemplate buildRestTemplate(int connectMs, int readMs) {
        SimpleClientHttpRequestFactory f = new SimpleClientHttpRequestFactory();
        f.setConnectTimeout(connectMs);
        f.setReadTimeout(readMs);
        return new RestTemplate(f);
    }
}
