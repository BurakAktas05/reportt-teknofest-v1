-- V9: Kriptografik kanıt bütünlüğü (SHA-256) ve Akıllı Triyaj alanları
-- Modül 1 (Smart Triage) + Modül 2 (Dijital Mühür)

-- ============================================================
-- MODÜL 2: EvidenceMedia tablosuna kriptografik hash sütunları
-- ============================================================
ALTER TABLE complaint_app.evidence_media
    ADD COLUMN sha256_hash VARCHAR(64);

ALTER TABLE complaint_app.evidence_media
    ADD COLUMN hash_verified BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN complaint_app.evidence_media.sha256_hash
    IS 'İstemci tarafında çekilen fotoğrafın SHA-256 hash değeri. Bütünlük kontrolü için kullanılır.';

COMMENT ON COLUMN complaint_app.evidence_media.hash_verified
    IS 'Sunucu tarafında hesaplanan hash, istemci hash ile eşleşti mi?';

-- ============================================================
-- MODÜL 1: ComplaintReport tablosuna akıllı triyaj ve cihaz doğrulama
-- ============================================================
ALTER TABLE complaint_app.complaint_report
    ADD COLUMN urgency_score INTEGER NOT NULL DEFAULT 0;

ALTER TABLE complaint_app.complaint_report
    ADD COLUMN device_attestation_token TEXT;

ALTER TABLE complaint_app.complaint_report
    ADD COLUMN device_verified BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE complaint_app.complaint_report
    ADD COLUMN ai_triage_summary TEXT;

ALTER TABLE complaint_app.complaint_report
    ADD COLUMN bypass_analysis BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE complaint_app.complaint_report
    ADD COLUMN offline_created_at TIMESTAMP;

COMMENT ON COLUMN complaint_app.complaint_report.urgency_score
    IS 'Hibrit AI tarafından hesaplanan aciliyet skoru (1-10).';

COMMENT ON COLUMN complaint_app.complaint_report.device_attestation_token
    IS 'iOS DeviceCheck / Android Play Integrity token.';

COMMENT ON COLUMN complaint_app.complaint_report.device_verified
    IS 'Cihaz doğrulama sonucu.';

COMMENT ON COLUMN complaint_app.complaint_report.ai_triage_summary
    IS 'Yapay zeka triyaj özet metni.';

COMMENT ON COLUMN complaint_app.complaint_report.bypass_analysis
    IS 'Güvenilir vatandaş kuralı gereği AI analizi atlandı mı?';

COMMENT ON COLUMN complaint_app.complaint_report.offline_created_at
    IS 'Çevrimdışı modda oluşturulan ihbarın cihaz üzerindeki zaman damgası.';
