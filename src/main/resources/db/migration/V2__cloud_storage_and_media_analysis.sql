SET search_path TO complaint_app, public;

ALTER TABLE evidence_media
    ADD COLUMN storage_provider VARCHAR(30) NOT NULL DEFAULT 'S3',
    ADD COLUMN analysis_status VARCHAR(30) NOT NULL DEFAULT 'REVIEW_REQUIRED',
    ADD COLUMN analysis_summary VARCHAR(500),
    ADD COLUMN analysis_raw_json TEXT,
    ADD COLUMN outdoor_confidence DOUBLE PRECISION,
    ADD COLUMN selfie_risk DOUBLE PRECISION,
    ADD COLUMN detected_plate VARCHAR(20),
    ADD COLUMN review_required BOOLEAN NOT NULL DEFAULT TRUE;
