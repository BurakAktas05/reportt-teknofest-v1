-- V11: Güvenilir vatandaş eşik değeri ve ihbar sayacı
-- Modül 5: Vatandaş Güven Puanı Sistemi (Oyunlaştırma)

-- ============================================================
-- app_user tablosuna doğrulanmış ihbar sayacı
-- ============================================================
ALTER TABLE complaint_app.app_user
    ADD COLUMN verified_report_count INTEGER NOT NULL DEFAULT 0;

ALTER TABLE complaint_app.app_user
    ADD COLUMN rejected_report_count INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN complaint_app.app_user.verified_report_count
    IS 'Doğrulanmış (VERIFIED) ihbar sayısı. Güven puanı hesaplamasında kullanılır.';

COMMENT ON COLUMN complaint_app.app_user.rejected_report_count
    IS 'Reddedilmiş ihbar sayısı. Olumsuz eğilim tespitinde kullanılır.';

-- ============================================================
-- Heatmap performansı için coğrafi indeksler
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_report_point
    ON complaint_app.complaint_report USING GIST (reported_point);

CREATE INDEX IF NOT EXISTS idx_report_status
    ON complaint_app.complaint_report (status);

CREATE INDEX IF NOT EXISTS idx_report_created_at
    ON complaint_app.complaint_report (created_at);
