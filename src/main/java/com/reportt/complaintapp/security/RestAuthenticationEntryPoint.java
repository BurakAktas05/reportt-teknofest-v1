package com.reportt.complaintapp.security;

import com.reportt.complaintapp.exception.ApiErrorResponseFactory;
import com.reportt.complaintapp.exception.ErrorCode;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

@Component
public class RestAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ApiErrorResponseFactory errorResponseFactory;

    public RestAuthenticationEntryPoint(ApiErrorResponseFactory errorResponseFactory) {
        this.errorResponseFactory = errorResponseFactory;
    }

    @Override
    public void commence(
            HttpServletRequest request,
            HttpServletResponse response,
            AuthenticationException authException
    ) throws IOException {
        errorResponseFactory.write(
                request,
                response,
                ErrorCode.AUTH_REQUIRED,
                "Bu islem icin gecerli bir erisim belirteci gereklidir.",
                List.of()
        );
    }
}
