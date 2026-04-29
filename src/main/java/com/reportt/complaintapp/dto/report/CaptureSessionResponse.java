package com.reportt.complaintapp.dto.report;

import java.time.LocalDateTime;

public record CaptureSessionResponse(
        String sessionToken,
        LocalDateTime expiresAt
) {
}
