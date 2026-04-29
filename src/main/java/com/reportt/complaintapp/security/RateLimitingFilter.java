package com.reportt.complaintapp.security;

import com.reportt.complaintapp.config.RateLimitProperties;
import com.reportt.complaintapp.exception.ApiErrorResponseFactory;
import com.reportt.complaintapp.exception.ErrorCode;
import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Refill;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
public class RateLimitingFilter extends OncePerRequestFilter {

    private final ApiErrorResponseFactory errorResponseFactory;
    private final RateLimitProperties properties;
    private final Map<String, Bucket> buckets = new ConcurrentHashMap<>();

    public RateLimitingFilter(ApiErrorResponseFactory errorResponseFactory, RateLimitProperties properties) {
        this.errorResponseFactory = errorResponseFactory;
        this.properties = properties;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String clientKey = resolveClientKey(request);
        Bucket bucket = buckets.computeIfAbsent(clientKey, key -> createBucketForPath(request.getRequestURI()));

        if (bucket.tryConsume(1)) {
            filterChain.doFilter(request, response);
            return;
        }

        errorResponseFactory.write(request, response, ErrorCode.RATE_LIMIT_EXCEEDED);
    }

    private String resolveClientKey(HttpServletRequest request) {
        String authorization = request.getHeader("Authorization");
        String subject = authorization != null ? authorization : request.getRemoteAddr();
        return request.getRequestURI() + "::" + subject;
    }

    private Bucket createBucketForPath(String path) {
        // Auth ve rapor endpointlerini daha siki sinirlayip kaba kuvvet ve spam ihtimalini dusuruyoruz.
        if (path.startsWith("/api/auth")) {
            return newBucket(properties.authCapacity(), properties.authRefillTokens(), properties.authRefillMinutes());
        }
        if (path.startsWith("/api/reports")) {
            return newBucket(properties.reportCapacity(), properties.reportRefillTokens(), properties.reportRefillMinutes());
        }
        return newBucket(properties.defaultCapacity(), properties.defaultRefillTokens(), properties.defaultRefillMinutes());
    }

    private Bucket newBucket(long capacity, long refillTokens, long refillMinutes) {
        Bandwidth limit = Bandwidth.classic(capacity, Refill.greedy(refillTokens, Duration.ofMinutes(refillMinutes)));
        return Bucket.builder().addLimit(limit).build();
    }
}
