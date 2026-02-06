package com.example.prosper.config;

import java.security.Key;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.MalformedJwtException;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import io.jsonwebtoken.security.SignatureException;

@Component
public class JwtUtil {

    private static final String SECRET_KEY = "FangSparrow33344@1$_SecretKey_ForJWT2025";
    private static final long EXPIRATION_TIME = 1000 * 60 * 60 * 10; // 10 часов
    private final Key key = Keys.hmacShaKeyFor(SECRET_KEY.getBytes());

    // === Генерация токена ===
    public String generateToken(Long userId, UserDetails userDetails) {
        Map<String, Object> claims = new HashMap<>();
        
        claims.put("userId", userId);
        
        String authorities = userDetails.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .collect(Collectors.joining(","));
        
        claims.put("authorities", authorities);
        
        System.out.println("🔹 Generating JWT token");
        System.out.println("   User ID: " + userId);
        System.out.println("   Username (nickname): " + userDetails.getUsername());
        System.out.println("   Authorities: " + authorities);
        
        // ✅ В subject храним nickname, а userId в claims
        String token = createToken(claims, userDetails.getUsername());
        System.out.println("   Token created (first 30 chars): " + token.substring(0, Math.min(30, token.length())) + "...");
        
        return token;
    }

    private String createToken(Map<String, Object> claims, String subject) {
        Date now = new Date(System.currentTimeMillis());
        Date expiration = new Date(System.currentTimeMillis() + EXPIRATION_TIME);
        
        System.out.println("   Issued at: " + now);
        System.out.println("   Expires at: " + expiration);
        
        return Jwts.builder()
                .setClaims(claims)
                .setSubject(subject)
                .setIssuedAt(now)
                .setExpiration(expiration)
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();
    }

    // === Извлечение userId из claims ===
    public Long extractUserId(String token) {
        try {
            Claims claims = extractAllClaims(token);
            Object userIdObj = claims.get("userId");
            
            if (userIdObj == null) {
                System.err.println("❌ userId is null in token");
                return null;
            }
            
            Long userId;
            if (userIdObj instanceof Integer intValue) {
                userId = intValue.longValue();
            } else if (userIdObj instanceof Long longValue) {
                userId = longValue;
            } else {
                System.err.println("❌ Unexpected userId type: " + userIdObj.getClass());
                return null;
            }
            
            System.out.println("🔹 Extracted userId from token: " + userId);
            return userId;
        } catch (ExpiredJwtException e) {
            System.err.println("❌ Token expired while extracting userId: " + e.getMessage());
            throw e;
        } catch (MalformedJwtException e) {
            System.err.println("❌ Malformed token while extracting userId: " + e.getMessage());
            throw e;
        } catch (SignatureException e) {
            System.err.println("❌ Invalid signature while extracting userId: " + e.getMessage());
            throw e;
        } catch (IllegalArgumentException e) {
            System.err.println("❌ Invalid argument while extracting userId: " + e.getMessage());
            throw e;
        } catch (RuntimeException e) {
            System.err.println("❌ Error extracting userId: " + e.getClass().getSimpleName() + " - " + e.getMessage());
            throw e;
        }
    }

    // ✅ Извлечение nickname из subject
    public String extractUsername(String token) {
        return extractClaim(token, Claims::getSubject);
    }

    public Date extractExpiration(String token) {
        return extractClaim(token, Claims::getExpiration);
    }

    // Извлечение authorities из токена
    public String extractAuthorities(String token) {
        try {
            Claims claims = extractAllClaims(token);
            String authorities = claims.get("authorities", String.class);
            System.out.println("🔹 Extracted authorities from token: " + authorities);
            return authorities;
        } catch (ExpiredJwtException e) {
            System.err.println("❌ Token expired while extracting authorities: " + e.getMessage());
            return null;
        } catch (MalformedJwtException e) {
            System.err.println("❌ Malformed token while extracting authorities: " + e.getMessage());
            return null;
        } catch (SignatureException e) {
            System.err.println("❌ Invalid signature while extracting authorities: " + e.getMessage());
            return null;
        } catch (IllegalArgumentException e) {
            System.err.println("❌ Invalid argument while extracting authorities: " + e.getMessage());
            return null;
        } catch (RuntimeException e) {
            System.err.println("❌ Error extracting authorities: " + e.getClass().getSimpleName() + " - " + e.getMessage());
            return null;
        }
    }

