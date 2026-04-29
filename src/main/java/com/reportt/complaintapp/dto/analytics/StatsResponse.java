package com.reportt.complaintapp.dto.analytics;

import java.util.List;
import java.util.Map;

/**
 * Vatandaş ve memur için istatistik cevap modeli.
 */
public record StatsResponse(
        // Ortak
        long totalReports,

        // Vatandaş
        Integer reputationScore,
        int verifiedCount,
        int rejectedCount,
        double approvalRate,
        long reportsThisWeek,
        String trustLevel,
        List<BadgeInfo> badges,

        // Memur
        Long pendingCount,
        Long urgentCount,
        List<CategoryCount> topCategories,
        List<LocationCount> topLocations,

        // Trend (son 7 gün)
        List<DailyCount> weeklyTrend
) {
    public record BadgeInfo(String id, String icon, String title, String description, boolean earned) {}
    public record CategoryCount(String category, long count) {}
    public record LocationCount(String location, long count) {}
    public record DailyCount(String date, long count) {}
}
