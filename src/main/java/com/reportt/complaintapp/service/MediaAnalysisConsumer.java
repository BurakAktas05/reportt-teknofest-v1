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

/**
 * RabbitMQ üzerinden gelen medya analiz görevlerini işleyen asenkron tüketici.
 *
 * <h3>V2: Hybrid AI Çapraz Doğrulama (Modül 1)</h3>
 * <p>Python media_guard.py'den gelen aciliyet skorunu istemci ön skoruyla karşılaştırır.
 * Fark belirli bir eşiğin üstündeyse (±3) bayrak kaldırır ve derin inceleme talep eder.
 * Bu hibrit yaklaşım hem edge manipülasyonunu hem de sunucu tarafı hatalarını tespit eder.</p>
 */
@Service
public class MediaAnalysisConsumer {

    /** İstemci-sunucu urgency skoru farkı bu eşiği geçerse bayrak kaldırılır. */
    private static final int HYBRID_SCORE_DIVERGENCE_THRESHOLD = 3;

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
        int maxUrgencyScore = 0;
        StringBuilder triageSummaryBuilder = new StringBuilder();

        for (EvidenceMedia evidence : evidences) {
            if ("S3".equals(evidence.getStorageProvider())) {
                Path tempFile = fileStorageService.downloadToTempFile(evidence.getStoragePath());
                try {
                    // V2: description parametresi NLP analizi için gönderiliyor
                    MediaInspectionResult result = mediaInspectionService.inspect(
                            tempFile,
                            evidence.getContentType(),
                            report.getCategory(),
                            report.getDescription()
                    );

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

                    // V2: Aciliyet skoru toplama
                    if (result.urgencyScore() != null && result.urgencyScore() > maxUrgencyScore) {
                        maxUrgencyScore = result.urgencyScore();
                    }
                    if (result.nlpSummary() != null && !result.nlpSummary().isBlank()) {
                        triageSummaryBuilder.append(result.nlpSummary()).append(" ");
                    }

                } finally {
                    try { Files.deleteIfExists(tempFile); } catch (Exception ignored) {}
                }
            }
        }

        // V2 Modül 1: İstemci ön skorunu kaydet (sunucu skoru yazılmadan ÖNCE)
        int clientScore = report.getUrgencyScore();

        // V2 Modül 1: Sunucu urgency skorunu kaydet
        report.setUrgencyScore(maxUrgencyScore);
        report.setAiTriageSummary(triageSummaryBuilder.toString().trim());

        // V2 Modül 1: Hybrid Check — istemci ön skoru ile sunucu skorunu karşılaştır
        boolean hybridDivergence = Math.abs(maxUrgencyScore - clientScore) > HYBRID_SCORE_DIVERGENCE_THRESHOLD;

        if (isSpam) {
            report.setStatus(ReportStatus.REJECTED_BY_SYSTEM);
            createFeedback(report, "Sistem tarafindan analiz sonucu SPAM olarak degerlendirildi ve reddedildi.");
        } else {
            report.setStatus(ReportStatus.SUBMITTED);
            if (needsReview) {
                createFeedback(report, "Otomatik inceleme bazi medya dosyalarinda dis mekan veya selfie supheleri gordu. Kayit manuel kontrole alinabilir.");
            }
            if (hybridDivergence) {
                createFeedback(report,
                        "HIBRIT UYARI: Istemci on skoru (" + clientScore + ") ile sunucu AI skoru (" + maxUrgencyScore
                                + ") arasinda belirgin sapma tespit edildi. Manuel inceleme onerilir.");
                needsReview = true;
            }
            if (maxUrgencyScore >= 8) {
                createFeedback(report,
                        "YUKSEK ONCELIK: AI aciliyet skoru " + maxUrgencyScore + "/10. Bu ihbar oncelikli olarak degerlendirilmelidir.");
            }
        }

        // Sunucu urgency skorunu güncelle (clientScore override)
        report.setUrgencyScore(maxUrgencyScore > 0 ? maxUrgencyScore : clientScore);
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
