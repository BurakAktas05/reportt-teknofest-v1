package com.reportt.complaintapp.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import com.reportt.complaintapp.domain.UserAccount;
import org.springframework.stereotype.Service;

import java.util.Map;

/**
 * V3: Firebase Cloud Messaging (FCM) push bildirim servisi.
 *
 * <p>Kullanıcının cihazına anlık bildirim gönderir.
 * FCM token'ı olmayan veya Firebase başlatılmamış ise sessizce atlar.</p>
 */
@Service
public class NotificationService {

    private final FirebaseMessaging firebaseMessaging;

    public NotificationService(FirebaseMessaging firebaseMessaging) {
        this.firebaseMessaging = firebaseMessaging;
    }

    /**
     * Belirli bir kullanıcıya push bildirim gönderir.
     *
     * @param user    hedef kullanıcı
     * @param title   bildirim başlığı
     * @param body    bildirim metni
     * @param data    ek veri (örn: reportId, newStatus)
     */
    public void sendToUser(UserAccount user, String title, String body, Map<String, String> data) {
        if (firebaseMessaging == null) {
            System.err.println("[FCM] Firebase başlatılmamış, bildirim gönderilemedi.");
            return;
        }

        String fcmToken = user.getFcmToken();
        if (fcmToken == null || fcmToken.isBlank()) {
            return; // Kullanıcının FCM token'ı yok, sessizce atla
        }

        try {
            Message message = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                    .putAllData(data != null ? data : Map.of())
                    .build();

            String messageId = firebaseMessaging.send(message);
            System.out.println("[FCM] Bildirim gönderildi: " + messageId + " → userId: " + user.getId());
        } catch (FirebaseMessagingException e) {
            System.err.println("[FCM] Bildirim gönderilemedi (userId: " + user.getId() + "): " + e.getMessage());
        }
    }

    /**
     * İhbar durum değişikliği bildirimi gönderir.
     */
    public void notifyReportStatusChange(UserAccount citizen, Long reportId, String newStatus) {
        String title = "📋 İhbar Durumu Güncellendi";
        String body = switch (newStatus) {
            case "VERIFIED" -> "İhbarınız doğrulandı! Teşekkür ederiz. 🎉";
            case "REJECTED" -> "İhbarınız inceleme sonucunda reddedildi.";
            case "REJECTED_BY_SYSTEM" -> "İhbarınız sistem tarafından otomatik reddedildi.";
            case "SUBMITTED" -> "İhbarınız analiz edildi ve inceleme için gönderildi.";
            case "IN_PROGRESS" -> "İhbarınız memur tarafından işleme alındı. 🔍";
            case "RESOLVED" -> "İhbarınız çözüldü! ✅";
            default -> "İhbar durumunuz güncellendi: " + newStatus;
        };

        sendToUser(citizen, title, body, Map.of(
                "reportId", String.valueOf(reportId),
                "newStatus", newStatus,
                "type", "report_status_change"
        ));
    }
}
