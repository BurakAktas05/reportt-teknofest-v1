package com.reportt.complaintapp.security;

import com.reportt.complaintapp.config.SecurityProperties;
import com.reportt.complaintapp.domain.UserAccount;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.Map;
import java.util.UUID;
import javax.crypto.SecretKey;
import org.springframework.stereotype.Service;

@Service
public class JwtService {

    private final SecurityProperties securityProperties;

    public JwtService(SecurityProperties securityProperties) {
        this.securityProperties = securityProperties;
    }

    /**
     * Access token üretir (kısa ömürlü).
     */
    public String generateToken(UserAccount user) {
        Instant now = Instant.now();
        Instant expiresAt = now.plus(securityProperties.tokenValidityMinutes(), ChronoUnit.MINUTES);

        return Jwts.builder()
                .subject(user.getPhoneNumber())
                .claims(Map.of(
                        "userId", user.getId(),
                        "role", user.getRole().name(),
                        "fullName", user.getFullName(),
                        "type", "access"
                ))
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiresAt))
                .signWith(signingKey())
                .compact();
    }

    /**
     * Refresh token üretir (uzun ömürlü — 7 gün).
     */
    public String generateRefreshToken(UserAccount user) {
        Instant now = Instant.now();
        Instant expiresAt = now.plus(7, ChronoUnit.DAYS);

        return Jwts.builder()
                .subject(user.getPhoneNumber())
                .claims(Map.of(
                        "userId", user.getId(),
                        "type", "refresh",
                        "jti", UUID.randomUUID().toString()
                ))
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiresAt))
                .signWith(signingKey())
                .compact();
    }

    /**
     * Token'ın refresh token olup olmadığını kontrol eder.
     */
    public boolean isRefreshToken(String token) {
        try {
            Claims claims = extractAllClaims(token);
            return "refresh".equals(claims.get("type", String.class));
        } catch (Exception e) {
            return false;
        }
    }

    public String extractUsername(String token) {
        return extractAllClaims(token).getSubject();
    }

    public boolean isTokenValid(String token, CustomUserPrincipal userPrincipal) {
        Claims claims = extractAllClaims(token);
        String phoneNumber = claims.getSubject();
        Date expiration = claims.getExpiration();
        return phoneNumber.equals(userPrincipal.getUsername()) && expiration.after(new Date());
    }

    public boolean isTokenExpired(String token) {
        try {
            return extractAllClaims(token).getExpiration().before(new Date());
        } catch (Exception e) {
            return true;
        }
    }

    private Claims extractAllClaims(String token) {
        return Jwts.parser()
                .verifyWith(signingKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    private SecretKey signingKey() {
        byte[] keyBytes = securityProperties.jwtSecret().getBytes(StandardCharsets.UTF_8);
        return Keys.hmacShaKeyFor(keyBytes);
    }
}
