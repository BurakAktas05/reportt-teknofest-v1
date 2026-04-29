package com.reportt.complaintapp.service;

import com.reportt.complaintapp.config.TrustScoreProperties;
import com.reportt.complaintapp.domain.UserAccount;
import com.reportt.complaintapp.domain.enums.ReportStatus;
import com.reportt.complaintapp.domain.enums.UserRole;
import com.reportt.complaintapp.dto.analytics.StatsResponse;
import com.reportt.complaintapp.repository.ComplaintReportRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;

/**
 * StatsService birim testleri.
 * Vatandaş ve memur istatistiklerinin doğru hesaplandığını doğrular.
 */
@ExtendWith(MockitoExtension.class)
class StatsServiceTest {

    @Mock
    private ComplaintReportRepository reportRepository;

    // Record'lar mock edilemez, gerçek instance kullanıyoruz
    private TrustScoreProperties trustScoreProperties;
    private StatsService statsService;

    private UserAccount citizen;

    @BeforeEach
    void setUp() {
        trustScoreProperties = new TrustScoreProperties(50, 5);
        statsService = new StatsService(reportRepository, trustScoreProperties);

        citizen = new UserAccount();
        citizen.setId(1L);
        citizen.setRole(UserRole.CITIZEN);
        citizen.setReputationScore(55);
        citizen.setVerifiedReportCount(6);
        citizen.setRejectedReportCount(1);
    }

    @Nested
    @DisplayName("Vatandaş İstatistikleri")
    class CitizenStatsTests {

        @Test
        @DisplayName("Toplam rapor sayısı doğru hesaplanmalı")
        void shouldReturnCorrectTotalReports() {
            stubCitizenCounts(10L, 6L, 1L, 0L, 3L);
            when(reportRepository.countByDaySince(any())).thenReturn(List.of());

            StatsResponse stats = statsService.getStats(citizen);

            assertEquals(10, stats.totalReports());
            assertEquals(6, stats.verifiedCount());
            assertEquals(1, stats.rejectedCount());
            assertEquals(3, stats.reportsThisWeek());
        }

        @Test
        @DisplayName("Onay oranı %60.0 olmalı (6/10)")
        void shouldCalculateApprovalRate() {
            stubCitizenCounts(10L, 6L, 1L, 0L, 0L);
            when(reportRepository.countByDaySince(any())).thenReturn(List.of());

            StatsResponse stats = statsService.getStats(citizen);

            assertEquals(60.0, stats.approvalRate());
        }

        @Test
        @DisplayName("Güven seviyesi TRUSTED olmalı (skor:55, verified:6)")
        void shouldReturnTrustedLevel() {
            stubCitizenCounts(10L, 6L, 0L, 0L, 0L);
            when(reportRepository.countByDaySince(any())).thenReturn(List.of());

            StatsResponse stats = statsService.getStats(citizen);

            assertEquals("TRUSTED", stats.trustLevel());
        }

        @Test
        @DisplayName("Rozet listesi boş olmamalı, yeni_vatandaş kazanılmış olmalı")
        void shouldReturnBadges() {
            stubCitizenCounts(10L, 6L, 0L, 0L, 0L);
            when(reportRepository.countByDaySince(any())).thenReturn(List.of());

            StatsResponse stats = statsService.getStats(citizen);

            assertNotNull(stats.badges());
            assertFalse(stats.badges().isEmpty());

            // "Yeni Vatandaş" rozeti kazanılmış olmalı (total >= 1)
            var newCitizenBadge = stats.badges().stream()
                    .filter(b -> b.id().equals("new_citizen"))
                    .findFirst()
                    .orElseThrow();
            assertTrue(newCitizenBadge.earned());

            // "Güvenilir Vatandaş" rozeti kazanılmış olmalı (verified >= 5)
            var trustedBadge = stats.badges().stream()
                    .filter(b -> b.id().equals("trusted_citizen"))
                    .findFirst()
                    .orElseThrow();
            assertTrue(trustedBadge.earned());
        }
    }

    @Nested
    @DisplayName("Sıfır Rapor Durumu")
    class ZeroReportTests {

        @Test
        @DisplayName("Hiç rapor yokken onay oranı 0 olmalı")
        void shouldReturnZeroApprovalForNoReports() {
            citizen.setVerifiedReportCount(0);
            citizen.setRejectedReportCount(0);
            citizen.setReputationScore(0);

            stubCitizenCounts(0L, 0L, 0L, 0L, 0L);
            when(reportRepository.countByDaySince(any())).thenReturn(List.of());

            StatsResponse stats = statsService.getStats(citizen);

            assertEquals(0, stats.totalReports());
            assertEquals(0.0, stats.approvalRate());
            assertEquals("NEW", stats.trustLevel());
        }
    }

    private void stubCitizenCounts(long total, long verified, long rejected, long rejectedBySystem, long thisWeek) {
        when(reportRepository.countByCitizen(citizen)).thenReturn(total);
        when(reportRepository.countByCitizenAndStatus(citizen, ReportStatus.VERIFIED)).thenReturn(verified);
        when(reportRepository.countByCitizenAndStatus(citizen, ReportStatus.REJECTED)).thenReturn(rejected);
        when(reportRepository.countByCitizenAndStatus(citizen, ReportStatus.REJECTED_BY_SYSTEM)).thenReturn(rejectedBySystem);
        when(reportRepository.countByCitizenAndCreatedAtAfter(eq(citizen), any())).thenReturn(thisWeek);
    }
}
