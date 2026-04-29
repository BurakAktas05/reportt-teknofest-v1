package com.reportt.complaintapp.repository;

import com.reportt.complaintapp.domain.ComplaintReport;
import com.reportt.complaintapp.domain.UserAccount;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ComplaintReportRepository extends JpaRepository<ComplaintReport, Long> {

    List<ComplaintReport> findByCitizenOrderByCreatedAtDesc(UserAccount citizen);

    List<ComplaintReport> findByAssignedStationIdOrderByCreatedAtDesc(Long stationId);

    // ── V3: İstatistik sorguları ─────────────────────────────

    long countByCitizen(UserAccount citizen);

    long countByCitizenAndStatus(UserAccount citizen, com.reportt.complaintapp.domain.enums.ReportStatus status);

    long countByAssignedStationId(Long stationId);

    long countByAssignedStationIdAndStatus(Long stationId, com.reportt.complaintapp.domain.enums.ReportStatus status);

    // V3: Admin — tüm sistemdeki bekleyen ihbar sayısı
    long countByStatus(com.reportt.complaintapp.domain.enums.ReportStatus status);

    @Query("SELECT COUNT(r) FROM ComplaintReport r WHERE r.urgencyScore >= :threshold")
    long countByUrgencyScoreGreaterThanEqual(@Param("threshold") int threshold);

    @Query("SELECT COUNT(r) FROM ComplaintReport r WHERE r.assignedStation.id = :stationId AND r.urgencyScore >= :threshold")
    long countByAssignedStationIdAndUrgencyScoreGreaterThanEqual(@Param("stationId") Long stationId, @Param("threshold") int threshold);

    @Query("SELECT COUNT(r) FROM ComplaintReport r WHERE r.citizen = :citizen AND r.createdAt >= :since")
    long countByCitizenAndCreatedAtAfter(@Param("citizen") UserAccount citizen, @Param("since") LocalDateTime since);

    // V3: Trend verisi
    @Query(value = """
            SELECT DATE_TRUNC('day', cr.created_at) AS day, COUNT(*)
            FROM complaint_app.complaint_report cr
            WHERE cr.created_at >= :since
            GROUP BY day
            ORDER BY day
            """, nativeQuery = true)
    List<Object[]> countByDaySince(@Param("since") LocalDateTime since);

    @Query(value = """
            SELECT DATE_TRUNC('day', cr.created_at) AS day, cr.category, COUNT(*)
            FROM complaint_app.complaint_report cr
            WHERE cr.created_at >= :since
            GROUP BY day, cr.category
            ORDER BY day
            """, nativeQuery = true)
    List<Object[]> countByDayAndCategorySince(@Param("since") LocalDateTime since);

    @Query(value = """
            SELECT cr.category, COUNT(*) AS cnt
            FROM complaint_app.complaint_report cr
            WHERE cr.assigned_station_id = :stationId
            GROUP BY cr.category
            ORDER BY cnt DESC
            """, nativeQuery = true)
    List<Object[]> countByCategoryForStation(@Param("stationId") Long stationId);

    // V3: Top bölgeler
    @Query(value = """
            SELECT cr.address_text, COUNT(*) AS cnt
            FROM complaint_app.complaint_report cr
            WHERE cr.created_at >= :since
            GROUP BY cr.address_text
            ORDER BY cnt DESC
            LIMIT :limit
            """, nativeQuery = true)
    List<Object[]> findTopLocations(@Param("since") LocalDateTime since, @Param("limit") int limit);
}
