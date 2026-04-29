package com.reportt.complaintapp.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import java.io.IOException;
import java.io.InputStream;

/**
 * V3: Firebase Admin SDK yapılandırması.
 *
 * <p>classpath:firebase-service-account.json dosyasından
 * kimlik bilgilerini okur ve FirebaseApp'i başlatır.</p>
 */
@Configuration
public class FirebaseConfig {

    @PostConstruct
    public void initFirebase() {
        try {
            if (FirebaseApp.getApps().isEmpty()) {
                InputStream serviceAccount = new ClassPathResource("firebase-service-account.json").getInputStream();
                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                        .build();
                FirebaseApp.initializeApp(options);
                System.out.println("[Firebase] Admin SDK başarıyla başlatıldı.");
            }
        } catch (IOException e) {
            System.err.println("[Firebase] UYARI: Service account dosyası bulunamadı. Push bildirimler devre dışı. " + e.getMessage());
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
}
