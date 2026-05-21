package com.example.prosper.controller;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.prosper.config.JwtUtil;
import com.example.prosper.model.User;
import com.example.prosper.repository.PasswordResetTokenRepository;
import com.example.prosper.repository.UserRepository;
import com.example.prosper.service.EmailService;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private UserDetailsService userDetailsService;

    @Autowired
    private EmailService emailService;

    @Autowired
    private PasswordResetTokenRepository tokenRepository;

    @Value("${google.client.id}")
    private String googleClientId;

    @PostMapping("/google")
    public ResponseEntity<?> googleLogin(
            @RequestBody Map<String, String> request
    ) {
        try {

            String idTokenString = request.get("idToken");

            if (idTokenString == null || idTokenString.isEmpty()) {
                return ResponseEntity.badRequest()
                        .body(Map.of(
                                "message",
                                "ID Token is required"
                        ));
            }

            System.out.println("TOKEN: " + idTokenString);

            GoogleIdTokenVerifier verifier =
                    new GoogleIdTokenVerifier.Builder(
                            new NetHttpTransport(),
                            GsonFactory.getDefaultInstance()
                    ).build();

            GoogleIdToken idToken =
                    verifier.verify(idTokenString);

            if (idToken == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(Map.of(
                                "message",
                                "Invalid ID Token"
                        ));
            }

            GoogleIdToken.Payload payload =
                    idToken.getPayload();

            System.out.println(
                    "AUDIENCE: " + payload.getAudience()
            );

            System.out.println(
                    "EMAIL: " + payload.getEmail()
            );

            String email = payload.getEmail();

            String googleId =
                    payload.getSubject();

            String name =
                    (String) payload.get("name");

            String pictureUrl =
                    (String) payload.get("picture");

            Optional<User> userOpt =
                    userRepository.findByGoogleId(
                            googleId
                    );

            if (userOpt.isEmpty()) {
                userOpt =
                        userRepository.findByEmail(email);
            }

            User user;

            if (userOpt.isPresent()) {

                user = userOpt.get();

                if (user.getGoogleId() == null) {
                    user.setGoogleId(googleId);
                }

                if (user.getAvatarUrl() == null) {
                    user.setAvatarUrl(pictureUrl);
                }

                user = userRepository.save(user);

            } else {

                user = new User();

                user.setEmail(email);

                user.setGoogleId(googleId);

                user.setNickname(
                        name != null
                                ? name
                                : email.split("@")[0]
                );

                user.setAvatarUrl(pictureUrl);

                user.setPassword(
                        passwordEncoder.encode(
                                java.util.UUID
                                        .randomUUID()
                                        .toString()
                        )
                );

                user.setRole("USER");

                user = userRepository.save(user);
            }

            UserDetails userDetails =
                    userDetailsService.loadUserByUsername(
                            user.getNickname()
                    );

            String token =
                    jwtUtil.generateToken(
                            user.getId(),
                            userDetails
                    );

            Map<String, Object> response =
                    new HashMap<>();

            response.put("token", token);
            response.put("username", user.getNickname());
            response.put("email", user.getEmail());
            response.put("role", user.getRole());
            response.put("id", user.getId());
            response.put("avatar_url", user.getAvatarUrl());

            return ResponseEntity.ok(response);

        } catch (Exception e) {

            e.printStackTrace();

            return ResponseEntity.status(
                    HttpStatus.INTERNAL_SERVER_ERROR
            ).body(
                    Map.of(
                            "message",
                            "Google Auth Error: "
                                    + e.getMessage()
                    )
            );
        }
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(
            @RequestBody Map<String, String> request
    ) {
        try {

            String nickname = request.get("username");
            String email = request.get("email");
            String password = request.get("password");

            if (nickname == null || nickname.trim().isEmpty()) {
                return ResponseEntity.badRequest()
                        .body(Map.of(
                                "message",
                                "Имя пользователя обязательно"
                        ));
            }

            if (email == null || email.trim().isEmpty()) {
                return ResponseEntity.badRequest()
                        .body(Map.of(
                                "message",
                                "Email обязателен"
                        ));
            }

            if (password == null || password.trim().isEmpty()) {
                return ResponseEntity.badRequest()
                        .body(Map.of(
                                "message",
                                "Пароль обязателен"
                        ));
            }

            if (userRepository.findByNickname(nickname).isPresent()) {
                return ResponseEntity.badRequest()
                        .body(Map.of(
                                "message",
                                "Пользователь с таким именем уже существует"
                        ));
            }

            if (userRepository.findByEmail(email).isPresent()) {
                return ResponseEntity.badRequest()
                        .body(Map.of(
                                "message",
                                "Email уже используется"
                        ));
            }

            User user = new User();

            user.setNickname(nickname);
            user.setEmail(email);

            user.setPassword(
                    passwordEncoder.encode(password)
            );

            user.setRole("USER");

            User savedUser =
                    userRepository.save(user);

            UserDetails userDetails =
                    userDetailsService.loadUserByUsername(
                            nickname
                    );

            String token =
                    jwtUtil.generateToken(
                            savedUser.getId(),
                            userDetails
                    );

            Map<String, Object> response =
                    new HashMap<>();

            response.put("token", token);
            response.put("username", user.getNickname());
            response.put("email", user.getEmail());
            response.put("role", user.getRole());
            response.put("id", user.getId());

            return ResponseEntity.ok(response);

        } catch (DataAccessException e) {

            return ResponseEntity.status(
                    HttpStatus.INTERNAL_SERVER_ERROR
            ).body(
                    Map.of(
                            "message",
                            "Ошибка базы данных при регистрации"
                    )
            );

        } catch (Exception e) {

            return ResponseEntity.status(
                    HttpStatus.INTERNAL_SERVER_ERROR
            ).body(
                    Map.of(
                            "message",
                            "Ошибка регистрации: "
                                    + e.getMessage()
                    )
            );
        }
    }
}