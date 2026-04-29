package com.reportt.complaintapp.exception;

import org.springframework.http.HttpStatus;

public enum ApiErrorCategory {
    VALIDATION,
    AUTHENTICATION,
    AUTHORIZATION,
    BUSINESS,
    RATE_LIMIT,
    SYSTEM;

    public static ApiErrorCategory fromStatus(HttpStatus status) {
        if (status == HttpStatus.BAD_REQUEST || status == HttpStatus.UNPROCESSABLE_ENTITY || status == HttpStatus.PAYLOAD_TOO_LARGE) {
            return VALIDATION;
        }
        if (status == HttpStatus.UNAUTHORIZED) {
            return AUTHENTICATION;
        }
        if (status == HttpStatus.FORBIDDEN) {
            return AUTHORIZATION;
        }
        if (status == HttpStatus.TOO_MANY_REQUESTS) {
            return RATE_LIMIT;
        }
        if (status.is5xxServerError()) {
            return SYSTEM;
        }
        return BUSINESS;
    }
}
