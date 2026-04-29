package com.reportt.complaintapp.exception;

import org.springframework.http.HttpStatus;

public enum ErrorCode {
    AUTH_REQUIRED(HttpStatus.UNAUTHORIZED, ApiErrorCategory.AUTHENTICATION, "Bu islem icin giris yapilmasi gerekiyor.", false),
    AUTH_INVALID(HttpStatus.UNAUTHORIZED, ApiErrorCategory.AUTHENTICATION, "Kimlik dogrulama bilgileri gecersiz.", false),
    ACCESS_DENIED(HttpStatus.FORBIDDEN, ApiErrorCategory.AUTHORIZATION, "Bu islem icin gerekli yetkiye sahip degilsiniz.", false),
    INVALID_ROLE(HttpStatus.BAD_REQUEST, ApiErrorCategory.BUSINESS, "Gecersiz rol secimi gonderildi.", false),
    STATION_NOT_FOUND(HttpStatus.NOT_FOUND, ApiErrorCategory.BUSINESS, "Uygun karakol bulunamadi.", false),
    PHONE_EXISTS(HttpStatus.CONFLICT, ApiErrorCategory.BUSINESS, "Bu telefon numarasi zaten kayitli.", false),
    EMAIL_EXISTS(HttpStatus.CONFLICT, ApiErrorCategory.BUSINESS, "Bu e-posta adresi zaten kayitli.", false),
    CAPTURE_SESSION_INVALID(HttpStatus.BAD_REQUEST, ApiErrorCategory.BUSINESS, "Canli cekim oturumu gecersiz.", false),
    CAPTURE_SESSION_FORBIDDEN(HttpStatus.FORBIDDEN, ApiErrorCategory.AUTHORIZATION, "Canli cekim oturumu bu kullaniciya ait degil.", false),
    CAPTURE_SESSION_USED(HttpStatus.BAD_REQUEST, ApiErrorCategory.BUSINESS, "Canli cekim oturumu daha once kullanilmis.", false),
    CAPTURE_SESSION_EXPIRED(HttpStatus.BAD_REQUEST, ApiErrorCategory.BUSINESS, "Canli cekim oturumunun suresi dolmus.", false),
    ONLY_CITIZEN_CAN_REPORT(HttpStatus.FORBIDDEN, ApiErrorCategory.AUTHORIZATION, "Sadece vatandas kullanicilar sikayet olusturabilir.", false),
    EVIDENCE_REQUIRED(HttpStatus.BAD_REQUEST, ApiErrorCategory.VALIDATION, "En az bir foto veya video eklenmelidir.", false),
    OFFICER_ONLY(HttpStatus.FORBIDDEN, ApiErrorCategory.AUTHORIZATION, "Bu islem yalnizca amir veya yonetici icindir.", false),
    OFFICER_STATION_REQUIRED(HttpStatus.BAD_REQUEST, ApiErrorCategory.BUSINESS, "Amir hesabina bir karakol atanmalidir.", false),
    INTERNAL_NOTE_FORBIDDEN(HttpStatus.FORBIDDEN, ApiErrorCategory.AUTHORIZATION, "Vatandas kullanici ic not ekleyemez.", false),
    REPORT_NOT_FOUND(HttpStatus.NOT_FOUND, ApiErrorCategory.BUSINESS, "Sikayet kaydi bulunamadi.", false),
    REPORT_ACCESS_DENIED(HttpStatus.FORBIDDEN, ApiErrorCategory.AUTHORIZATION, "Bu sikayete erisim yetkiniz yok.", false),
    STORAGE_INIT_FAILED(HttpStatus.INTERNAL_SERVER_ERROR, ApiErrorCategory.SYSTEM, "Dosya depolama alani hazirlanamadi.", true),
    FILE_STORE_FAILED(HttpStatus.INTERNAL_SERVER_ERROR, ApiErrorCategory.SYSTEM, "Dosya kaydedilemedi.", true),
    MEDIA_TYPE_REQUIRED(HttpStatus.BAD_REQUEST, ApiErrorCategory.VALIDATION, "Dosya tipi anlasilamadi.", false),
    MEDIA_TYPE_UNSUPPORTED(HttpStatus.BAD_REQUEST, ApiErrorCategory.VALIDATION, "Sadece izin verilen foto ve video tipleri yuklenebilir.", false),
    LOCATION_REQUIRED(HttpStatus.BAD_REQUEST, ApiErrorCategory.VALIDATION, "Enlem ve boylam zorunludur.", false),
    VALIDATION_ERROR(HttpStatus.BAD_REQUEST, ApiErrorCategory.VALIDATION, "Gonderilen veri dogrulanamadi.", false),
    INVALID_PAYLOAD(HttpStatus.BAD_REQUEST, ApiErrorCategory.VALIDATION, "Istek govdesi okunamadi veya eksik gonderildi.", false),
    FILE_TOO_LARGE(HttpStatus.PAYLOAD_TOO_LARGE, ApiErrorCategory.VALIDATION, "Dosya boyutu izin verilen limiti asiyor.", false),
    RATE_LIMIT_EXCEEDED(HttpStatus.TOO_MANY_REQUESTS, ApiErrorCategory.RATE_LIMIT, "Cok fazla istek gonderildi. Lutfen daha sonra tekrar deneyin.", true),
    UNEXPECTED_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, ApiErrorCategory.SYSTEM, "Beklenmeyen bir hata olustu. Destek icin requestId bilgisini kaydedin.", true),

    // ── V2: Kriptografik Kanıt Bütünlüğü (Modül 2) ────────
    EVIDENCE_HASH_MISMATCH(HttpStatus.BAD_REQUEST, ApiErrorCategory.BUSINESS, "Kanit dosyasinin hash degeri sunucu tarafinda dogrulanamadi. Dosya tahrifata ugrams olabilir.", false),
    EVIDENCE_HASH_REQUIRED(HttpStatus.BAD_REQUEST, ApiErrorCategory.VALIDATION, "Her kanit dosyasi icin SHA-256 hash degeri gonderilmelidir.", false),

    // ── V2: Cihaz Doğrulama (Modül 1) ──────────────────────
    DEVICE_ATTESTATION_FAILED(HttpStatus.BAD_REQUEST, ApiErrorCategory.BUSINESS, "Cihaz guvenlik dogrulamasi basarisiz oldu.", false),

    // ── V2: Analytics (Modül 3) ─────────────────────────────
    INVALID_BOUNDING_BOX(HttpStatus.BAD_REQUEST, ApiErrorCategory.VALIDATION, "Gecersiz bounding box parametreleri gonderildi.", false);

    private final HttpStatus status;
    private final ApiErrorCategory category;
    private final String userMessage;
    private final boolean retryable;

    ErrorCode(HttpStatus status, ApiErrorCategory category, String userMessage, boolean retryable) {
        this.status = status;
        this.category = category;
        this.userMessage = userMessage;
        this.retryable = retryable;
    }

    public HttpStatus getStatus() {
        return status;
    }

    public ApiErrorCategory getCategory() {
        return category;
    }

    public String getCode() {
        return name();
    }

    public String getUserMessage() {
        return userMessage;
    }

    public boolean isRetryable() {
        return retryable;
    }
}
