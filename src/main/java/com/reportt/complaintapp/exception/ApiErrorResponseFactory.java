package com.reportt.complaintapp.exception;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.OffsetDateTime;
import java.util.List;
import org.slf4j.MDC;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;

@Component
public class ApiErrorResponseFactory {

    public static final String REQUEST_ID_ATTRIBUTE = "requestId";
    public static final String REQUEST_ID_HEADER = "X-Request-Id";

    private final ObjectMapper objectMapper;

    public ApiErrorResponseFactory(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public ApiErrorResponse build(HttpServletRequest request, ErrorCode errorCode) {
        return build(request, errorCode, errorCode.getUserMessage(), List.of());
    }

    public ApiErrorResponse build(HttpServletRequest request, ErrorCode errorCode, String message) {
        return build(request, errorCode, message, List.of());
    }

    public ApiErrorResponse build(
            HttpServletRequest request,
            ErrorCode errorCode,
            String message,
            List<ApiFieldViolation> fieldErrors
    ) {
        return new ApiErrorResponse(
                resolveRequestId(request),
                errorCode.getStatus().value(),
                errorCode.getStatus().getReasonPhrase(),
                errorCode.getCode(),
                errorCode.getCategory().name(),
                message,
                errorCode.isRetryable(),
                request.getRequestURI(),
                OffsetDateTime.now(),
                fieldErrors
        );
    }

    public void write(HttpServletRequest request, HttpServletResponse response, ErrorCode errorCode) throws IOException {
        write(request, response, errorCode, errorCode.getUserMessage(), List.of());
    }

    public void write(
            HttpServletRequest request,
            HttpServletResponse response,
            ErrorCode errorCode,
            String message,
            List<ApiFieldViolation> fieldErrors
    ) throws IOException {
        ApiErrorResponse errorResponse = build(request, errorCode, message, fieldErrors);
        response.setStatus(errorCode.getStatus().value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setHeader(REQUEST_ID_HEADER, errorResponse.requestId());
        objectMapper.writeValue(response.getOutputStream(), errorResponse);
    }

    private String resolveRequestId(HttpServletRequest request) {
        Object requestId = request.getAttribute(REQUEST_ID_ATTRIBUTE);
        if (requestId instanceof String value && !value.isBlank()) {
            return value;
        }
        String mdcRequestId = MDC.get(REQUEST_ID_ATTRIBUTE);
        return mdcRequestId == null ? "unknown" : mdcRequestId;
    }
}
