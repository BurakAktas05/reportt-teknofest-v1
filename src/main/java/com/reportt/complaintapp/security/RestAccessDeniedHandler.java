package com.reportt.complaintapp.security;

import com.reportt.complaintapp.exception.ApiErrorResponseFactory;
import com.reportt.complaintapp.exception.ErrorCode;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

@Component
public class RestAccessDeniedHandler implements AccessDeniedHandler {

    private final ApiErrorResponseFactory errorResponseFactory;

    public RestAccessDeniedHandler(ApiErrorResponseFactory errorResponseFactory) {
        this.errorResponseFactory = errorResponseFactory;
    }

    @Override
    public void handle(
            HttpServletRequest request,
            HttpServletResponse response,
            AccessDeniedException accessDeniedException
    ) throws IOException {
        errorResponseFactory.write(request, response, ErrorCode.ACCESS_DENIED);
    }
}
