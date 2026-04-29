package com.reportt.complaintapp.dto.auth;

import jakarta.validation.constraints.NotBlank;

public record LoginRequest(
        @NotBlank String phoneNumber,
        @NotBlank String password
) {
}
