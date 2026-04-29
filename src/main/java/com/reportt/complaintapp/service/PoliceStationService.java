package com.reportt.complaintapp.service;

import com.reportt.complaintapp.domain.PoliceStation;
import com.reportt.complaintapp.dto.report.StationResponse;
import com.reportt.complaintapp.exception.ApiException;
import com.reportt.complaintapp.exception.ErrorCode;
import com.reportt.complaintapp.repository.PoliceStationRepository;
import java.util.List;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

@Service
public class PoliceStationService {

    private final PoliceStationRepository policeStationRepository;

    public PoliceStationService(PoliceStationRepository policeStationRepository) {
        this.policeStationRepository = policeStationRepository;
    }

    public PoliceStation findNearest(double latitude, double longitude) {
        return policeStationRepository.findNearestStation(latitude, longitude)
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
