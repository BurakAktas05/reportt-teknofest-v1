package com.reportt.complaintapp.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final String code;
    private final ApiErrorCategory category;
    private final boolean retryable;

    public ApiException(HttpStatus status, String code, String message) {
        super(message);
        this.status = status;
        this.code = code;
        this.category = ApiErrorCategory.fromStatus(status);
        this.retryable = status == HttpStatus.TOO_MANY_REQUESTS || status.is5xxServerError();
    }

    public ApiException(ErrorCode errorCode) {
        super(errorCode.getUserMessage());
        this.status = errorCode.getStatus();
        this.code = errorCode.getCode();
        this.category = errorCode.getCategory();
        this.retryable = errorCode.isRetryable();
    }

    public ApiException(ErrorCode errorCode, String message) {
        super(message);
        this.status = errorCode.getStatus();
        this.code = errorCode.getCode();
        this.category = errorCode.getCategory();
        this.retryable = errorCode.isRetryable();
    }
}
