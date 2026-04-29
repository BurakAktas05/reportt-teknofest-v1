package com.reportt.complaintapp.config;

import jakarta.validation.constraints.Min;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.rate-limit")
public record RateLimitProperties(
        @Min(1) long authCapacity,
        @Min(1) long authRefillTokens,
        @Min(1) long authRefillMinutes,
        @Min(1) long reportCapacity,
        @Min(1) long reportRefillTokens,
        @Min(1) long reportRefillMinutes,
        @Min(1) long defaultCapacity,
        @Min(1) long defaultRefillTokens,
        @Min(1) long defaultRefillMinutes
) {
}
