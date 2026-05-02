package com.reportt.complaintapp.service;

import com.reportt.complaintapp.domain.UserAccount;
import com.reportt.complaintapp.domain.enums.ReportStatus;
import com.reportt.complaintapp.domain.enums.UserRole;
import com.reportt.complaintapp.dto.analytics.StatsResponse;
import com.reportt.complaintapp.dto.analytics.StatsResponse.*;
import com.reportt.complaintapp.config.TrustScoreProperties;
import com.reportt.complaintapp.repository.ComplaintReportRepository;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Vatandaş ve memur dashboard istatistik servisi (V3).
 */
@Service
public class StatsService {

    private final ComplaintReportRepository reportRepository;
    private final TrustScoreProperties trustScoreProperties;

    public StatsService(ComplaintReportRepository reportRepository, TrustScoreProperties trustScoreProperties) {
        this.reportRepository = reportRepository;
        this.trustScoreProperties = trustScoreProperties;
    }

    @Transactional(readOnly = true)
    public StatsResponse getStats(UserAccount user) {
        if (user.getRole() == UserRole.CITIZEN) {
            return buildCitizenStats(user);
        } else {
            return buildOfficerStats(user);
        }
    }

    private StatsResponse buildCitizenStats(UserAccount citizen) {
        long total = reportRepository.countByCitizen(citizen);
        long verified = reportRepository.countByCitizenAndStatus(citizen, ReportStatus.VERIFIED);
        long thisWeek = reportRepository.countByCitizenAndCreatedAtAfter(citizen, LocalDateTime.now().minusDays(7));
        double approvalRate = total > 0 ? (double) verified / total * 100 : 0.0;
        approvalRate = Math.round(approvalRate * 10) / 10.0;

        String trustLevel = determineTrustLevel(citizen);
        List<BadgeInfo> badges = calculateBadges(citizen, total, verified);
        List<DailyCount> weeklyTrend = getWeeklyTrend();

        return new StatsResponse(
                total,
                citizen.getReputationScore(),
                citizen.getVerifiedReportCount(),
                citizen.getRejectedReportCount(),
                approvalRate,
                thisWeek,
                trustLevel,
                badges,
                null, null, null, null,
                weeklyTrend
        );
    }

    private StatsResponse buildOfficerStats(UserAccount officer) {
        Long stationId = officer.getAssignedStation() != null ? officer.getAssignedStation().getId() : null;

        long total;
        long pending;
        long urgent;
        List<CategoryCount> topCategories;
        List<LocationCount> topLocations;

        if (officer.getRole() == UserRole.ADMIN) {
            total = reportRepository.count();
            pending = reportRepository.countByStatus(ReportStatus.SUBMITTED);
            urgent = reportRepository.countByUrgencyScoreGreaterThanEqual(8);
            topCategories = List.of();
            topLocations = getTopLocations(30, 5);
        } else if (stationId != null) {
            total = reportRepository.countByAssignedStationId(stationId);
            pending = reportRepository.countByAssignedStationIdAndStatus(stationId, ReportStatus.SUBMITTED);
            urgent = reportRepository.countByAssignedStationIdAndUrgencyScoreGreaterThanEqual(stationId, 8);
            topCategories = getCategoriesForStation(stationId);
            topLocations = getTopLocations(30, 5);
        } else {
            total = 0;
            pending = 0;
            urgent = 0;
            topCategories = List.of();
            topLocations = List.of();
        }

        List<DailyCount> weeklyTrend = getWeeklyTrend();

        return new StatsResponse(
                total,
                null,
                0, 0, 0.0, 0,
                null,
                null,
                pending,
                urgent,
                topCategories,
                topLocations,
                weeklyTrend
        );
    }

    private String determineTrustLevel(UserAccount citizen) {
        int score = citizen.getReputationScore();
        int verified = citizen.getVerifiedReportCount();

        if (score >= trustScoreProperties.bypassThreshold() && verified >= trustScoreProperties.minimumVerifiedReports()) {
            return "TRUSTED";
        } else if (score >= 30) {
            return "RELIABLE";
        } else if (score >= 10) {
            return "ACTIVE";
        } else {
            return "NEW";
        }
    }

    private List<BadgeInfo> calculateBadges(UserAccount citizen, long totalReports, long verifiedReports) {
        int score = citizen.getReputationScore();
        int verifiedCount = citizen.getVerifiedReportCount();
        boolean isTrusted = score >= trustScoreProperties.bypassThreshold()
                && verifiedCount >= trustScoreProperties.minimumVerifiedReports();

        List<BadgeInfo> badges = new ArrayList<>();

        badges.add(new BadgeInfo("new_citizen", "🥉", "Yeni Vatandaş",
                "İlk ihbarınızı gönderin!", totalReports >= 1));

        badges.add(new BadgeInfo("trusted_citizen", "🥈", "Güvenilir Vatandaş",
                "5+ onaylı ihbar gönderin.", verifiedCount >= 5));

        badges.add(new BadgeInfo("city_guardian", "🥇", "Şehir Koruyucu",
                "25+ onaylı ihbar + 100 puan.", verifiedCount >= 25 && score >= 100));

        badges.add(new BadgeInfo("digital_informer", "🛡️", "Dijital Muhbir",
                "AI bypass aktif — güvenilir statü.", isTrusted));

        badges.add(new BadgeInfo("field_force", "📴", "Saha Gücü",
                "Çevrimdışı ihbar gönderin.", totalReports >= 1)); // Offline flag check yapılabilir

        badges.add(new BadgeInfo("urgent_observer", "🔥", "Acil Durum Gözlemcisi",
                "Yüksek aciliyet ihbar gönderin.", totalReports >= 3));

        badges.add(new BadgeInfo("consistency", "📊", "Tutarlı İhbarcı",
                "%80+ onay oranı ve 10+ ihbar.", totalReports >= 10 && verifiedCount * 100.0 / totalReports >= 80));

        badges.add(new BadgeInfo("weekly_active", "⚡", "Haftalık Aktif",
                "Bu hafta en az 3 ihbar.", false)); // Frontend'den kontrol

        return badges;
    }

    private List<DailyCount> getWeeklyTrend() {
        LocalDateTime since = LocalDateTime.now().minusDays(7);
        List<Object[]> rows = reportRepository.countByDaySince(since);
        return rows.stream()
                .map(row -> {
                    Timestamp ts = (Timestamp) row[0];
                    long count = ((Number) row[1]).longValue();
                    return new DailyCount(ts.toLocalDateTime().toLocalDate().toString(), count);
                })
                .toList();
    }

    private List<CategoryCount> getCategoriesForStation(Long stationId) {
        return reportRepository.countByCategoryForStation(stationId).stream()
                .map(row -> new CategoryCount((String) row[0], ((Number) row[1]).longValue()))
                .toList();
    }

    private List<LocationCount> getTopLocations(int days, int limit) {
        return reportRepository.findTopLocations(LocalDateTime.now().minusDays(days), limit).stream()
                .map(row -> new LocationCount(
                        row[0] != null ? (String) row[0] : "Bilinmeyen",
                        ((Number) row[1]).longValue()
                ))
                .toList();
    }
}
