package com.reportt.complaintapp.dto.analytics;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/**
 * Isı haritası sorgulama parametreleri.
 * Bounding box veya merkez+yarıçap ile sorgu yapılabilir.
 */
public record HeatmapRequest(
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double southLat,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double westLng,
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double northLat,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double eastLng,

        /** Grid çözünürlüğü — satır ve sütun sayısı. Varsayılan: 20 */
        @Min(5) @Max(100) Integer gridSize,

        /** Opsiyonel: Sadece son N gün içindeki ihbarlar (varsayılan: 90). */
        @Min(1) @Max(365) Integer days,

        /** Opsiyonel: Sadece belirli bir kategori filtresi. */
        String category
) {
    public int resolvedGridSize() {
        return gridSize != null ? gridSize : 20;
    }

    public int resolvedDays() {
        return days != null ? days : 90;
    }
}
