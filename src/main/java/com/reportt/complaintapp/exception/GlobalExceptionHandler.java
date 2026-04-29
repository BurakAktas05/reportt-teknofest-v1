package com.reportt.complaintapp.exception;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    private final ApiErrorResponseFactory errorResponseFactory;

    public GlobalExceptionHandler(ApiErrorResponseFactory errorResponseFactory) {
        this.errorResponseFactory = errorResponseFactory;
    }

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ApiErrorResponse> handleApiException(ApiException exception, HttpServletRequest request) {
        log.warn(
                "requestId={} path={} code={} category={}",
                request.getAttribute(ApiErrorResponseFactory.REQUEST_ID_ATTRIBUTE),
                request.getRequestURI(),
                exception.getCode(),
                exception.getCategory()
        );
        return ResponseEntity.status(exception.getStatus())
                .body(new ApiErrorResponse(
                        String.valueOf(request.getAttribute(ApiErrorResponseFactory.REQUEST_ID_ATTRIBUTE)),
                        exception.getStatus().value(),
                        exception.getStatus().getReasonPhrase(),
                        exception.getCode(),
                        exception.getCategory().name(),
                        exception.getMessage(),
                        exception.isRetryable(),
                        request.getRequestURI(),
                        java.time.OffsetDateTime.now(),
                        List.of()
                ));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiErrorResponse> handleValidation(MethodArgumentNotValidException exception, HttpServletRequest request) {
        return ResponseEntity.badRequest()
                .body(errorResponseFactory.build(
                        request,
                        ErrorCode.VALIDATION_ERROR,
                        ErrorCode.VALIDATION_ERROR.getUserMessage(),
                        exception.getBindingResult().getFieldErrors().stream()
                                .map(this::toFieldViolation)
                                .toList()
                ));
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiErrorResponse> handleConstraintViolation(ConstraintViolationException exception, HttpServletRequest request) {
        return ResponseEntity.badRequest()
                .body(errorResponseFactory.build(request, ErrorCode.VALIDATION_ERROR));
    }

    @ExceptionHandler({BadCredentialsException.class})
    public ResponseEntity<ApiErrorResponse> handleBadCredentials(HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(errorResponseFactory.build(request, ErrorCode.AUTH_INVALID, "Telefon numarasi veya sifre hatali."));
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, MissingServletRequestPartException.class})
    public ResponseEntity<ApiErrorResponse> handleUnreadablePayload(HttpServletRequest request) {
        return ResponseEntity.badRequest()
                .body(errorResponseFactory.build(request, ErrorCode.INVALID_PAYLOAD));
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<ApiErrorResponse> handleUploadSize(MaxUploadSizeExceededException exception, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE)
                .body(errorResponseFactory.build(request, ErrorCode.FILE_TOO_LARGE));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiErrorResponse> handleUnhandled(Exception exception, HttpServletRequest request) {
        log.error(
                "requestId={} path={} unexpectedError",
                request.getAttribute(ApiErrorResponseFactory.REQUEST_ID_ATTRIBUTE),
                request.getRequestURI(),
                exception
        );
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(errorResponseFactory.build(request, ErrorCode.UNEXPECTED_ERROR));
    }

    private ApiFieldViolation toFieldViolation(FieldError fieldError) {
        return new ApiFieldViolation(fieldError.getField(), fieldError.getDefaultMessage());
    }
}
