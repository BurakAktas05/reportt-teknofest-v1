package com.reportt.complaintapp.api.auth;

import com.reportt.complaintapp.dto.auth.AuthResponse;
import com.reportt.complaintapp.dto.auth.CreateOfficerRequest;
import com.reportt.complaintapp.dto.auth.LoginRequest;
import com.reportt.complaintapp.dto.auth.RegisterCitizenRequest;
import com.reportt.complaintapp.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register/citizen")
    @ResponseStatus(HttpStatus.CREATED)
    public AuthResponse registerCitizen(@Valid @RequestBody RegisterCitizenRequest request) {
        return authService.registerCitizen(request);
    }

    @PostMapping("/register/officer")
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public AuthResponse registerOfficer(@Valid @RequestBody CreateOfficerRequest request) {
        return authService.createOfficer(request);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }
}
