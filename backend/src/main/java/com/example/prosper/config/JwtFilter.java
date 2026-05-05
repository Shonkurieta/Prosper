package com.example.prosper.config;

import java.io.IOException;

import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.example.prosper.service.CustomUserDetailsService;

import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.MalformedJwtException;
import io.jsonwebtoken.security.SignatureException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * JWT-фильтр для проверки токена при каждом запросе.
 *
 * ВАЖНО: Аннотация @Component оставлена для того, чтобы Spring мог
 * инжектировать этот бин в SecurityConfig. Чтобы предотвратить двойную
 * регистрацию фильтра (как сервлет-фильтр И как фильтр в SecurityFilterChain),
 * в SecurityConfig объявлен FilterRegistrationBean с enabled=false.
 */
@Component
public class JwtFilter extends OncePerRequestFilter {
    
    private final JwtUtil jwtUtil;
    private final CustomUserDetailsService userDetailsService;

    public JwtFilter(JwtUtil jwtUtil, CustomUserDetailsService userDetailsService) {
        this.jwtUtil = jwtUtil;
        this.userDetailsService = userDetailsService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {
        
        String path = request.getRequestURI();
        
        if (path.startsWith("/api/auth/") || 
            path.startsWith("/api/books") || 
            path.startsWith("/api/genres") ||
            path.startsWith("/api/test/") ||
            path.startsWith("/covers/") ||
            path.startsWith("/assets/")) {
            filterChain.doFilter(request, response);
            return;
        }
        
        final String authHeader = request.getHeader("Authorization");
        
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }
        
        try {
            final String jwtToken = authHeader.substring(7);
            
            final Long userId = jwtUtil.extractUserId(jwtToken);
            
            if (userId != null && SecurityContextHolder.getContext().getAuthentication() == null) {
                UserDetails userDetails = userDetailsService.loadUserById(userId);
                
                if (jwtUtil.isTokenValid(jwtToken, userId)) {
                    UsernamePasswordAuthenticationToken authToken =
                            new UsernamePasswordAuthenticationToken(
                                    userDetails,
                                    null,
                                    userDetails.getAuthorities()
                            );
                    authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(authToken);
                }
            }
        } catch (ExpiredJwtException e) {
            System.err.println("JWT token expired: " + e.getMessage());
        } catch (MalformedJwtException e) {
            System.err.println("Malformed JWT token: " + e.getMessage());
        } catch (SignatureException e) {
            System.err.println("Invalid JWT signature: " + e.getMessage());
        } catch (UsernameNotFoundException e) {
            System.err.println("User not found: " + e.getMessage());
        } catch (IllegalArgumentException e) {
            System.err.println("Invalid JWT argument: " + e.getMessage());
        } catch (RuntimeException e) {
            System.err.println("JWT Filter error: " + e.getClass().getSimpleName() + " - " + e.getMessage());
        }
        
        filterChain.doFilter(request, response);
    }
}
