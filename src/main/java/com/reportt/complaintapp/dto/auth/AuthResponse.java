package com.reportt.complaintapp.dto.auth;

public record AuthResponse(
        Long userId,
        String fullName,
        String phoneNumber,
        String role,
        Integer reputationScore,
        String accessToken
) {
}
