package com.reportt.complaintapp.service;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/**
 * Server-Sent Events (SSE) servisi — gerçek zamanlı bildirim altyapısı.
 *
 * Her kullanıcı bir SSE bağlantısı açar. İhbar durumu değiştiğinde
 * ilgili kullanıcıya anında push edilir.
 */
@Service
public class SseService {

    /** userId → aktif SSE bağlantıları */
    private final Map<Long, List<SseEmitter>> emitters = new ConcurrentHashMap<>();

    /**
     * Kullanıcı için yeni bir SSE bağlantısı oluşturur.
     * Timeout: 30 dakika.
     */
    public SseEmitter subscribe(Long userId) {
        SseEmitter emitter = new SseEmitter(30 * 60 * 1000L); // 30 dk

        emitters.computeIfAbsent(userId, k -> new CopyOnWriteArrayList<>()).add(emitter);

        emitter.onCompletion(() -> removeEmitter(userId, emitter));
        emitter.onTimeout(() -> removeEmitter(userId, emitter));
        emitter.onError(e -> removeEmitter(userId, emitter));

        // İlk bağlantı mesajı
        try {
            emitter.send(SseEmitter.event()
                    .name("connected")
                    .data(Map.of("message", "SSE baglantisi kuruldu."))
            );
        } catch (IOException e) {
            removeEmitter(userId, emitter);
        }

        return emitter;
    }

    /**
     * Belirli bir kullanıcıya olay gönderir.
     *
     * @param userId hedef kullanıcı
     * @param eventName olay adı (örn: "report_update", "badge_earned")
     * @param data olay verisi
     */
    public void sendToUser(Long userId, String eventName, Object data) {
        List<SseEmitter> userEmitters = emitters.get(userId);
        if (userEmitters == null || userEmitters.isEmpty()) return;

        List<SseEmitter> deadEmitters = new java.util.ArrayList<>();

        for (SseEmitter emitter : userEmitters) {
            try {
                emitter.send(SseEmitter.event()
                        .name(eventName)
                        .data(data)
                );
            } catch (Exception e) {
                deadEmitters.add(emitter);
            }
        }

        userEmitters.removeAll(deadEmitters);
    }

    /**
     * Tüm bağlı kullanıcılara broadcast yapar.
     */
    public void broadcast(String eventName, Object data) {
        emitters.forEach((userId, userEmitters) -> {
            List<SseEmitter> dead = new java.util.ArrayList<>();
            for (SseEmitter emitter : userEmitters) {
                try {
                    emitter.send(SseEmitter.event().name(eventName).data(data));
                } catch (Exception e) {
                    dead.add(emitter);
                }
            }
            userEmitters.removeAll(dead);
        });
    }

    private void removeEmitter(Long userId, SseEmitter emitter) {
        List<SseEmitter> userEmitters = emitters.get(userId);
        if (userEmitters != null) {
            userEmitters.remove(emitter);
            if (userEmitters.isEmpty()) {
                emitters.remove(userId);
            }
        }
    }
}
