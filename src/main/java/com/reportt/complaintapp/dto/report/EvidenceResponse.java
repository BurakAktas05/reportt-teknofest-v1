package com.reportt.complaintapp.dto.report;

public record EvidenceResponse(
        Long id,
        String evidenceType,
        String originalFileName,
        String contentType,
        Long fileSize,
        String analysisStatus,
        String analysisSummary,
        Double outdoorConfidence,
        Double selfieRisk,
        String detectedPlate,
        boolean reviewRequired
) {
}
