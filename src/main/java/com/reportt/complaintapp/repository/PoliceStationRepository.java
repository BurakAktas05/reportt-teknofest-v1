package com.reportt.complaintapp.repository;

import com.reportt.complaintapp.domain.PoliceStation;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PoliceStationRepository extends JpaRepository<PoliceStation, Long> {

    Optional<PoliceStation> findByRegistrationCode(String registrationCode);

    @Query(value = """
            SELECT *
            FROM complaint_app.police_station ps
            WHERE ps.active = true
            ORDER BY ST_DistanceSphere(
                ps.station_point,
                ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)
            )
            LIMIT 1
            """, nativeQuery = true)
    Optional<PoliceStation> findNearestStation(@Param("latitude") double latitude, @Param("longitude") double longitude);

    List<PoliceStation> findByActiveTrueOrderByDistrictAscStationNameAsc();
}
