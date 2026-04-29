package com.reportt.complaintapp.domain;

import com.reportt.complaintapp.domain.enums.EvidenceType;
import com.reportt.complaintapp.domain.enums.MediaAnalysisStatus;
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
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "evidence_media")
public class EvidenceMedia extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "complaint_report_id", nullable = false)
    private ComplaintReport complaintReport;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private EvidenceType evidenceType;

    @Column(nullable = false, length = 255)
    private String originalFileName;

    @Column(nullable = false, length = 120)
    private String contentType;

    @Column(nullable = false, length = 255)
    private String storagePath;

    @Column(nullable = false, length = 30)
    private String storageProvider;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private MediaAnalysisStatus analysisStatus;

    @Column(length = 500)
    private String analysisSummary;

    @Column(columnDefinition = "TEXT")
    private String analysisRawJson;

    private Double outdoorConfidence;

    private Double selfieRisk;

    @Column(length = 20)
    private String detectedPlate;

    @Column(nullable = false)
    private boolean reviewRequired;

    @Column(nullable = false)
    private Long fileSize;
}
