-- V10: Karakol sorumluluk bölgesi poligonları (PostGIS Polygon)
-- Modül 4: Coğrafi Tam Otomatik Karakol Ataması

-- ============================================================
-- police_station tablosuna bölge sınır poligonu ekleme
-- ============================================================
ALTER TABLE complaint_app.police_station
    ADD COLUMN station_polygon geometry(Polygon, 4326);

-- Poligon tabanlı sorgular için GIST indeksi
CREATE INDEX idx_station_polygon
    ON complaint_app.police_station USING GIST (station_polygon);

COMMENT ON COLUMN complaint_app.police_station.station_polygon
    IS 'Karakolun sorumluluk bölgesi sınırlarını tanımlayan PostGIS poligonu (SRID 4326).';

-- ============================================================
-- Mevcut karakol noktalarından ~2 km yarıçaplı varsayılan poligon üretimi
-- Bu sayede mevcut veriler de polygon sorgusuyla kullanılabilir
-- ============================================================
UPDATE complaint_app.police_station
SET station_polygon = ST_Buffer(station_point::geography, 2000)::geometry
WHERE station_polygon IS NULL
  AND station_point IS NOT NULL;
