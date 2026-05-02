package com.reportt.complaintapp.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

/**
 * V3: Firebase Admin SDK yapılandırması.
 *
 * <p>Credentials şu sırayla aranır:</p>
 * <ol>
 *   <li>FIREBASE_CREDENTIALS_JSON env var (raw JSON)</li>
 *   <li>FIREBASE_CREDENTIALS_BASE64 env var (Base64-encoded JSON — Railway için ideal)</li>
 *   <li>classpath:firebase-service-account.json (fallback — yalnızca local dev)</li>
 * </ol>
 */
@Configuration
public class FirebaseConfig {

    @Value("${FIREBASE_CREDENTIALS_JSON:}")
    private String firebaseCredentialsJson;

    @Value("${FIREBASE_CREDENTIALS_BASE64:}")
    private String firebaseCredentialsBase64;

    @PostConstruct
    public void initFirebase() {
        try {
            if (FirebaseApp.getApps().isEmpty()) {
                InputStream credentialsStream = resolveCredentials();
                if (credentialsStream == null) {
                    System.err.println("[Firebase] UYARI: Kimlik bilgileri bulunamadı. Push bildirimler devre dışı.");
                    return;
                }

                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(credentialsStream))
                        .build();
                FirebaseApp.initializeApp(options);
                System.out.println("[Firebase] Admin SDK başarıyla başlatıldı.");
            }
        } catch (IOException e) {
            System.err.println("[Firebase] UYARI: Firebase başlatılamadı. Push bildirimler devre dışı. " + e.getMessage());
        }
    }

    @Bean
    public FirebaseMessaging firebaseMessaging() {
        try {
            return FirebaseMessaging.getInstance();
        } catch (Exception e) {
            System.err.println("[Firebase] FirebaseMessaging oluşturulamadı: " + e.getMessage());
            return null;
        }
    }

    /**
     * Ortam değişkenlerinden veya classpath'ten Firebase credentials'ını çözümler.
     */
    private InputStream resolveCredentials() {
        // 1) Raw JSON env variable
        if (firebaseCredentialsJson != null && !firebaseCredentialsJson.isBlank()) {
            System.out.println("[Firebase] Credentials: FIREBASE_CREDENTIALS_JSON env var");
            return new ByteArrayInputStream(firebaseCredentialsJson.getBytes(StandardCharsets.UTF_8));
        }

        // 2) Base64-encoded JSON env variable (Railway friendly)
        if (firebaseCredentialsBase64 != null && !firebaseCredentialsBase64.isBlank()) {
            System.out.println("[Firebase] Credentials: FIREBASE_CREDENTIALS_BASE64 env var");
            byte[] decoded = Base64.getDecoder().decode(firebaseCredentialsBase64);
            return new ByteArrayInputStream(decoded);
        }

        // 3) Classpath fallback (local development only)
        try {
            InputStream is = new ClassPathResource("firebase-service-account.json").getInputStream();
            System.out.println("[Firebase] Credentials: classpath:firebase-service-account.json (local dev)");
            return is;
        } catch (IOException e) {
            return null;
        }
    }
}
