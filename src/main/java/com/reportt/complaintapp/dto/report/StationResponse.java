package com.reportt.complaintapp.dto.report;

public record StationResponse(
        Long id,
        String stationName,
        String district,
        String contactPhone,
        Double latitude,
        Double longitude
) {
}
