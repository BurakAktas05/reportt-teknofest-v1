package com.reportt.complaintapp.config;

import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.object-storage")
public record ObjectStorageProperties(
        @NotBlank String endpoint,
        @NotBlank String region,
        @NotBlank String bucket,
        @NotBlank String accessKey,
        @NotBlank String secretKey,
        boolean pathStyleAccessEnabled,
        boolean autoCreateBucket
) {
}
