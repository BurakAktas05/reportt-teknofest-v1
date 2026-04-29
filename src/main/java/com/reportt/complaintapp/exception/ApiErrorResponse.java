package com.reportt.complaintapp.exception;

import java.time.OffsetDateTime;
import java.util.List;

public record ApiErrorResponse(
        String requestId,
        Integer status,
        String error,
        String code,
        String category,
        String message,
        boolean retryable,
        String path,
        OffsetDateTime timestamp,
        List<ApiFieldViolation> fieldErrors
) {
}
