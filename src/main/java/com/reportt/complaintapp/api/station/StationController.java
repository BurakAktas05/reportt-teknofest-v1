package com.reportt.complaintapp.api.station;

import com.reportt.complaintapp.dto.report.StationResponse;
import com.reportt.complaintapp.service.PoliceStationService;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import java.util.List;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/api/stations")
public class StationController {

    private final PoliceStationService policeStationService;

    public StationController(PoliceStationService policeStationService) {
        this.policeStationService = policeStationService;
    }

    @GetMapping
    public List<StationResponse> listStations() {
        return policeStationService.listStations();
    }

    @GetMapping("/nearest")
    public StationResponse nearestStation(
            @RequestParam @DecimalMin("-90.0") @DecimalMax("90.0") Double latitude,
            @RequestParam @DecimalMin("-180.0") @DecimalMax("180.0") Double longitude
    ) {
        return policeStationService.getNearestStationResponse(latitude, longitude);
    }
}
