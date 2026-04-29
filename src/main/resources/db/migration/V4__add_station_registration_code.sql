ALTER TABLE police_station ADD COLUMN registration_code VARCHAR(36) DEFAULT gen_random_uuid() UNIQUE;
UPDATE police_station SET registration_code = gen_random_uuid() WHERE registration_code IS NULL;
ALTER TABLE police_station ALTER COLUMN registration_code SET NOT NULL;
