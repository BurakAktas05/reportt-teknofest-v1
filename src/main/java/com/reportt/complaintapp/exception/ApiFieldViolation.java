package com.reportt.complaintapp.exception;

public record ApiFieldViolation(
        String field,
        String message
) {
}
