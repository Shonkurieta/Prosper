package com.example.prosper.controller;

import java.util.HashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.UUID;

import com.example.prosper.config.JwtUtil;
import com.example.prosper.model.User;
import com.example.prosper.repository.UserRepository;

@RestController
@RequestMapping("/api/user")
@CrossOrigin(origins = "*")
public class UserController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private UserDetailsService userDetailsService;

    @GetMapping("/profile")
    public ResponseEntity<?> getProfile(@RequestHeader("Authorization") String token) {
        String identifier = jwtUtil.extractUsername(token.replace("Bearer ", ""));
        
        User user = userRepository.findByNickname(identifier)
                .orElseGet(() -> userRepository.findByEmail(identifier).orElse(null));
        
        if (user == null) {
            return ResponseEntity.notFound().build();
        }
        
        Map<String, Object> profile = new HashMap<>();
        profile.put("username", user.getNickname());
        profile.put("email", user.getEmail());
        profile.put("nickname", user.getNickname());
        profile.put("role", user.getRole());
        profile.put("avatarUrl", user.getAvatarUrl());
        return ResponseEntity.ok(profile);
    }

    @PutMapping("/nickname")
    public ResponseEntity<?> updateNickname(
            @RequestHeader("Authorization") String token,
            @RequestBody Map<String, String> request) {
        String identifier = jwtUtil.extractUsername(token.replace("Bearer ", ""));
        String nickname = request.get("nickname");
        
        if (nickname == null || nickname.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "Никнейм не может быть пустым"));
        }

        User user = userRepository.findByNickname(identifier)
                .orElseGet(() -> userRepository.findByEmail(identifier).orElse(null));
        
        if (user == null) {
            return ResponseEntity.notFound().build();
        }

        if (userRepository.findByNickname(nickname).isPresent()) {
            return ResponseEntity.badRequest().body(Map.of("message", "Никнейм уже занят"));
        }
        
        user.setNickname(nickname);
        userRepository.save(user);

        UserDetails userDetails = userDetailsService.loadUserByUsername(user.getNickname());
        String newToken = jwtUtil.generateToken(user.getId(), userDetails);

        Map<String, Object> response = new HashMap<>();
        response.put("message", "Никнейм успешно обновлён");
        response.put("token", newToken);
        response.put("nickname", user.getNickname());
        
        return ResponseEntity.ok(response);
    }

    @PutMapping("/password")
    public ResponseEntity<?> changePassword(
            @RequestHeader("Authorization") String token,
            @RequestBody Map<String, String> request) {
        String identifier = jwtUtil.extractUsername(token.replace("Bearer ", ""));
        String oldPassword = request.get("oldPassword");
        String newPassword = request.get("newPassword");
        
        if (newPassword == null || newPassword.length() < 8) {
            return ResponseEntity.badRequest().body(
                Map.of("message", "Пароль должен содержать минимум 8 символов")
            );
        }

        User user = userRepository.findByNickname(identifier)
                .orElseGet(() -> userRepository.findByEmail(identifier).orElse(null));
        
        if (user == null) {
            return ResponseEntity.notFound().build();
        }
        
        if (!passwordEncoder.matches(oldPassword, user.getPassword())) {
            return ResponseEntity.badRequest().body(
                Map.of("message", "Неверный старый пароль")
            );
        }
        
        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);
        
        return ResponseEntity.ok(Map.of("message", "Пароль успешно изменён"));
    }

    @PostMapping("/avatar")
    public ResponseEntity<?> updateAvatar(
            @RequestHeader("Authorization") String token,
            @RequestParam("avatar") MultipartFile file) {
        String identifier = jwtUtil.extractUsername(token.replace("Bearer ", ""));
        
        User user = userRepository.findByNickname(identifier)
                .orElseGet(() -> userRepository.findByEmail(identifier).orElse(null));
        
        if (user == null) {
            return ResponseEntity.notFound().build();
        }

        if (file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "Файл не выбран"));
        }

        try {
            String uploadDir = "assets/avatars/";
            Path uploadPath = Paths.get(uploadDir);
            if (!Files.exists(uploadPath)) {
                Files.createDirectories(uploadPath);
            }

            String originalFilename = file.getOriginalFilename();
            String extension = originalFilename != null && originalFilename.contains(".") 
                ? originalFilename.substring(originalFilename.lastIndexOf(".")) 
                : ".jpg";
            String fileName = UUID.randomUUID().toString() + extension;
            Path filePath = uploadPath.resolve(fileName);
            Files.copy(file.getInputStream(), filePath, StandardCopyOption.REPLACE_EXISTING);

            String avatarUrl = "/assets/avatars/" + fileName;
            user.setAvatarUrl(avatarUrl);
            userRepository.save(user);

            return ResponseEntity.ok(Map.of(
                "message", "Аватар успешно обновлён",
                "avatarUrl", avatarUrl
            ));
        } catch (IOException e) {
            return ResponseEntity.internalServerError().body(Map.of("message", "Ошибка при сохранении файла: " + e.getMessage()));
        }
    }
}