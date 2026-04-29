package com.reportt.complaintapp.dto.analytics;

/**
 * Tek bir ısı haritası hücresi.
 * Merkez koordinat, ihbar sayısı ve normalize edilmiş yoğunluk içerir.
 */
public record HeatmapCell(
        /** Hücrenin merkez enlemi. */
        double latitude,
        /** Hücrenin merkez boylamı. */
        double longitude,
        /** Hücredeki ihbar sayısı. */
        long count,
        /** Normalize edilmiş yoğunluk (0.0 – 1.0). */
        double intensity
) {
}
