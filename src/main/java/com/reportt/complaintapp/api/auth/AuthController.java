package com.reportt.complaintapp.api.auth;

import com.reportt.complaintapp.dto.auth.AuthResponse;
import com.reportt.complaintapp.dto.auth.CreateOfficerRequest;
import com.reportt.complaintapp.dto.auth.FcmTokenRequest;
import com.reportt.complaintapp.dto.auth.LoginRequest;
import com.reportt.complaintapp.dto.auth.RefreshTokenRequest;
import com.reportt.complaintapp.dto.auth.RegisterCitizenRequest;
import com.reportt.complaintapp.domain.UserAccount;
import com.reportt.complaintapp.repository.UserAccountRepository;
import com.reportt.complaintapp.service.AuthService;
import com.reportt.complaintapp.service.CurrentUserService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

import java.util.Map;

@Tag(name = "Authentication", description = "Kayıt, giriş ve FCM token endpoint'leri")
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;
    private final CurrentUserService currentUserService;
    private final UserAccountRepository userAccountRepository;

    public AuthController(AuthService authService, CurrentUserService currentUserService, UserAccountRepository userAccountRepository) {
        this.authService = authService;
        this.currentUserService = currentUserService;
        this.userAccountRepository = userAccountRepository;
    }

    @PostMapping("/register/citizen")
    @ResponseStatus(HttpStatus.CREATED)
    public AuthResponse registerCitizen(@Valid @RequestBody RegisterCitizenRequest request) {
        return authService.registerCitizen(request);
    }

    @PostMapping("/register/officer")
    @ResponseStatus(HttpStatus.CREATED)
    public AuthResponse registerOfficer(@Valid @RequestBody CreateOfficerRequest request) {
        return authService.createOfficer(request);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    @PostMapping("/refresh")
    public AuthResponse refreshToken(@Valid @RequestBody RefreshTokenRequest request) {
        return authService.refreshToken(request);
    }

    /**
     * V3: FCM cihaz token kaydı.
     * Kullanıcı giriş yaptıktan sonra cihaz token'ını sunucuya bildirir.
     */
    @Operation(summary = "FCM token kaydet", description = "Kullanıcı cihaz FCM token'ını kaydeder.")
    @PostMapping("/fcm-token")
    public Map<String, String> saveFcmToken(@Valid @RequestBody FcmTokenRequest request) {
        UserAccount user = currentUserService.getCurrentUser();
        user.setFcmToken(request.fcmToken());
        userAccountRepository.save(user);
        return Map.of("status", "ok", "message", "FCM token kaydedildi.");
    }
}

