package com.reportt.complaintapp.dto.report;

import java.time.LocalDateTime;

public record FeedbackResponse(
        Long id,
        String authorName,
        String authorRole,
        String message,
        boolean internalNote,
        LocalDateTime createdAt
) {
}
