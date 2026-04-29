CREATE SCHEMA IF NOT EXISTS complaint_app;
CREATE EXTENSION IF NOT EXISTS postgis SCHEMA public;
SET search_path TO complaint_app, public;

CREATE TABLE app_user (
    id BIGSERIAL PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    phone_number VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(120) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL,
    reputation_score INTEGER NOT NULL DEFAULT 0,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE police_station (
    id BIGSERIAL PRIMARY KEY,
    station_name VARCHAR(150) NOT NULL,
    district VARCHAR(120) NOT NULL,
    station_point geometry(Point, 4326) NOT NULL,
    contact_phone VARCHAR(20),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_police_station_point ON police_station USING GIST (station_point);

ALTER TABLE app_user
    ADD COLUMN station_id BIGINT REFERENCES police_station(id);

CREATE TABLE capture_session (
    id BIGSERIAL PRIMARY KEY,
    citizen_id BIGINT NOT NULL REFERENCES app_user(id),
    session_token VARCHAR(120) NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    consumed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE complaint_report (
    id BIGSERIAL PRIMARY KEY,
    citizen_id BIGINT NOT NULL REFERENCES app_user(id),
    assigned_station_id BIGINT NOT NULL REFERENCES police_station(id),
    title VARCHAR(150) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL,
    status VARCHAR(30) NOT NULL,
    incident_at TIMESTAMP NOT NULL,
    reported_point geometry(Point, 4326) NOT NULL,
    address_text VARCHAR(255),
    live_capture_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_complaint_report_point ON complaint_report USING GIST (reported_point);
CREATE INDEX idx_complaint_report_status ON complaint_report (status);
CREATE INDEX idx_complaint_report_station ON complaint_report (assigned_station_id);

CREATE TABLE evidence_media (
    id BIGSERIAL PRIMARY KEY,
    complaint_report_id BIGINT NOT NULL REFERENCES complaint_report(id) ON DELETE CASCADE,
    evidence_type VARCHAR(20) NOT NULL,
    original_file_name VARCHAR(255) NOT NULL,
    content_type VARCHAR(120) NOT NULL,
    storage_path VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE report_feedback (
    id BIGSERIAL PRIMARY KEY,
    complaint_report_id BIGINT NOT NULL REFERENCES complaint_report(id) ON DELETE CASCADE,
    author_id BIGINT NOT NULL REFERENCES app_user(id),
    message VARCHAR(500) NOT NULL,
    internal_note BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO police_station (station_name, district, station_point, contact_phone)
VALUES
    ('Kadikoy Merkez Karakolu', 'Kadikoy', ST_SetSRID(ST_MakePoint(29.0326, 40.9917), 4326), '+90-216-000-0001'),
    ('Besiktas Merkez Karakolu', 'Besiktas', ST_SetSRID(ST_MakePoint(29.0094, 41.0422), 4326), '+90-212-000-0002');
