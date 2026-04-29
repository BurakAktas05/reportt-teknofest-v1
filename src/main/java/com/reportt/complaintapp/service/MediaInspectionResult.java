package com.reportt.complaintapp.service;

import com.reportt.complaintapp.domain.enums.MediaAnalysisStatus;

/**
 * Medya analiz sonuç kaydı.
 * V2 ile urgencyScore ve nlpSummary alanları eklendi.
 */
public record MediaInspectionResult(
        MediaAnalysisStatus analysisStatus,
        String summary,
        Double outdoorConfidence,
        Double selfieRisk,
        String detectedPlate,
        boolean reviewRequired,
        String rawJson,

        // ── V2: Smart Triage ────────────────────────────────
        /** NLP + görüntü analizi ile hesaplanan aciliyet skoru (1-10). */
        Integer urgencyScore,
        /** NLP tarafından üretilen aciliyet özeti. */
        String nlpSummary
) {
    public static MediaInspectionResult failed(String summary) {
        return new MediaInspectionResult(
                MediaAnalysisStatus.FAILED,
                summary,
                null,
                null,
                null,
                true,
                null,
                null,
                null
        );
    }
}
