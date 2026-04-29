package com.reportt.complaintapp.dto.auth;

import jakarta.validation.constraints.NotBlank;

/**
 * V3: FCM token kayıt isteği.
 * Kullanıcı giriş yaptıktan sonra cihaz token'ını gönderir.
 */
public record FcmTokenRequest(
        @NotBlank(message = "FCM token boş olamaz.")
        String fcmToken
) {
}
