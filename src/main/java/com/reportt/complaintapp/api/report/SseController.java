package com.reportt.complaintapp.api.report;

import com.reportt.complaintapp.service.CurrentUserService;
import com.reportt.complaintapp.service.SseService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/**
 * Server-Sent Events endpoint'i — gerçek zamanlı bildirimler.
 * Flutter tarafında EventSource ile dinlenir.
 */
@Tag(name = "Real-Time", description = "SSE gerçek zamanlı bildirim akışı")
@RestController
@RequestMapping("/api/stream")
public class SseController {

    private final SseService sseService;
    private final CurrentUserService currentUserService;

    public SseController(SseService sseService, CurrentUserService currentUserService) {
        this.sseService = sseService;
        this.currentUserService = currentUserService;
    }

    @Operation(summary = "Gerçek zamanlı bildirim akışı (SSE)", description = "İhbar durum değişiklikleri, rozet kazanımları vb. anında iletilir.")
    @GetMapping(value = "/events", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter subscribe() {
        var user = currentUserService.getCurrentUser();
        return sseService.subscribe(user.getId());
    }
}
