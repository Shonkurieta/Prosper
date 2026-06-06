package com.example.prosper.controller;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.example.prosper.dto.ChapterDTO;
import com.example.prosper.model.Book;
import com.example.prosper.model.Chapter;
import com.example.prosper.model.Genre;
import com.example.prosper.model.User;
import com.example.prosper.model.Notification;
import com.example.prosper.model.NotificationType;
import com.example.prosper.model.UserBook;
import com.example.prosper.repository.BookRatingRepository;
import com.example.prosper.repository.BookRepository;
import com.example.prosper.repository.ChapterRepository;
import com.example.prosper.repository.GenreRepository;
import com.example.prosper.repository.NotificationRepository;
import com.example.prosper.repository.UserBookRepository;
import com.example.prosper.repository.UserRepository;

@RestController
@RequestMapping("/api/admin")
@CrossOrigin(origins = "*")
public class AdminController {

    @Autowired
    private BookRepository bookRepository;

    @Autowired
    private ChapterRepository chapterRepository;

    @Autowired
    private UserRepository userRepository;
    
    @Autowired
    private GenreRepository genreRepository;

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private UserBookRepository userBookRepository;

    @Autowired
    private BookRatingRepository bookRatingRepository;

    @GetMapping("/books")
    public ResponseEntity<List<Book>> getAllBooks() {
        return ResponseEntity.ok(bookRepository.findAll());
    }

    @GetMapping("/books/{id}")
    public ResponseEntity<Book> getBook(@PathVariable Long id) {
        return bookRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping(value = "/books", consumes = "multipart/form-data")
    public ResponseEntity<?> createBook(
            @RequestPart("title") String title,
            @RequestPart("author") String author,
            @RequestPart(value = "description", required = false) String description,
            @RequestPart(value = "genres", required = false) String genresJson,
            @RequestPart(value = "cover", required = false) MultipartFile cover
    ) {
        try {
            if (title == null || title.trim().isEmpty()) {
                return ResponseEntity.badRequest().body(createError("Название новеллы обязательно"));
            }

            if (author == null || author.trim().isEmpty()) {
                return ResponseEntity.badRequest().body(createError("Автор новеллы обязателен"));
            }

            Book newBook = new Book();
            newBook.setTitle(title);
            newBook.setAuthor(author);
            newBook.setDescription(description != null ? description : "");

            if (genresJson != null && !genresJson.isEmpty()) {
                Set<Genre> genres = new HashSet<>();
                for (String genreName : genresJson.split(",")) {
                    genreRepository.findByName(genreName.trim())
                        .ifPresent(genres::add);
                }
                newBook.setGenres(genres);
            }

            if (cover != null && !cover.isEmpty()) {
                String coverUrl = saveCoverFile(cover);
                if (coverUrl == null) {
                    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                            .body(createError("Ошибка сохранения обложки"));
                }
                newBook.setCoverUrl(coverUrl);
            }

            Book savedBook = bookRepository.save(newBook);
            return ResponseEntity.status(HttpStatus.CREATED).body(savedBook);

        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(createError("Ошибка при создании новеллы: " + e.getMessage()));
        }
    }

    @PutMapping(value = "/books/{id}", consumes = "multipart/form-data")
    public ResponseEntity<?> updateBook(
            @PathVariable Long id,
            @RequestPart(value = "title", required = false) String title,
            @RequestPart(value = "author", required = false) String author,
            @RequestPart(value = "description", required = false) String description,
            @RequestPart(value = "genres", required = false) String genresJson,
            @RequestPart(value = "cover", required = false) MultipartFile cover
    ) {
        try {
            Book existingBook = bookRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("Новелла не найдена"));

            if (title != null && !title.trim().isEmpty()) existingBook.setTitle(title);
            if (author != null && !author.trim().isEmpty()) existingBook.setAuthor(author);
            if (description != null) existingBook.setDescription(description);

            if (genresJson != null) {
                Set<Genre> genres = new HashSet<>();
                for (String genreName : genresJson.split(",")) {
                    genreRepository.findByName(genreName.trim())
                        .ifPresent(genres::add);
                }
                existingBook.setGenres(genres);
            }

            if (cover != null && !cover.isEmpty()) {
                deleteOldCover(existingBook.getCoverUrl());
                String coverUrl = saveCoverFile(cover);
                if (coverUrl == null) {
                    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                            .body(createError("Ошибка сохранения обложки"));
                }
                existingBook.setCoverUrl(coverUrl);
            }

            return ResponseEntity.ok(bookRepository.save(existingBook));

        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(createError("Ошибка при обновлении новеллы: " + e.getMessage()));
        }
    }

