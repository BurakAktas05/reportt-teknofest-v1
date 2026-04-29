package com.reportt.complaintapp.dto.report;

import com.reportt.complaintapp.domain.enums.ReportCategory;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDateTime;
import java.util.List;

public record CreateReportRequest(
        @NotBlank @Size(max = 150) String title,
        @NotBlank @Size(max = 4000) String description,
        @NotNull ReportCategory category,
        @NotNull LocalDateTime incidentAt,
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double latitude,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double longitude,
        @Size(max = 255) String addressText,
        @NotBlank String captureSessionToken,

        // ── V2: Kriptografik Kanıt Bütünlüğü ───────────────
        /** Her dosya için istemci tarafında hesaplanan SHA-256 hash listesi (dosya sırasına göre). */
        List<String> evidenceHashes,

        // ── V2: Zero-Trust Cihaz Doğrulama ──────────────────
        /** iOS DeviceCheck / Android Play Integrity token. */
        String deviceAttestationToken,

        // ── V2: On-Device Urgency Pre-Score ─────────────────
        /** Flutter tarafında cihaz-içi modelle hesaplanan ön aciliyet skoru. */
        Integer clientUrgencyScore,

        // ── V2: Çevrimdışı İhbar ────────────────────────────
        /** Çevrimdışı modda oluşturulmuşsa cihaz üzerindeki zaman damgası. */
        LocalDateTime offlineCreatedAt
) {
}
