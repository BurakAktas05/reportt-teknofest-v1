package com.reportt.complaintapp.dto.report;

import java.time.LocalDateTime;
import java.util.List;

public record ReportResponse(
        Long id,
        String title,
        String description,
        String category,
        String status,
        LocalDateTime incidentAt,
        Double latitude,
        Double longitude,
        String addressText,
        boolean liveCaptureConfirmed,
        String citizenName,
        Integer citizenScore,
        String assignedStationName,
        String assignedStationDistrict,
        LocalDateTime createdAt,
        List<EvidenceResponse> evidences,
        List<FeedbackResponse> feedback,

        // ── V2 alanları ─────────────────────────────────────
        int urgencyScore,
        boolean deviceVerified,
        String aiTriageSummary,
        boolean bypassAnalysis
) {
}