    public <T> T extractClaim(String token, Function<Claims, T> claimsResolver) {
        final Claims claims = extractAllClaims(token);
        return claimsResolver.apply(claims);
    }

    private Claims extractAllClaims(String token) {
        try {
            return Jwts.parserBuilder()
                    .setSigningKey(key)
                    .build()
                    .parseClaimsJws(token)
                    .getBody();
        } catch (ExpiredJwtException e) {
            System.err.println("❌ Token expired: " + e.getMessage());
            throw e;
        } catch (MalformedJwtException e) {
            System.err.println("❌ Malformed token: " + e.getMessage());
            throw e;
        } catch (SignatureException e) {
            System.err.println("❌ Invalid signature: " + e.getMessage());
            throw e;
        } catch (IllegalArgumentException e) {
            System.err.println("❌ Invalid argument: " + e.getMessage());
            throw e;
        } catch (RuntimeException e) {
            System.err.println("❌ Error parsing token: " + e.getClass().getSimpleName() + " - " + e.getMessage());
            throw e;
        }
    }

    // === Проверка токена ===
    private boolean isTokenExpired(String token) {
        try {
            Date expiration = extractExpiration(token);
            Date now = new Date();
            boolean expired = expiration.before(now);
            
            System.out.println("🔹 Token expiration check:");
            System.out.println("   Expires at: " + expiration);
            System.out.println("   Current time: " + now);
            System.out.println("   Is expired: " + expired);
            
            return expired;
        } catch (ExpiredJwtException e) {
            System.err.println("❌ Token already expired: " + e.getMessage());
            return true;
        } catch (MalformedJwtException e) {
            System.err.println("❌ Malformed token during expiration check: " + e.getMessage());
            return true;
        } catch (SignatureException e) {
            System.err.println("❌ Invalid signature during expiration check: " + e.getMessage());
            return true;
        } catch (RuntimeException e) {
            System.err.println("❌ Error checking expiration: " + e.getClass().getSimpleName() + " - " + e.getMessage());
            return true;
        }
    }

    // Валидация по userId
    public boolean isTokenValid(String token, Long userId) {
        try {
            System.out.println("🔹 Validating token:");
            
            final Long tokenUserId = extractUserId(token);
            
            System.out.println("   Token userId: " + tokenUserId);
            System.out.println("   Expected userId: " + userId);
            
            boolean userIdMatches = tokenUserId != null && tokenUserId.equals(userId);
            System.out.println("   UserId matches: " + userIdMatches);
            
            boolean expired = isTokenExpired(token);
            System.out.println("   Token expired: " + expired);
            
            boolean valid = userIdMatches && !expired;
            System.out.println("   Final result: " + (valid ? "✅ VALID" : "❌ INVALID"));
            
            return valid;
        } catch (ExpiredJwtException e) {
            System.err.println("❌ Token expired during validation: " + e.getMessage());
            return false;
        } catch (MalformedJwtException e) {
            System.err.println("❌ Malformed token during validation: " + e.getMessage());
            return false;
        } catch (SignatureException e) {
            System.err.println("❌ Invalid signature during validation: " + e.getMessage());
            return false;
        } catch (NullPointerException e) {
            System.err.println("❌ Null value during validation: " + e.getMessage());
            return false;
        } catch (RuntimeException e) {
            System.err.println("❌ Token validation error: " + e.getClass().getSimpleName() + " - " + e.getMessage());
            return false;
        }
    }

    // Валидация по UserDetails
    public boolean isTokenValid(String token, UserDetails userDetails) {
        try {
            return !isTokenExpired(token);
        } catch (ExpiredJwtException e) {
            System.err.println("❌ Token expired: " + e.getMessage());
            return false;
        } catch (MalformedJwtException e) {
            System.err.println("❌ Malformed token: " + e.getMessage());
            return false;
        } catch (SignatureException e) {
            System.err.println("❌ Invalid signature: " + e.getMessage());
            return false;
        } catch (RuntimeException e) {
            System.err.println("❌ Token validation error: " + e.getClass().getSimpleName() + " - " + e.getMessage());
            return false;
        }
    }
}