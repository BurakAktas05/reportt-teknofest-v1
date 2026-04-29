package com.reportt.complaintapp.service;

import com.reportt.complaintapp.domain.enums.MediaAnalysisStatus;

public record MediaInspectionResult(
        MediaAnalysisStatus analysisStatus,
        String summary,
        Double outdoorConfidence,
        Double selfieRisk,
        String detectedPlate,
        boolean reviewRequired,
        String rawJson
) {
    public static MediaInspectionResult failed(String summary) {
        return new MediaInspectionResult(
                MediaAnalysisStatus.FAILED,
                summary,
                null,
                null,
                null,
                true,
                null
        );
    }
}
