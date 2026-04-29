UPDATE police_station SET active = false;

INSERT INTO police_station (station_name, district, station_point, contact_phone)
VALUES 
('3 Nisan Polis Merkezi Amirliği', 'Karabük Merkez', ST_SetSRID(ST_MakePoint(32.625, 41.205), 4326), '03704121212'),
('100. Yıl Polis Merkezi Amirliği', 'Karabük Merkez', ST_SetSRID(ST_MakePoint(32.655, 41.215), 4326), '03704333333'),
('Safranbolu Şehit Murat Akpınar Polis Merkezi', 'Safranbolu', ST_SetSRID(ST_MakePoint(32.685, 41.250), 4326), '03707121212'),
('Yenice İlçe Emniyet Amirliği', 'Yenice', ST_SetSRID(ST_MakePoint(32.325, 41.198), 4326), '03707661212');
