package com.reportt.complaintapp.service;

import com.reportt.complaintapp.dto.analytics.HeatmapCell;
import com.reportt.complaintapp.dto.analytics.HeatmapRequest;
import com.reportt.complaintapp.dto.analytics.HeatmapResponse;
import com.reportt.complaintapp.exception.ApiException;
import com.reportt.complaintapp.exception.ErrorCode;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import java.util.ArrayList;
import java.util.List;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Dinamik Suç Isı Haritası Servisi (Modül 3 — Predictive Policing).
 *
 * <h3>Mimari</h3>
 * <p>PostGIS'in mekansal fonksiyonlarını kullanarak verilen bounding box
 * içindeki ihbarları grid hücrelerine böler ve her hücredeki yoğunluğu hesaplar.
 * Sonuç Redis ile cache'lenerek yüksek performans sağlanır.</p>
 *
 * <h3>Algoritma</h3>
 * <ol>
 *   <li>Bounding box alanı gridSize×gridSize hücreye bölünür</li>
 *   <li>Her hücre için PostGIS ST_Contains ile ihbar sayısı hesaplanır</li>
 *   <li>Yoğunluk değeri max'a göre normalize edilir (0.0–1.0)</li>
 *   <li>Sonuç Redis'te 5 dakika cache'lenir</li>
 * </ol>
 */
@Service
public class HeatmapService {

    private final EntityManager entityManager;

    public HeatmapService(EntityManager entityManager) {
        this.entityManager = entityManager;
    }

    /**
     * Bounding box içindeki ihbar yoğunluk verisini grid formatında döndürür.
     */
    @Transactional(readOnly = true)
    @Cacheable(value = "heatmap", key = "#request.hashCode()")
    public HeatmapResponse generateHeatmap(HeatmapRequest request) {
        validateBoundingBox(request);

        long startTime = System.currentTimeMillis();
        int gridSize = request.resolvedGridSize();
        int days = request.resolvedDays();

        // PostGIS grid-based aggregation sorgusu
        String sql = buildHeatmapQuery(request.category());

        Query query = entityManager.createNativeQuery(sql);
        query.setParameter("south", request.southLat());
        query.setParameter("west", request.westLng());
        query.setParameter("north", request.northLat());
        query.setParameter("east", request.eastLng());
        query.setParameter("gridSize", gridSize);
        query.setParameter("days", days);

        @SuppressWarnings("unchecked")
        List<Object[]> rows = query.getResultList();

        // Grid hücrelerini oluştur
        long maxCount = 0;
        List<HeatmapCell> rawCells = new ArrayList<>();
        for (Object[] row : rows) {
            double lat = ((Number) row[0]).doubleValue();
            double lng = ((Number) row[1]).doubleValue();
            long count = ((Number) row[2]).longValue();
            maxCount = Math.max(maxCount, count);
            rawCells.add(new HeatmapCell(lat, lng, count, 0.0));
        }

        // Yoğunluk normalizasyonu
        long totalReports = 0;
        List<HeatmapCell> normalizedCells = new ArrayList<>();
        for (HeatmapCell cell : rawCells) {
            double intensity = maxCount > 0 ? (double) cell.count() / maxCount : 0.0;
            normalizedCells.add(new HeatmapCell(
                    cell.latitude(),
                    cell.longitude(),
                    cell.count(),
                    Math.round(intensity * 10000.0) / 10000.0
            ));
            totalReports += cell.count();
        }

        long queryTimeMs = System.currentTimeMillis() - startTime;

        return new HeatmapResponse(
                request.southLat(),
                request.westLng(),
                request.northLat(),
                request.eastLng(),
                gridSize,
                totalReports,
                normalizedCells,
                false,
                queryTimeMs
        );
    }

    /**
     * PostGIS ile grid tabanlı ihbar yoğunluk sorgusu oluşturur.
     *
     * <p>Sorgu stratejisi:</p>
     * <ul>
     *   <li>{@code generate_series} ile grid satır/sütunları üretilir</li>
     *   <li>Her hücre için {@code ST_MakeEnvelope} ile bir bounding box oluşturulur</li>
     *   <li>{@code ST_Contains} ile ihbar noktalarının hücreye düşüp düşmediği kontrol edilir</li>
     *   <li>Sadece count > 0 olan hücreler döndürülür (sparse grid)</li>
     * </ul>
     */
    private String buildHeatmapQuery(String category) {
        String categoryFilter = (category != null && !category.isBlank())
                ? " AND cr.category = '" + category.replace("'", "") + "'"
                : "";

        return """
                WITH grid AS (
                    SELECT
                        :south + (row_idx * ((:north - :south) / :gridSize)) + (((:north - :south) / :gridSize) / 2.0) AS cell_lat,
                        :west  + (col_idx * ((:east  - :west)  / :gridSize)) + (((:east  - :west)  / :gridSize) / 2.0) AS cell_lng,
                        ST_MakeEnvelope(
                            :west  + (col_idx * ((:east  - :west)  / :gridSize)),
                            :south + (row_idx * ((:north - :south) / :gridSize)),
                            :west  + ((col_idx + 1) * ((:east  - :west)  / :gridSize)),
                            :south + ((row_idx + 1) * ((:north - :south) / :gridSize)),
                            4326
                        ) AS cell_geom
                    FROM generate_series(0, :gridSize - 1) AS row_idx,
                         generate_series(0, :gridSize - 1) AS col_idx
                )
                SELECT
                    g.cell_lat,
                    g.cell_lng,
                    COUNT(cr.id) AS report_count
                FROM grid g
                LEFT JOIN complaint_app.complaint_report cr
                    ON ST_Contains(g.cell_geom, cr.reported_point)
                    AND cr.created_at >= NOW() - CAST(:days || ' days' AS INTERVAL)
                    AND cr.status NOT IN ('REJECTED', 'REJECTED_BY_SYSTEM')
                """ + categoryFilter + """
                GROUP BY g.cell_lat, g.cell_lng
                HAVING COUNT(cr.id) > 0
                ORDER BY report_count DESC
                """;
    }

    private void validateBoundingBox(HeatmapRequest request) {
        if (request.southLat() >= request.northLat() || request.westLng() >= request.eastLng()) {
            throw new ApiException(ErrorCode.INVALID_BOUNDING_BOX);
        }
    }
}
