package com.reportt.complaintapp.repository;

import com.reportt.complaintapp.domain.CaptureSession;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CaptureSessionRepository extends JpaRepository<CaptureSession, Long> {

    Optional<CaptureSession> findBySessionToken(String sessionToken);
}
