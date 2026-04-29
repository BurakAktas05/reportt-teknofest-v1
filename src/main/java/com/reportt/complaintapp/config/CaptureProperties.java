package com.reportt.complaintapp.config;

import jakarta.validation.constraints.Min;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.capture")
public record CaptureProperties(@Min(1) long sessionValidityMinutes) {
}
