package com.example.prosper.config;

import java.util.List;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;

@Configuration
@EnableWebSecurity
public class SecurityConfig {
    
    private final JwtFilter jwtFilter;

    public SecurityConfig(JwtFilter jwtFilter) {
        this.jwtFilter = jwtFilter;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .cors(cors -> cors.configurationSource(request -> {
                CorsConfiguration config = new CorsConfiguration();
                config.setAllowedOrigins(List.of("*"));
                config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
                config.setAllowedHeaders(List.of("*"));
                config.setAllowCredentials(false);
                return config;
            }))
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                // ✅ Публичные эндпоинты
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers("/api/books/**").permitAll()
                .requestMatchers("/api/genres/**").permitAll()
                .requestMatchers("/api/test/**").permitAll()
                
                // ✅ Статические файлы
                .requestMatchers("/covers/**").permitAll()
                .requestMatchers("/assets/**").permitAll()
                .requestMatchers("/assets/covers/**").permitAll()
                
                // ✅ Защищенные эндпоинты
                // В логах видно "Authorities: [ROLE_ADMIN]", поэтому используем hasAnyRole или hasAnyAuthority с ROLE_
                .requestMatchers("/api/admin/**").hasAnyRole("ADMIN", "MODERATOR")
                .requestMatchers("/api/user/**").hasAnyRole("USER", "ADMIN", "MODERATOR")
                .requestMatchers("/api/bookmarks/**").hasAnyRole("USER", "ADMIN", "MODERATOR")
                
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);
        
        return http.build();
    }
}
