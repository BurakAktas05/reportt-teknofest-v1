package com.reportt.complaintapp.dto.report;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record FeedbackRequest(
        @NotBlank @Size(max = 500) String message,
        Boolean internalNote
) {
}
