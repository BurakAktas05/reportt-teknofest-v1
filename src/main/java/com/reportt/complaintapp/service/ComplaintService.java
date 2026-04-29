package com.reportt.complaintapp.service;

import com.reportt.complaintapp.config.RabbitMQConfig;
import com.reportt.complaintapp.config.ScoringProperties;
import com.reportt.complaintapp.config.TrustScoreProperties;
import com.reportt.complaintapp.domain.ComplaintReport;
import com.reportt.complaintapp.domain.EvidenceMedia;
import com.reportt.complaintapp.domain.PoliceStation;
import com.reportt.complaintapp.domain.ReportFeedback;
import com.reportt.complaintapp.domain.UserAccount;
import com.reportt.complaintapp.domain.enums.ReportStatus;
import com.reportt.complaintapp.domain.enums.UserRole;
import com.reportt.complaintapp.dto.report.CreateReportRequest;
import com.reportt.complaintapp.dto.report.FeedbackRequest;
import com.reportt.complaintapp.dto.report.FeedbackResponse;
import com.reportt.complaintapp.dto.report.ReportResponse;
import com.reportt.complaintapp.dto.report.ReportStatusUpdateRequest;
import com.reportt.complaintapp.exception.ApiException;
import com.reportt.complaintapp.exception.ErrorCode;
import com.reportt.complaintapp.repository.ComplaintReportRepository;
import com.reportt.complaintapp.repository.EvidenceMediaRepository;
import com.reportt.complaintapp.repository.ReportFeedbackRepository;
import com.reportt.complaintapp.repository.UserAccountRepository;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import org.locationtech.jts.geom.Point;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/**
 * İhbar yaşam döngüsünü yöneten ana servis.
 *
 * <h3>V2 Genişletmeleri</h3>
 * <ul>
 *   <li><b>Modül 1 — Smart Triage:</b> Cihaz doğrulama + istemci ön skor kaydı</li>
 *   <li><b>Modül 2 — Dijital Mühür:</b> SHA-256 hash doğrulaması (istemci ↔ sunucu)</li>
 *   <li><b>Modül 4 — PostGIS Routing:</b> Polygon-first karakol ataması (PoliceStationService içinde)</li>
 *   <li><b>Modül 5 — Güven Puanı:</b> Güvenilir vatandaş bypass kuralı + sayaç güncellemesi</li>
 *   <li><b>Modül 6 — Offline:</b> offlineCreatedAt zaman damgası</li>
 * </ul>
 */
@Service
public class ComplaintService {

    private final ComplaintReportRepository complaintReportRepository;
    private final EvidenceMediaRepository evidenceMediaRepository;
    private final ReportFeedbackRepository reportFeedbackRepository;
    private final UserAccountRepository userAccountRepository;
    private final CaptureSessionService captureSessionService;
    private final PoliceStationService policeStationService;
    private final GeoPointService geoPointService;
    private final FileStorageService fileStorageService;
    private final ScoringProperties scoringProperties;
    private final TrustScoreProperties trustScoreProperties;
    private final ReportAccessPolicy reportAccessPolicy;
    private final ReportResponseMapper reportResponseMapper;
    private final RabbitTemplate rabbitTemplate;
    private final DeviceAttestationService deviceAttestationService;
    private final SseService sseService;
    private final NotificationService notificationService;

    public ComplaintService(
            ComplaintReportRepository complaintReportRepository,
            EvidenceMediaRepository evidenceMediaRepository,
            ReportFeedbackRepository reportFeedbackRepository,
            UserAccountRepository userAccountRepository,
            CaptureSessionService captureSessionService,
            PoliceStationService policeStationService,
            GeoPointService geoPointService,
            FileStorageService fileStorageService,
            ScoringProperties scoringProperties,
            TrustScoreProperties trustScoreProperties,
            ReportAccessPolicy reportAccessPolicy,
            ReportResponseMapper reportResponseMapper,
            RabbitTemplate rabbitTemplate,
            DeviceAttestationService deviceAttestationService,
            SseService sseService,
            NotificationService notificationService
    ) {
        this.complaintReportRepository = complaintReportRepository;
        this.evidenceMediaRepository = evidenceMediaRepository;
        this.reportFeedbackRepository = reportFeedbackRepository;
        this.userAccountRepository = userAccountRepository;
        this.captureSessionService = captureSessionService;
        this.policeStationService = policeStationService;
        this.geoPointService = geoPointService;
        this.fileStorageService = fileStorageService;
        this.scoringProperties = scoringProperties;
        this.trustScoreProperties = trustScoreProperties;
        this.reportAccessPolicy = reportAccessPolicy;
        this.reportResponseMapper = reportResponseMapper;
        this.rabbitTemplate = rabbitTemplate;
        this.deviceAttestationService = deviceAttestationService;
        this.sseService = sseService;
        this.notificationService = notificationService;
    }

