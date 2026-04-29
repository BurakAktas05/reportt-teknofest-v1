-- Police station tablosundaki eksik kolonlari tamamla
ALTER TABLE police_station ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE police_station ADD COLUMN IF NOT EXISTS registration_code VARCHAR(36) UNIQUE;

-- Kayit kodu eksik olan varsa doldur
UPDATE police_station SET registration_code = gen_random_uuid() WHERE registration_code IS NULL;
ALTER TABLE police_station ALTER COLUMN registration_code SET NOT NULL;
