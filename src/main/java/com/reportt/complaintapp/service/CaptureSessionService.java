package com.reportt.complaintapp.service;

import com.reportt.complaintapp.config.CaptureProperties;
import com.reportt.complaintapp.domain.CaptureSession;
import com.reportt.complaintapp.domain.UserAccount;
import com.reportt.complaintapp.dto.report.CaptureSessionResponse;
import com.reportt.complaintapp.exception.ApiException;
import com.reportt.complaintapp.exception.ErrorCode;
import com.reportt.complaintapp.repository.CaptureSessionRepository;
import java.time.LocalDateTime;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CaptureSessionService {

    private final CaptureSessionRepository captureSessionRepository;
    private final CaptureProperties captureProperties;

    public CaptureSessionService(CaptureSessionRepository captureSessionRepository, CaptureProperties captureProperties) {
        this.captureSessionRepository = captureSessionRepository;
        this.captureProperties = captureProperties;
    }

    @Transactional
    public CaptureSessionResponse createSession(UserAccount citizen) {
        CaptureSession session = new CaptureSession();
        session.setCitizen(citizen);
        session.setSessionToken(UUID.randomUUID().toString());
        session.setExpiresAt(LocalDateTime.now().plusMinutes(captureProperties.sessionValidityMinutes()));
        session.setConsumed(false);

        CaptureSession saved = captureSessionRepository.save(session);
        return new CaptureSessionResponse(saved.getSessionToken(), saved.getExpiresAt());
    }

    @Transactional
    public void validateAndConsume(String token, UserAccount citizen) {
        CaptureSession session = captureSessionRepository.findBySessionToken(token)
                .orElseThrow(() -> new ApiException(ErrorCode.CAPTURE_SESSION_INVALID, "Canli cekim oturumu bulunamadi."));

        // Tek kullanimlik, kisa omurlu oturum galeriden eski medya yuklenmesini zorlastirir.
        if (!session.getCitizen().getId().equals(citizen.getId())) {
            throw new ApiException(ErrorCode.CAPTURE_SESSION_FORBIDDEN);
        }
        if (session.isConsumed()) {
            throw new ApiException(ErrorCode.CAPTURE_SESSION_USED);
        }
        if (session.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new ApiException(ErrorCode.CAPTURE_SESSION_EXPIRED);
        }

        session.setConsumed(true);
        captureSessionRepository.save(session);
    }
}