    @DeleteMapping("/books/{id}")
    @Transactional
    public ResponseEntity<?> deleteBook(@PathVariable Long id) {
        return bookRepository.findById(id)
                .map(book -> {
                    // Собираем ID глав для удаления уведомлений (chapter_id → NO ACTION)
                    List<Chapter> chapters = chapterRepository.findByBookIdOrderByChapterOrderAsc(id);
                    List<Long> chapterIds = chapters.stream()
                            .map(Chapter::getId)
                            .collect(Collectors.toList());

                    // Удаляем уведомления (book_id и chapter_id — NO ACTION FK)
                    notificationRepository.deleteByBookId(id);
                    if (!chapterIds.isEmpty()) {
                        notificationRepository.deleteByChapterIdIn(chapterIds);
                    }

                    // Удаляем рейтинги (book_id — NO ACTION FK)
                    bookRatingRepository.deleteByBookId(id);

                    // Удаляем главы
                    chapterRepository.deleteAll(chapters);

                    // Удаляем файл обложки
                    deleteOldCover(book.getCoverUrl());

                    // Удаляем книгу (остальные FK: CASCADE — user_books, reviews,
                    // comments, related_books, book_genres — удалятся автоматически)
                    bookRepository.delete(book);
                    return ResponseEntity.ok(createSuccess("Новелла удалена"));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/covers/{filename}")
    public ResponseEntity<Resource> getCover(@PathVariable String filename) {
        try {
            Path filePath = Paths.get("assets/covers").resolve(filename);
            Resource resource = new UrlResource(filePath.toUri());

            if (resource.exists() && resource.isReadable()) {
                String contentType = Files.probeContentType(filePath);
                if (contentType == null) contentType = "image/jpeg";
                return ResponseEntity.ok()
                        .contentType(MediaType.parseMediaType(contentType))
                        .body(resource);
            } else {
                return ResponseEntity.notFound().build();
            }
        } catch (IOException e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/books/{bookId}/chapters")
    public ResponseEntity<List<Chapter>> getChapters(@PathVariable Long bookId) {
        return ResponseEntity.ok(chapterRepository.findByBookIdOrderByChapterOrderAsc(bookId));
    }

    @PostMapping("/books/{bookId}/chapters")
    public ResponseEntity<?> createChapter(@PathVariable Long bookId, @RequestBody ChapterDTO dto) {
        return bookRepository.findById(bookId)
                .map(book -> {
                    Chapter chapter = new Chapter();
                    chapter.setBook(book);
                    chapter.setchapterOrder(dto.getChapterOrder());
                    chapter.setTitle(dto.getTitle());
                    chapter.setContent(dto.getContent());
                    Chapter saved = chapterRepository.save(chapter);

                    List<UserBook> bookmarkedUsers = userBookRepository.findByBookIdAndSubscribedTrue(bookId);
                    List<Notification> notifications = new ArrayList<>(bookmarkedUsers.size());
                    for (UserBook ub : bookmarkedUsers) {
                        Notification notification = new Notification();
                        notification.setRecipient(ub.getUser());
                        notification.setType(NotificationType.NEW_CHAPTER);
                        notification.setTitle("Новая глава!");
                        notification.setMessage("Вышла глава " + saved.getchapterOrder() + " в новелле \"" + book.getTitle() + "\"");
                        notification.setBook(book);
                        notification.setChapter(saved);
                        notifications.add(notification);
                    }
                    notificationRepository.saveAll(notifications);

                    return ResponseEntity.ok(saved);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/books/{bookId}/chapters/{chapterId}")
    public ResponseEntity<?> updateChapter(
            @PathVariable Long bookId,
            @PathVariable Long chapterId,
            @RequestBody ChapterDTO dto) {
        return chapterRepository.findById(chapterId)
                .map(chapter -> {
                    if (dto.getChapterOrder() != null) chapter.setchapterOrder(dto.getChapterOrder());
                    if (dto.getTitle() != null) chapter.setTitle(dto.getTitle());
                    if (dto.getContent() != null) chapter.setContent(dto.getContent());
                    return ResponseEntity.ok(chapterRepository.save(chapter));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/books/{bookId}/chapters/{chapterId}")
    public ResponseEntity<?> deleteChapter(@PathVariable Long bookId, @PathVariable Long chapterId) {
        return chapterRepository.findById(chapterId)
                .map(chapter -> {
                    chapterRepository.delete(chapter);
                    return ResponseEntity.ok(createSuccess("Глава удалена"));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/users")
    public ResponseEntity<List<User>> getAllUsers() {
        return ResponseEntity.ok(userRepository.findAll());
    }

    @GetMapping("/genres")
    public ResponseEntity<List<Genre>> getAllGenres() {
        return ResponseEntity.ok(genreRepository.findAll());
    }

    @DeleteMapping("/users/{id}")
    public ResponseEntity<?> deleteUser(@PathVariable Long id) {
        return userRepository.findById(id)
                .map(user -> {
                    if ("ADMIN".equals(user.getRole()) && userRepository.countByRole("ADMIN") <= 1) {
                        return ResponseEntity.status(HttpStatus.FORBIDDEN)
                                .body(createError("Нельзя удалить последнего администратора"));
                    }
                    userRepository.delete(user);
                    return ResponseEntity.ok(createSuccess("Пользователь удалён"));
                })
                .orElse(ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(createError("Пользователь не найден")));
    }

    @PutMapping("/users/{id}/role")
    public ResponseEntity<?> updateUserRole(@PathVariable Long id, @RequestBody Map<String, String> body) {
        String newRole = body.get("role");
        if (newRole == null || newRole.isEmpty()) {
            return ResponseEntity.badRequest().body(createError("Роль не указана"));
        }
        return userRepository.findById(id)
                .map(user -> {
                    user.setRole(newRole);
                    userRepository.save(user);
                    return ResponseEntity.ok(createSuccess("Роль пользователя обновлена до " + newRole));
                })
                .orElse(ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(createError("Пользователь не найден")));
    }

    private String saveCoverFile(MultipartFile cover) {
        try {
            Path uploadPath = Paths.get("assets/covers");
            if (!Files.exists(uploadPath)) Files.createDirectories(uploadPath);

            String fileName = System.currentTimeMillis() + "_" + cover.getOriginalFilename();
            Path filePath = uploadPath.resolve(fileName);
            Files.copy(cover.getInputStream(), filePath, StandardCopyOption.REPLACE_EXISTING);

            return "assets/covers/" + fileName;
        } catch (IOException e) {
            return null;
        }
    }

    private void deleteOldCover(String coverUrl) {
        if (coverUrl != null && !coverUrl.isEmpty()) {
            try {
                Files.deleteIfExists(Paths.get(coverUrl));
            } catch (IOException ignored) {}
        }
    }

    private Map<String, String> createError(String message) {
        Map<String, String> map = new HashMap<>();
        map.put("error", message);
        return map;
    }

    private Map<String, String> createSuccess(String message) {
        Map<String, String> map = new HashMap<>();
        map.put("message", message);
        return map;
    }
}
