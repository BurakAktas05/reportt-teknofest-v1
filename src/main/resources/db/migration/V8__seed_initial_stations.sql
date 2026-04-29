-- Eger hic karakol yoksa test icin birkac tane ekle
INSERT INTO complaint_app.police_station (station_name, district, station_point, contact_phone, registration_code)
SELECT 'Kadikoy Merkez Karakolu', 'Kadikoy', ST_SetSRID(ST_MakePoint(29.0326, 40.9917), 4326), '+90-216-000-0001', '550e8400-e29b-41d4-a716-446655440000'
WHERE NOT EXISTS (SELECT 1 FROM complaint_app.police_station WHERE station_name = 'Kadikoy Merkez Karakolu');

INSERT INTO complaint_app.police_station (station_name, district, station_point, contact_phone, registration_code)
SELECT 'Besiktas Merkez Karakolu', 'Besiktas', ST_SetSRID(ST_MakePoint(29.0094, 41.0422), 4326), '+90-212-000-0002', '550e8400-e29b-41d4-a716-446655440001'
WHERE NOT EXISTS (SELECT 1 FROM complaint_app.police_station WHERE station_name = 'Besiktas Merkez Karakolu');
