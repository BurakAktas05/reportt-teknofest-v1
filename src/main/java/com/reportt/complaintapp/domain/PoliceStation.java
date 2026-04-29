package com.reportt.complaintapp.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.Point;

@Getter
@Setter
@Entity
@Table(name = "police_station")
public class PoliceStation extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String stationName;

    @Column(nullable = false, length = 120)
    private String district;

    @Column(nullable = false, columnDefinition = "geometry(Point,4326)")
    private Point stationPoint;

    @Column(length = 20)
    private String contactPhone;

    @Column(nullable = false)
    private boolean active = true;

    @Column(nullable = false, unique = true, length = 36)
    private String registrationCode;

    // ── V2: Sorumluluk Bölgesi Poligonu (Modül 4) ──────────

    /** Karakolun sorumluluk bölgesi sınırlarını tanımlayan PostGIS poligonu. */
    @Column(columnDefinition = "geometry(Polygon,4326)")
    private Geometry stationPolygon;
}
