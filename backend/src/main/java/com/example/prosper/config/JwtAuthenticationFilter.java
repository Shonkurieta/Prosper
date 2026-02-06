package com.example.prosper.config;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.MalformedJwtException;
import io.jsonwebtoken.security.SignatureException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private UserDetailsService userDetailsService;

    private static final List<String> PUBLIC_PATHS = Arrays.asList(
        "/api/auth/",
        "/api/books",
        "/api/genres",
        "/api/test/",
        "/covers/",
        "/assets/"
    );

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        
        String path = request.getRequestURI();
        
        System.out.println("🔒 [JwtAuthenticationFilter] Processing request:");
        System.out.println("   URI: " + path);
        System.out.println("   Method: " + request.getMethod());
        
        // Skip JWT check for public resources
        if (isPublicPath(path)) {
            System.out.println("   ✅ Public resource - skipping JWT check");
            filterChain.doFilter(request, response);
            return;
        }
        
        try {
            final String authHeader = request.getHeader("Authorization");

            // No Authorization header or not Bearer token
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                System.out.println("   ℹ️ No JWT token found, continuing chain");
                filterChain.doFilter(request, response);
                return;
            }

            // Extract token
            final String jwt = authHeader.substring(7);
            System.out.println("   Token (first 30 chars): " + jwt.substring(0, Math.min(30, jwt.length())) + "...");

            // Extract username from token
            final String username = jwtUtil.extractUsername(jwt);
            System.out.println("   Username from token: " + username);

            // Authenticate if username exists and not already authenticated
            if (username != null && SecurityContextHolder.getContext().getAuthentication() == null) {
                authenticateUser(request, jwt, username);
            }

        } catch (ExpiredJwtException e) {
            System.err.println("   ❌ JWT token expired: " + e.getMessage());
        } catch (MalformedJwtException e) {
            System.err.println("   ❌ Malformed JWT token: " + e.getMessage());
        } catch (SignatureException e) {
            System.err.println("   ❌ Invalid JWT signature: " + e.getMessage());
        } catch (IllegalArgumentException e) {
            System.err.println("   ❌ Invalid JWT argument: " + e.getMessage());
        } catch (RuntimeException e) {
            System.err.println("   ❌ JWT authentication error: " + e.getClass().getSimpleName() + " - " + e.getMessage());
        }
        
        filterChain.doFilter(request, response);
    }

    private boolean isPublicPath(String path) {
        return PUBLIC_PATHS.stream().anyMatch(path::startsWith);
    }

    private void authenticateUser(HttpServletRequest request, String jwt, String username) {
        // Load UserDetails
        UserDetails userDetails = userDetailsService.loadUserByUsername(username);
        System.out.println("   UserDetails loaded for: " + username);
        System.out.println("   UserDetails authorities: " + userDetails.getAuthorities());

        // Validate token
        if (!jwtUtil.isTokenValid(jwt, userDetails)) {
            System.out.println("   ❌ Token is invalid");
            return;
        }

        System.out.println("   ✅ Token is valid");

        // Extract authorities from token
        List<SimpleGrantedAuthority> authorities = extractAuthorities(jwt, userDetails);
        System.out.println("   🔑 Final authorities: " + authorities);

        // Create authentication token
        UsernamePasswordAuthenticationToken authToken = new UsernamePasswordAuthenticationToken(
                userDetails,
                null,
                authorities
        );

        authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
        SecurityContextHolder.getContext().setAuthentication(authToken);
        
        System.out.println("   ✅ Authentication set in SecurityContext");
    }

    private List<SimpleGrantedAuthority> extractAuthorities(String jwt, UserDetails userDetails) {
        String authoritiesString = jwtUtil.extractAuthorities(jwt);
        
        if (authoritiesString != null && !authoritiesString.isEmpty()) {
            List<SimpleGrantedAuthority> tokenAuthorities = Arrays.stream(authoritiesString.split(","))
                    .map(SimpleGrantedAuthority::new)
                    .collect(Collectors.toList());
            System.out.println("   🔑 Authorities from token: " + tokenAuthorities);
            return tokenAuthorities;
        }
        
        // Fallback to UserDetails authorities
        List<SimpleGrantedAuthority> userAuthorities = userDetails.getAuthorities().stream()
                .map(auth -> new SimpleGrantedAuthority(auth.getAuthority()))
                .collect(Collectors.toList());
        System.out.println("   🔑 Authorities from UserDetails: " + userAuthorities);
        return userAuthorities;
    }
}