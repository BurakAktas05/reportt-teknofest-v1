-- V12: FCM Push Notification - kullanıcı FCM token kaydı
ALTER TABLE complaint_app.app_user
    ADD COLUMN fcm_token TEXT;

COMMENT ON COLUMN complaint_app.app_user.fcm_token
    IS 'Firebase Cloud Messaging cihaz token degeri. Push bildirim gondermek icin kullanilir.';
