package com.reportt.complaintapp.domain;

import com.reportt.complaintapp.domain.enums.ReportCategory;
import com.reportt.complaintapp.domain.enums.ReportStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;
import org.locationtech.jts.geom.Point;

@Getter
@Setter
@Entity
@Table(name = "complaint_report")
public class ComplaintReport extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "citizen_id", nullable = false)
    private UserAccount citizen;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "assigned_station_id", nullable = false)
    private PoliceStation assignedStation;

    @Column(nullable = false, length = 150)
    private String title;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 50)
    private ReportCategory category;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private ReportStatus status;

    @Column(nullable = false)
    private LocalDateTime incidentAt;

    @Column(nullable = false, columnDefinition = "geometry(Point,4326)")
    private Point reportedPoint;

    @Column(length = 255)
    private String addressText;

    @Column(nullable = false)
    private boolean liveCaptureConfirmed;

    // ── V2: Smart Triage (Modül 1) ──────────────────────────

    /** Hibrit AI tarafından hesaplanan aciliyet skoru (1-10). */
    @Column(nullable = false)
    private int urgencyScore = 0;

    /** iOS DeviceCheck / Android Play Integrity token. */
    @Column(columnDefinition = "TEXT")
    private String deviceAttestationToken;

    /** Cihaz doğrulama sonucu. */
    @Column(nullable = false)
    private boolean deviceVerified = false;

    /** Yapay zeka triyaj özet metni. */
    @Column(columnDefinition = "TEXT")
    private String aiTriageSummary;

    // ── V2: Trust Bypass (Modül 5) ──────────────────────────

    /** Güvenilir vatandaş kuralı gereği AI analizi atlandı mı? */
    @Column(nullable = false)
    private boolean bypassAnalysis = false;

    // ── V2: Offline (Modül 6) ───────────────────────────────

    /** Çevrimdışı modda oluşturulan ihbarın cihaz üzerindeki zaman damgası. */
    private LocalDateTime offlineCreatedAt;
}
