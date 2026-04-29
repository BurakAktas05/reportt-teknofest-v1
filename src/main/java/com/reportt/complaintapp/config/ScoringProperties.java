package com.reportt.complaintapp.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.scoring")
public record ScoringProperties(int verifiedReportPoints, int rejectedReportPenalty) {
}
