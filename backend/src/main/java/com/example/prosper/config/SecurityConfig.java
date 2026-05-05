package com.example.prosper.config;

import java.util.List;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
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

    /**
     * Отключаем авто-регистрацию JwtFilter как обычного сервлет-фильтра.
     * Без этого Spring Boot регистрирует @Component-фильтры дважды:
     * один раз как сервлет-фильтр (вне SecurityFilterChain) и один раз
     * через addFilterBefore внутри SecurityFilterChain.
     * Двойная регистрация приводит к непредсказуемому поведению авторизации.
     */
    @Bean
    public FilterRegistrationBean<JwtFilter> jwtFilterRegistration(JwtFilter filter) {
        FilterRegistrationBean<JwtFilter> registration = new FilterRegistrationBean<>(filter);
        registration.setEnabled(false);
        return registration;
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
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers("/api/books/**").permitAll()
                .requestMatchers("/api/genres/**").permitAll()
                .requestMatchers("/api/test/**").permitAll()

                .requestMatchers("/covers/**").permitAll()
                .requestMatchers("/assets/**").permitAll()
                .requestMatchers("/assets/covers/**").permitAll()

                // Только ADMIN и MODERATOR могут управлять пользователями, книгами и т.д.
                .requestMatchers("/api/admin/**").hasAnyRole("ADMIN", "MODERATOR")
                .requestMatchers("/api/user/**").hasAnyRole("USER", "ADMIN", "MODERATOR")
                .requestMatchers("/api/bookmarks/**").hasAnyRole("USER", "ADMIN", "MODERATOR")

                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);
        
        return http.build();
    }
}
