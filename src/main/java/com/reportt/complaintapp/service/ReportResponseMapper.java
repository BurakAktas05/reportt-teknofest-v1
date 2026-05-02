package com.reportt.complaintapp.service;

import com.reportt.complaintapp.domain.ComplaintReport;
import com.reportt.complaintapp.domain.EvidenceMedia;
import com.reportt.complaintapp.domain.ReportFeedback;
import com.reportt.complaintapp.dto.report.EvidenceResponse;
import com.reportt.complaintapp.dto.report.FeedbackResponse;
import com.reportt.complaintapp.dto.report.ReportResponse;
import java.util.List;
import org.springframework.stereotype.Component;

@Component
public class ReportResponseMapper {

    public ReportResponse toReportResponse(ComplaintReport report, List<EvidenceMedia> evidences, List<FeedbackResponse> feedback, com.reportt.complaintapp.domain.UserAccount actor) {
        String citizenName = (actor != null && actor.getRole() == com.reportt.complaintapp.domain.enums.UserRole.CITIZEN)
                ? report.getCitizen().getFullName()
                : "Anonim Vatandaş";

        return new ReportResponse(
                report.getId(),
                report.getTitle(),
                report.getDescription(),
                report.getCategory().name(),
                report.getStatus().name(),
                report.getIncidentAt(),
                report.getReportedPoint().getY(),
                report.getReportedPoint().getX(),
                report.getAddressText(),
                report.isLiveCaptureConfirmed(),
                citizenName,
                report.getCitizen().getReputationScore(),
                report.getAssignedStation() != null ? report.getAssignedStation().getStationName() : null,
                report.getAssignedStation() != null ? report.getAssignedStation().getDistrict() : null,
                report.getCreatedAt(),
                evidences.stream()
                        .map(evidence -> new EvidenceResponse(
                                evidence.getId(),
                                evidence.getEvidenceType().name(),
                                evidence.getOriginalFileName(),
                                evidence.getContentType(),
                                evidence.getFileSize(),
                                evidence.getAnalysisStatus().name(),
                                evidence.getAnalysisSummary(),
                                evidence.getOutdoorConfidence(),
                                evidence.getSelfieRisk(),
                                evidence.getDetectedPlate(),
                                evidence.isReviewRequired(),
                                // V2
                                evidence.getSha256Hash(),
                                evidence.isHashVerified()
                        ))
                        .toList(),
                feedback,
                // V2 alanları
                report.getUrgencyScore(),
                report.isDeviceVerified(),
                report.getAiTriageSummary(),
                report.isBypassAnalysis()
        );
    }

    public FeedbackResponse toFeedbackResponse(ReportFeedback feedback) {
        return new FeedbackResponse(
                feedback.getId(),
                feedback.getAuthor().getFullName(),
                feedback.getAuthor().getRole().name(),
                feedback.getMessage(),
                feedback.isInternalNote(),
                feedback.getCreatedAt()
        );
    }
}
