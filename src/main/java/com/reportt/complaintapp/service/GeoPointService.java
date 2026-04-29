package com.reportt.complaintapp.service;

import com.reportt.complaintapp.exception.ApiException;
import com.reportt.complaintapp.exception.ErrorCode;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Service;

@Service
public class GeoPointService {

    private final GeometryFactory geometryFactory;

    public GeoPointService(GeometryFactory geometryFactory) {
        this.geometryFactory = geometryFactory;
    }

    public Point createPoint(Double latitude, Double longitude) {
        if (latitude == null || longitude == null) {
            throw new ApiException(ErrorCode.LOCATION_REQUIRED);
        }

        Point point = geometryFactory.createPoint(new Coordinate(longitude, latitude));
        point.setSRID(4326);
        return point;
    }
}
