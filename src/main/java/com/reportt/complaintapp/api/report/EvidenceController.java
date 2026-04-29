package com.reportt.complaintapp.api.report;

import com.reportt.complaintapp.config.ObjectStorageProperties;
import com.reportt.complaintapp.domain.EvidenceMedia;
import com.reportt.complaintapp.domain.ComplaintReport;
import com.reportt.complaintapp.exception.ApiException;
import com.reportt.complaintapp.exception.ErrorCode;
import com.reportt.complaintapp.repository.EvidenceMediaRepository;
import com.reportt.complaintapp.service.CurrentUserService;
import com.reportt.complaintapp.service.ReportAccessPolicy;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedGetObjectRequest;

/**
 * Kanıt medya dosyaları için presigned URL endpoint'i.
 * MinIO/S3'ten güvenli geçici URL oluşturur.
 */
@Tag(name = "Evidence", description = "Kanıt medya dosyası erişimi")
@RestController
@RequestMapping("/api/evidence")
public class EvidenceController {

    private final EvidenceMediaRepository evidenceMediaRepository;
    private final CurrentUserService currentUserService;
    private final ReportAccessPolicy reportAccessPolicy;
    private final S3Presigner s3Presigner;
    private final ObjectStorageProperties storageProperties;

    public EvidenceController(
            EvidenceMediaRepository evidenceMediaRepository,
            CurrentUserService currentUserService,
            ReportAccessPolicy reportAccessPolicy,
            S3Presigner s3Presigner,
            ObjectStorageProperties storageProperties
    ) {
        this.evidenceMediaRepository = evidenceMediaRepository;
        this.currentUserService = currentUserService;
        this.reportAccessPolicy = reportAccessPolicy;
        this.s3Presigner = s3Presigner;
        this.storageProperties = storageProperties;
    }

    @Operation(summary = "Kanıt dosyası presigned URL", description = "15 dakika geçerli MinIO/S3 presigned URL döndürür.")
    @GetMapping("/{evidenceId}/url")
    public EvidenceUrlResponse getPresignedUrl(@PathVariable Long evidenceId) {
        var user = currentUserService.getCurrentUser();
        EvidenceMedia evidence = evidenceMediaRepository.findById(evidenceId)
                .orElseThrow(() -> new ApiException(ErrorCode.REPORT_NOT_FOUND));

        ComplaintReport report = evidence.getComplaintReport();
        reportAccessPolicy.assertCanAccessReport(report, user);

        GetObjectRequest getObjectRequest = GetObjectRequest.builder()
                .bucket(storageProperties.bucket())
                .key(evidence.getStoragePath())
                .build();

        PresignedGetObjectRequest presigned = s3Presigner.presignGetObject(
                GetObjectPresignRequest.builder()
                        .signatureDuration(Duration.ofMinutes(15))
                        .getObjectRequest(getObjectRequest)
                        .build()
        );

        return new EvidenceUrlResponse(
                evidenceId,
                presigned.url().toString(),
                evidence.getContentType(),
                evidence.getOriginalFileName(),
                15
        );
    }

    public record EvidenceUrlResponse(
            Long evidenceId,
            String url,
            String contentType,
            String fileName,
            int expiresInMinutes
    ) {}
}