    @Transactional
    public ReportResponse createReport(UserAccount citizen, CreateReportRequest request, List<MultipartFile> files) {
        reportAccessPolicy.assertCitizenCanCreate(citizen);
        if (files == null || files.isEmpty()) {
            throw new ApiException(ErrorCode.EVIDENCE_REQUIRED);
        }

        captureSessionService.validateAndConsume(request.captureSessionToken(), citizen);
        Point reportPoint = geoPointService.createPoint(request.latitude(), request.longitude());

        // V2 Modül 4: Polygon-first karakol ataması (PostGIS ST_Contains)
        PoliceStation station = policeStationService.findNearest(request.latitude(), request.longitude());

        // V2 Modül 1: Zero-Trust cihaz doğrulama
        boolean deviceVerified = deviceAttestationService.verify(request.deviceAttestationToken());

        // V2 Modül 5: Güvenilir vatandaş bypass kuralı
        boolean isTrustedCitizen = citizen.getReputationScore() >= trustScoreProperties.bypassThreshold()
                && citizen.getVerifiedReportCount() >= trustScoreProperties.minimumVerifiedReports();

        ComplaintReport report = new ComplaintReport();
        report.setCitizen(citizen);
        report.setAssignedStation(station);
        report.setTitle(request.title());
        report.setDescription(request.description());
        report.setCategory(request.category());
        report.setIncidentAt(request.incidentAt());
        report.setReportedPoint(reportPoint);
        report.setAddressText(request.addressText());
        report.setLiveCaptureConfirmed(true);

        // V2 alanları
        report.setDeviceAttestationToken(request.deviceAttestationToken());
        report.setDeviceVerified(deviceVerified);
        report.setUrgencyScore(request.clientUrgencyScore() != null ? request.clientUrgencyScore() : 0);
        report.setOfflineCreatedAt(request.offlineCreatedAt());

        // V2 Modül 5: Trust bypass
        if (isTrustedCitizen) {
            report.setStatus(ReportStatus.SUBMITTED);
            report.setBypassAnalysis(true);
        } else {
            report.setStatus(ReportStatus.PENDING_ANALYSIS);
            report.setBypassAnalysis(false);
        }

        ComplaintReport savedReport = complaintReportRepository.save(report);

        // Dosya işleme + V2 Modül 2: Kriptografik hash doğrulama
        List<String> clientHashes = request.evidenceHashes();
        List<EvidenceMedia> evidences = new ArrayList<>();

        for (int i = 0; i < files.size(); i++) {
            MultipartFile file = files.get(i);
            Path tempFile = createTempFile(file);
            try {
                // V2 Modül 2: Sunucu tarafında SHA-256 hesapla
                String serverHash = fileStorageService.computeSha256(tempFile);
                boolean hashVerified = false;

                // İstemci hash gönderildiyse bütünlük doğrula
                if (clientHashes != null && i < clientHashes.size() && clientHashes.get(i) != null) {
                    String clientHash = clientHashes.get(i);
                    if (!serverHash.equalsIgnoreCase(clientHash)) {
                        throw new ApiException(ErrorCode.EVIDENCE_HASH_MISMATCH,
                                "Dosya " + (i + 1) + " hash uyumsuzlugu: istemci=" + clientHash + " sunucu=" + serverHash);
                    }
                    hashVerified = true;
                }

                // MinIO'ya yükle
                FileStorageService.StoredFile stored = fileStorageService.store(
                        tempFile,
                        file.getOriginalFilename(),
                        file.getContentType(),
                        file.getSize(),
                        savedReport.getId()
                );

                EvidenceMedia evidenceMedia = new EvidenceMedia();
                evidenceMedia.setComplaintReport(savedReport);
                evidenceMedia.setEvidenceType(stored.contentType() != null && stored.contentType().startsWith("video/")
                        ? com.reportt.complaintapp.domain.enums.EvidenceType.VIDEO
                        : com.reportt.complaintapp.domain.enums.EvidenceType.PHOTO);
                evidenceMedia.setOriginalFileName(file.getOriginalFilename() == null ? "unknown" : Path.of(file.getOriginalFilename()).getFileName().toString());
                evidenceMedia.setContentType(stored.contentType());
                evidenceMedia.setStoragePath(stored.storagePath());
                evidenceMedia.setStorageProvider(stored.storageProvider());
                evidenceMedia.setFileSize(stored.fileSize());
                evidenceMedia.setAnalysisStatus(com.reportt.complaintapp.domain.enums.MediaAnalysisStatus.PENDING);
                evidenceMedia.setReviewRequired(false);

                // V2 Modül 2: Hash kaydet
                evidenceMedia.setSha256Hash(serverHash);
                evidenceMedia.setHashVerified(hashVerified);

                evidences.add(evidenceMediaRepository.save(evidenceMedia));
            } finally {
                deleteTempFile(tempFile);
            }
        }

        // Geri bildirim ve analiz kuyruğu
        if (isTrustedCitizen) {
            createFeedback(savedReport, citizen,
                    "Guvenilir vatandas statunuz nedeniyle ihbariniz AI bekleme sirasi atlanarak dogrudan yonlendirildi.", false);
        } else {
            createFeedback(savedReport, citizen,
                    "Sikayetiniz sisteme alindi ve analiz icin siraya eklendi.", false);
            rabbitTemplate.convertAndSend(RabbitMQConfig.MEDIA_ANALYSIS_QUEUE, savedReport.getId());
        }

        return reportResponseMapper.toReportResponse(savedReport, evidences, listVisibleFeedback(savedReport.getId(), citizen), citizen);
    }

