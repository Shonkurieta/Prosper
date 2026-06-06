package com.example.prosper.controller;

import com.example.prosper.model.Book;
import com.example.prosper.model.User;
import com.example.prosper.repository.BookRatingRepository;
import com.example.prosper.repository.BookRepository;
import com.example.prosper.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/recommendations")
public class RecommendationController {

    @Autowired
    private BookRepository bookRepository;

    @Autowired
    private BookRatingRepository bookRatingRepository;

    @Autowired
    private UserRepository userRepository;

    private static final String ML_URL =
            System.getenv().getOrDefault("ML_SERVICE_URL", "http://ml-service:8001");

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();

    private final ObjectMapper objectMapper = new ObjectMapper();

    @GetMapping
    public ResponseEntity<Map<String, Object>> getRecommendations(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "10") int limit
    ) {
        User user = userRepository.findByNickname(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));

        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(ML_URL + "/recommendations/" + user.getId() + "?limit=" + limit))
                    .timeout(Duration.ofSeconds(8))
                    .GET()
                    .build();

            HttpResponse<String> response =
                    httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() != 200) {
                return ResponseEntity.ok(Map.of("books", List.of(), "level", 0));
            }

            @SuppressWarnings("unchecked")
            Map<String, Object> mlResp = objectMapper.readValue(response.body(), Map.class);

            @SuppressWarnings("unchecked")
            List<Integer> rawIds = (List<Integer>) mlResp.getOrDefault("bookIds", List.of());
            int level = ((Number) mlResp.getOrDefault("level", 0)).intValue();

            if (rawIds.isEmpty()) {
                return ResponseEntity.ok(Map.of("books", List.of(), "level", level));
            }

            List<Long> bookIds = rawIds.stream().map(Long::valueOf).collect(Collectors.toList());

            // Pre-load average ratings in one query
            Map<Long, Double> avgRatings = new HashMap<>();
            bookRatingRepository.getAverageRatingsForAllBooks()
                    .forEach(arr -> avgRatings.put((Long) arr[0], (Double) arr[1]));

            // Load books and preserve ML-ranked order
            Map<Long, Book> bookMap = new HashMap<>();
            bookRepository.findAllById(bookIds).forEach(b -> bookMap.put(b.getId(), b));

            List<Map<String, Object>> books = bookIds.stream()
                    .map(bookMap::get)
                    .filter(Objects::nonNull)
                    .map(b -> {
                        Map<String, Object> m = new LinkedHashMap<>();
                        m.put("id", b.getId());
                        m.put("title", b.getTitle());
                        m.put("author", b.getAuthor());
                        m.put("description", b.getDescription());
                        m.put("coverUrl", b.getCoverUrl());
                        m.put("genres", b.getGenres());
                        m.put("averageRating", avgRatings.getOrDefault(b.getId(), 0.0));
                        return m;
                    })
                    .collect(Collectors.toList());

            return ResponseEntity.ok(Map.of("books", books, "level", level));

        } catch (Exception e) {
            return ResponseEntity.ok(Map.of("books", List.of(), "level", 0));
        }
    }
}
