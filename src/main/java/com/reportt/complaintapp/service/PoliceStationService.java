package com.reportt.complaintapp.service;

import com.reportt.complaintapp.domain.PoliceStation;
import com.reportt.complaintapp.dto.report.StationResponse;
import com.reportt.complaintapp.exception.ApiException;
import com.reportt.complaintapp.exception.ErrorCode;
import com.reportt.complaintapp.repository.PoliceStationRepository;
import java.util.List;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

/**
 * Karakol atama servisi.
 *
 * <h3>V2: Polygon-First Atama Stratejisi (Modül 4)</h3>
 * <p>İhbar noktası bir karakolun sorumluluk poligonu ({@code station_polygon}) içinde
 * mi kontrol eder. PostGIS {@code ST_Contains} + GIST indeksi ile milisaniyeler içinde
 * sonuç döner.</p>
 *
 * <p>Eğer hiçbir polygon eşleşmezse, geriye dönük uyumluluk için
 * {@code ST_DistanceSphere} ile en yakın karakol atanır.</p>
 */
@Service
public class PoliceStationService {

    private final PoliceStationRepository policeStationRepository;

    public PoliceStationService(PoliceStationRepository policeStationRepository) {
        this.policeStationRepository = policeStationRepository;
    }

    /**
     * İhbar noktasına göre karakol ataması yapar.
     *
     * <p>Öncelik sırası:</p>
     * <ol>
     *   <li>Polygon tabanlı ({@code ST_Contains}) — tam coğrafi eşleşme</li>
     *   <li>Mesafe tabanlı ({@code ST_DistanceSphere}) — en yakın karakol (fallback)</li>
     * </ol>
     */
    public PoliceStation findNearest(double latitude, double longitude) {
        // V2: Önce polygon tabanlı atama dene
        return policeStationRepository.findByPolygonContaining(latitude, longitude)
                .or(() -> policeStationRepository.findNearestStation(latitude, longitude))
                .orElseThrow(() -> new ApiException(ErrorCode.STATION_NOT_FOUND));
    }

    @Cacheable(value = "stations")
    public List<StationResponse> listStations() {
        return policeStationRepository.findByActiveTrueOrderByDistrictAscStationNameAsc().stream()
                .map(this::toStationResponse)
                .toList();
    }

    public StationResponse getNearestStationResponse(double latitude, double longitude) {
        return toStationResponse(findNearest(latitude, longitude));
    }

    private StationResponse toStationResponse(PoliceStation station) {
        return new StationResponse(
                station.getId(),
                station.getStationName(),
                station.getDistrict(),
                station.getContactPhone(),
                station.getStationPoint().getY(),
                station.getStationPoint().getX()
        );
    }
}
