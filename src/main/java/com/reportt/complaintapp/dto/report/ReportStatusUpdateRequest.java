package com.reportt.complaintapp.dto.report;

import com.reportt.complaintapp.domain.enums.ReportStatus;
import jakarta.validation.constraints.NotNull;

public record ReportStatusUpdateRequest(@NotNull ReportStatus status) {
}
