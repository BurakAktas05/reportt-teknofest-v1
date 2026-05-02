SET search_path TO complaint_app, public;

-- Mevcut uzun UUID'leri (36 karakter) daha kısa 6 karakterli rastgele alfasayısal kodlarla değiştir
UPDATE police_station 
SET registration_code = upper(substring(md5(random()::text) from 1 for 6));

-- Eğer veritabanı postgres gen_random_uuid kullanıyorsa default değerini de güncelleyelim
ALTER TABLE police_station ALTER COLUMN registration_code TYPE VARCHAR(36);
ALTER TABLE police_station ALTER COLUMN registration_code SET DEFAULT upper(substring(md5(random()::text) from 1 for 6));