    @Transactional(readOnly = true)
    public List<ReportResponse> listCitizenReports(UserAccount citizen) {
        return complaintReportRepository.findByCitizenOrderByCreatedAtDesc(citizen).stream()
                .map(report -> reportResponseMapper.toReportResponse(
                        report,
                        evidenceMediaRepository.findByComplaintReportIdOrderByCreatedAtAsc(report.getId()),
                        listVisibleFeedback(report.getId(), citizen),
                        citizen
                ))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<ReportResponse> listAssignedReports(UserAccount officer) {
        reportAccessPolicy.assertOfficerCapabilities(officer);

        if (officer.getRole() == UserRole.ADMIN) {
            return complaintReportRepository.findAll().stream()
                    .map(report -> reportResponseMapper.toReportResponse(
                            report,
                            evidenceMediaRepository.findByComplaintReportIdOrderByCreatedAtAsc(report.getId()),
                            listVisibleFeedback(report.getId(), officer),
                            officer
                    ))
                    .toList();
        }
        if (officer.getAssignedStation() == null) {
            throw new ApiException(ErrorCode.OFFICER_STATION_REQUIRED);
        }

        return complaintReportRepository.findByAssignedStationIdOrderByCreatedAtDesc(officer.getAssignedStation().getId()).stream()
                .map(report -> reportResponseMapper.toReportResponse(
                        report,
                        evidenceMediaRepository.findByComplaintReportIdOrderByCreatedAtAsc(report.getId()),
                        listVisibleFeedback(report.getId(), officer),
                        officer
                ))
                .toList();
    }

    @Transactional(readOnly = true)
    public ReportResponse getReport(Long reportId, UserAccount actor) {
        ComplaintReport report = findReport(reportId);
        reportAccessPolicy.assertCanAccessReport(report, actor);

        return reportResponseMapper.toReportResponse(
                report,
                evidenceMediaRepository.findByComplaintReportIdOrderByCreatedAtAsc(reportId),
                listVisibleFeedback(reportId, actor),
                actor
        );
    }

    @Transactional
    public FeedbackResponse addFeedback(Long reportId, UserAccount actor, FeedbackRequest request) {
        ComplaintReport report = findReport(reportId);
        reportAccessPolicy.assertOfficerCapabilities(actor);
        reportAccessPolicy.assertCanAccessReport(report, actor);

        boolean internalNote = Boolean.TRUE.equals(request.internalNote());

        ReportFeedback feedback = createFeedback(report, actor, request.message(), internalNote);
        return reportResponseMapper.toFeedbackResponse(feedback);
    }

    @Transactional
    public ReportResponse updateStatus(Long reportId, UserAccount officer, ReportStatusUpdateRequest request) {
        ComplaintReport report = findReport(reportId);
        reportAccessPolicy.assertOfficerCapabilities(officer);
        reportAccessPolicy.assertCanAccessReport(report, officer);

        ReportStatus previousStatus = report.getStatus();
        report.setStatus(request.status());
        ComplaintReport saved = complaintReportRepository.save(report);

        applyScoreIfNeeded(saved, previousStatus, request.status());
        createFeedback(saved, officer, "Sikayet durumu " + request.status().name() + " olarak guncellendi.", false);

        // V3: SSE ile vatandaşa gerçek zamanlı bildirim
        try {
            sseService.sendToUser(saved.getCitizen().getId(), "report_update", java.util.Map.of(
                    "reportId", saved.getId(),
                    "newStatus", request.status().name(),
                    "message", "Ihbariniz " + request.status().name() + " durumuna guncellendi."
            ));
        } catch (Exception ignored) { /* SSE bağlantısı yoksa hata vermesin */ }

        // V3: FCM Push Notification ile vatandaşa bildirim
        try {
            notificationService.notifyReportStatusChange(
                    saved.getCitizen(), saved.getId(), request.status().name());
        } catch (Exception ignored) { /* FCM hatası uygulamayı durdurmasın */ }

        return reportResponseMapper.toReportResponse(
                saved,
                evidenceMediaRepository.findByComplaintReportIdOrderByCreatedAtAsc(reportId),
                listVisibleFeedback(reportId, officer),
                officer
        );
    }

    private ComplaintReport findReport(Long reportId) {
        return complaintReportRepository.findById(reportId)
                .orElseThrow(() -> new ApiException(ErrorCode.REPORT_NOT_FOUND));
    }

    private List<FeedbackResponse> listVisibleFeedback(Long reportId, UserAccount actor) {
        return reportFeedbackRepository.findByComplaintReportIdOrderByCreatedAtAsc(reportId).stream()
                .filter(feedback -> actor.getRole() != UserRole.CITIZEN || !feedback.isInternalNote())
                .map(reportResponseMapper::toFeedbackResponse)
                .toList();
    }

    private ReportFeedback createFeedback(ComplaintReport report, UserAccount author, String message, boolean internalNote) {
        ReportFeedback feedback = new ReportFeedback();
        feedback.setComplaintReport(report);
        feedback.setAuthor(author);
        feedback.setMessage(message);
        feedback.setInternalNote(internalNote);
        return reportFeedbackRepository.save(feedback);
    }

    /**
     * V2 Modül 5: Puanlama ve sayaç güncelleme mantığı.
     *
     * <ul>
     *   <li>VERIFIED: +puan, verifiedReportCount++</li>
     *   <li>REJECTED / REJECTED_BY_SYSTEM: -puan, rejectedReportCount++</li>
     * </ul>
     */
    private void applyScoreIfNeeded(ComplaintReport report, ReportStatus previousStatus, ReportStatus newStatus) {
        if (previousStatus == newStatus) {
            return;
        }

        UserAccount citizen = report.getCitizen();
        if (newStatus == ReportStatus.VERIFIED) {
            citizen.setReputationScore(citizen.getReputationScore() + scoringProperties.verifiedReportPoints());
            citizen.setVerifiedReportCount(citizen.getVerifiedReportCount() + 1);
            userAccountRepository.save(citizen);
            return;
        }

        if (newStatus == ReportStatus.REJECTED || newStatus == ReportStatus.REJECTED_BY_SYSTEM) {
            citizen.setReputationScore(Math.max(0, citizen.getReputationScore() - scoringProperties.rejectedReportPenalty()));
            citizen.setRejectedReportCount(citizen.getRejectedReportCount() + 1);
            userAccountRepository.save(citizen);
        }
    }

    private Path createTempFile(MultipartFile file) {
        try {
            String suffix = resolveSuffix(file.getOriginalFilename());
            Path tempFile = Files.createTempFile("complaint-media-", suffix);
            file.transferTo(tempFile);
            return tempFile;
        } catch (IOException exception) {
            throw new ApiException(ErrorCode.FILE_STORE_FAILED, "Yuklenen medya gecici dosyaya yazilamadi.");
        }
    }

    private void deleteTempFile(Path tempFile) {
        try {
            Files.deleteIfExists(tempFile);
        } catch (IOException ignored) {
        }
    }

    private String resolveSuffix(String fileName) {
        if (fileName == null) {
            return ".bin";
        }
        int index = fileName.lastIndexOf('.');
        return index >= 0 ? fileName.substring(index) : ".bin";
    }
}
