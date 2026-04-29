package com.reportt.complaintapp.security;

import com.reportt.complaintapp.config.SecurityProperties;
import com.reportt.complaintapp.domain.UserAccount;
import com.reportt.complaintapp.domain.enums.UserRole;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * JWT Token üretimi ve doğrulama testleri.
 * Access/Refresh token ayrımını, expiration kontrolünü ve
 * kullanıcı bilgisi çıkarmayı doğrular.
 */
class JwtServiceTest {

    private JwtService jwtService;
    private UserAccount testUser;

    @BeforeEach
    void setUp() {
        // 64 byte secret
        SecurityProperties props = new SecurityProperties(
                "0123456789012345678901234567890101234567890123456789012345678901",
                180
        );
        jwtService = new JwtService(props);

        testUser = new UserAccount();
        testUser.setId(42L);
        testUser.setPhoneNumber("5551234567");
        testUser.setFullName("Test Vatandas");
        testUser.setRole(UserRole.CITIZEN);
    }

    @Test
    @DisplayName("Access token üretilmeli ve username çıkarılabilmeli")
    void shouldGenerateAccessToken() {
        String token = jwtService.generateToken(testUser);

        assertNotNull(token);
        assertFalse(token.isEmpty());
        assertEquals("5551234567", jwtService.extractUsername(token));
    }

    @Test
    @DisplayName("Refresh token üretilmeli ve refresh olarak tanınmalı")
    void shouldGenerateRefreshToken() {
        String refreshToken = jwtService.generateRefreshToken(testUser);

        assertNotNull(refreshToken);
        assertTrue(jwtService.isRefreshToken(refreshToken));
    }

    @Test
    @DisplayName("Access token refresh olarak tanınMAmalı")
    void accessTokenShouldNotBeRefresh() {
        String accessToken = jwtService.generateToken(testUser);

        assertFalse(jwtService.isRefreshToken(accessToken));
    }

    @Test
    @DisplayName("Geçerli token expired olmamalı")
    void validTokenShouldNotBeExpired() {
        String token = jwtService.generateToken(testUser);

        assertFalse(jwtService.isTokenExpired(token));
    }

    @Test
    @DisplayName("Geçersiz token için isTokenExpired true dönmeli")
    void invalidTokenShouldBeExpired() {
        assertTrue(jwtService.isTokenExpired("invalid.token.here"));
    }

    @Test
    @DisplayName("Refresh token'dan username çıkarılabilmeli")
    void shouldExtractUsernameFromRefreshToken() {
        String refreshToken = jwtService.generateRefreshToken(testUser);

        assertEquals("5551234567", jwtService.extractUsername(refreshToken));
    }
}
