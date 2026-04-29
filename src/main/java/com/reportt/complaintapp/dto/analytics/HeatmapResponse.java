package com.reportt.complaintapp.dto.analytics;

import java.util.List;

/**
 * Isı haritası cevap modeli.
 * Grid tabanlı yoğunluk verisi döndürür.
 */
public record HeatmapResponse(
        /** Bounding box sınırları. */
        double southLat,
        double westLng,
        double northLat,
        double eastLng,

        /** Grid çözünürlüğü. */
        int gridSize,

        /** Toplam ihbar sayısı. */
        long totalReports,

        /** Grid hücreleri — yoğunluk verileri. */
        List<HeatmapCell> cells,

        /** Cache'den mi geldi? */
        boolean cached,

        /** Sorgu süresi (ms). */
        long queryTimeMs
) {
}
