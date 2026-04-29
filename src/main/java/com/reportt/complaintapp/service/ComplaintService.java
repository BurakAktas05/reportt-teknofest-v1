package com.reportt.complaintapp.service;

import com.reportt.complaintapp.config.ScoringProperties;
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
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import com.reportt.complaintapp.config.RabbitMQConfig;

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
    private final ReportAccessPolicy reportAccessPolicy;
    private final ReportResponseMapper reportResponseMapper;
    private final RabbitTemplate rabbitTemplate;

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
            ReportAccessPolicy reportAccessPolicy,
            ReportResponseMapper reportResponseMapper,
            RabbitTemplate rabbitTemplate
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
        this.reportAccessPolicy = reportAccessPolicy;
        this.reportResponseMapper = reportResponseMapper;
        this.rabbitTemplate = rabbitTemplate;
    }

    @Transactional
    public ReportResponse createReport(UserAccount citizen, CreateReportRequest request, List<MultipartFile> files) {
        reportAccessPolicy.assertCitizenCanCreate(citizen);
        if (files == null || files.isEmpty()) {
            throw new ApiException(ErrorCode.EVIDENCE_REQUIRED);
        }

        captureSessionService.validateAndConsume(request.captureSessionToken(), citizen);
        Point reportPoint = geoPointService.createPoint(request.latitude(), request.longitude());
        PoliceStation station = policeStationService.findNearest(request.latitude(), request.longitude());

        ComplaintReport report = new ComplaintReport();
        report.setCitizen(citizen);
        report.setAssignedStation(station);
        report.setTitle(request.title());
        report.setDescription(request.description());
        report.setCategory(request.category());
        report.setStatus(ReportStatus.PENDING_ANALYSIS);
        report.setIncidentAt(request.incidentAt());
        report.setReportedPoint(reportPoint);
        report.setAddressText(request.addressText());
        report.setLiveCaptureConfirmed(true);

        ComplaintReport savedReport = complaintReportRepository.save(report);

        List<EvidenceMedia> evidences = new ArrayList<>();
        for (MultipartFile file : files) {
            Path tempFile = createTempFile(file);
            try {
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
                evidences.add(evidenceMediaRepository.save(evidenceMedia));
            } finally {
                deleteTempFile(tempFile);
            }
        }

        createFeedback(savedReport, citizen, "Sikayetiniz sisteme alindi ve analiz icin siraya eklendi.", false);
        rabbitTemplate.convertAndSend(RabbitMQConfig.MEDIA_ANALYSIS_QUEUE, savedReport.getId());

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

    private void applyScoreIfNeeded(ComplaintReport report, ReportStatus previousStatus, ReportStatus newStatus) {
        if (previousStatus == newStatus) {
            return;
        }

        UserAccount citizen = report.getCitizen();
        if (newStatus == ReportStatus.VERIFIED) {
            citizen.setReputationScore(citizen.getReputationScore() + scoringProperties.verifiedReportPoints());
            userAccountRepository.save(citizen);
            return;
        }

        if (newStatus == ReportStatus.REJECTED) {
            citizen.setReputationScore(Math.max(0, citizen.getReputationScore() - scoringProperties.rejectedReportPenalty()));
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
