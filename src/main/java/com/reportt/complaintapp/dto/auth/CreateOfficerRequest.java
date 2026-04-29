package com.reportt.complaintapp.dto.auth;

import com.reportt.complaintapp.domain.enums.UserRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record CreateOfficerRequest(
        @NotBlank @Size(max = 120) String fullName,
        @NotBlank @Pattern(regexp = "^[0-9+]{10,20}$") String phoneNumber,
        @Email @Size(max = 120) String email,
        @NotBlank @Size(min = 8, max = 64) String password,
        UserRole role,
        Long stationId
) {
}
