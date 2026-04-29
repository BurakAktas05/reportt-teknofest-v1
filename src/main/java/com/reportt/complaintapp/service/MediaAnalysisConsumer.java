package com.reportt.complaintapp.service;

import com.reportt.complaintapp.config.RabbitMQConfig;
import com.reportt.complaintapp.domain.ComplaintReport;
import com.reportt.complaintapp.domain.EvidenceMedia;
import com.reportt.complaintapp.domain.enums.ReportStatus;
import com.reportt.complaintapp.domain.ReportFeedback;
import com.reportt.complaintapp.repository.ComplaintReportRepository;
import com.reportt.complaintapp.repository.EvidenceMediaRepository;
import com.reportt.complaintapp.repository.ReportFeedbackRepository;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MediaAnalysisConsumer {

    private final ComplaintReportRepository complaintReportRepository;
    private final EvidenceMediaRepository evidenceMediaRepository;
    private final ReportFeedbackRepository reportFeedbackRepository;
    private final FileStorageService fileStorageService;
    private final MediaInspectionService mediaInspectionService;

    public MediaAnalysisConsumer(
            ComplaintReportRepository complaintReportRepository,
            EvidenceMediaRepository evidenceMediaRepository,
            ReportFeedbackRepository reportFeedbackRepository,
            FileStorageService fileStorageService,
            MediaInspectionService mediaInspectionService) {
        this.complaintReportRepository = complaintReportRepository;
        this.evidenceMediaRepository = evidenceMediaRepository;
        this.reportFeedbackRepository = reportFeedbackRepository;
        this.fileStorageService = fileStorageService;
        this.mediaInspectionService = mediaInspectionService;
    }

    @Transactional
    @RabbitListener(queues = RabbitMQConfig.MEDIA_ANALYSIS_QUEUE)
    public void processMediaAnalysis(Long reportId) {
        ComplaintReport report = complaintReportRepository.findById(reportId).orElse(null);
        if (report == null || report.getStatus() != ReportStatus.PENDING_ANALYSIS) {
            return;
        }

        List<EvidenceMedia> evidences = evidenceMediaRepository.findByComplaintReportIdOrderByCreatedAtAsc(reportId);
        boolean isSpam = false;
        boolean needsReview = false;

        for (EvidenceMedia evidence : evidences) {
            if ("S3".equals(evidence.getStorageProvider())) {
                Path tempFile = fileStorageService.downloadToTempFile(evidence.getStoragePath());
                try {
                    MediaInspectionResult result = mediaInspectionService.inspect(tempFile, evidence.getContentType(), report.getCategory());
                    evidence.setAnalysisStatus(result.analysisStatus());
                    evidence.setAnalysisSummary(result.summary());
                    evidence.setAnalysisRawJson(result.rawJson());
                    evidence.setOutdoorConfidence(result.outdoorConfidence());
                    evidence.setSelfieRisk(result.selfieRisk());
                    evidence.setDetectedPlate(result.detectedPlate());
                    evidence.setReviewRequired(result.reviewRequired());
                    evidenceMediaRepository.save(evidence);

                    if (result.selfieRisk() != null && result.selfieRisk() > 0.8) {
                        isSpam = true;
                    }
                    if (result.outdoorConfidence() != null && result.outdoorConfidence() < 0.3) {
                        isSpam = true;
                    }
                    if (Boolean.TRUE.equals(result.reviewRequired())) {
                        needsReview = true;
                    }

                } finally {
                    try { Files.deleteIfExists(tempFile); } catch (Exception ignored) {}
                }
            }
        }

        if (isSpam) {
            report.setStatus(ReportStatus.REJECTED_BY_SYSTEM);
            createFeedback(report, "Sistem tarafindan analiz sonucu SPAM olarak degerlendirildi ve reddedildi.");
        } else {
            report.setStatus(ReportStatus.SUBMITTED);
            if (needsReview) {
                createFeedback(report, "Otomatik inceleme bazi medya dosyalarinda dis mekan veya selfie supheleri gordu. Kayit manuel kontrole alinabilir.");
            }
        }
        complaintReportRepository.save(report);
    }

    private void createFeedback(ComplaintReport report, String message) {
        ReportFeedback feedback = new ReportFeedback();
        feedback.setComplaintReport(report);
        feedback.setAuthor(report.getCitizen());
        feedback.setMessage(message);
        feedback.setInternalNote(false);
        reportFeedbackRepository.save(feedback);
    }
}
