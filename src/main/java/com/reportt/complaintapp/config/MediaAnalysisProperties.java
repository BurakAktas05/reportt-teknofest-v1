package com.reportt.complaintapp.config;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.media-analysis")
public record MediaAnalysisProperties(
        boolean enabled,
        @NotBlank String pythonCommand,
        @NotBlank String scriptPath,
        @Min(1) int timeoutSeconds
) {
}
