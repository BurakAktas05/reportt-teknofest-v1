package com.reportt.complaintapp.api.analytics;

import com.reportt.complaintapp.dto.analytics.HeatmapRequest;
import com.reportt.complaintapp.dto.analytics.HeatmapResponse;
import com.reportt.complaintapp.dto.analytics.StatsResponse;
import com.reportt.complaintapp.service.CurrentUserService;
import com.reportt.complaintapp.service.HeatmapService;
import com.reportt.complaintapp.service.StatsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Analitik, İstatistik ve Predictive Policing endpoint'leri.
 */
@Tag(name = "Analytics", description = "İstatistik dashboard ve ısı haritası endpoint'leri")
@RestController
@RequestMapping("/api/analytics")
public class AnalyticsController {

    private final HeatmapService heatmapService;
    private final StatsService statsService;
    private final CurrentUserService currentUserService;

    public AnalyticsController(HeatmapService heatmapService, StatsService statsService, CurrentUserService currentUserService) {
        this.heatmapService = heatmapService;
        this.statsService = statsService;
        this.currentUserService = currentUserService;
    }

    @Operation(summary = "Suç yoğunluk ısı haritası", description = "Bounding box içindeki ihbar yoğunluğunu grid formatında döndürür.")
    @GetMapping("/heatmap")
    @PreAuthorize("hasAnyRole('OFFICER', 'ADMIN')")
    public HeatmapResponse heatmap(@Valid HeatmapRequest request) {
        return heatmapService.generateHeatmap(request);
    }

    @Operation(summary = "Dashboard istatistikleri", description = "Vatandaş veya memur için rol bazlı istatistik ve rozet verisi döndürür.")
    @GetMapping("/stats")
    public StatsResponse stats() {
        return statsService.getStats(currentUserService.getCurrentUser());
    }
}
