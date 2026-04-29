package com.reportt.complaintapp.service;

import com.reportt.complaintapp.domain.UserAccount;
import com.reportt.complaintapp.domain.enums.UserRole;
import com.reportt.complaintapp.dto.auth.AuthResponse;
import com.reportt.complaintapp.dto.auth.CreateOfficerRequest;
import com.reportt.complaintapp.dto.auth.LoginRequest;
import com.reportt.complaintapp.dto.auth.RegisterCitizenRequest;
import com.reportt.complaintapp.exception.ApiException;
import com.reportt.complaintapp.exception.ErrorCode;
import com.reportt.complaintapp.repository.PoliceStationRepository;
import com.reportt.complaintapp.repository.UserAccountRepository;
import com.reportt.complaintapp.security.JwtService;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserAccountRepository userAccountRepository;
    private final PoliceStationRepository policeStationRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;

    public AuthService(
            UserAccountRepository userAccountRepository,
            PoliceStationRepository policeStationRepository,
            PasswordEncoder passwordEncoder,
            AuthenticationManager authenticationManager,
            JwtService jwtService
    ) {
        this.userAccountRepository = userAccountRepository;
        this.policeStationRepository = policeStationRepository;
        this.passwordEncoder = passwordEncoder;
        this.authenticationManager = authenticationManager;
        this.jwtService = jwtService;
    }

    @Transactional
    public AuthResponse registerCitizen(RegisterCitizenRequest request) {
        validateUniqueness(request.phoneNumber(), request.email());

        UserAccount user = new UserAccount();
        user.setFullName(request.fullName());
        user.setPhoneNumber(request.phoneNumber());
        user.setEmail(request.email());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setRole(UserRole.CITIZEN);

        return toAuthResponse(userAccountRepository.save(user));
    }

    @Transactional
    public AuthResponse createOfficer(CreateOfficerRequest request) {
        validateUniqueness(request.phoneNumber(), request.email());

        UserRole role = request.role() == null ? UserRole.OFFICER : request.role();
        if (role == UserRole.CITIZEN) {
            throw new ApiException(ErrorCode.INVALID_ROLE, "Bu endpoint yalnizca amir veya admin olusturabilir.");
        }

        UserAccount user = new UserAccount();
        user.setFullName(request.fullName());
        user.setPhoneNumber(request.phoneNumber());
        user.setEmail(request.email());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setRole(role);
        if (request.stationCode() != null && !request.stationCode().isBlank()) {
            user.setAssignedStation(policeStationRepository.findByRegistrationCode(request.stationCode())
                    .orElseThrow(() -> new ApiException(ErrorCode.STATION_NOT_FOUND, "Gecersiz karakol kayit kodu (UUID).")));
        }

        return toAuthResponse(userAccountRepository.save(user));
    }

    public AuthResponse login(LoginRequest request) {
        authenticationManager.authenticate(new UsernamePasswordAuthenticationToken(request.phoneNumber(), request.password()));
        UserAccount user = userAccountRepository.findByPhoneNumber(request.phoneNumber())
                .orElseThrow(() -> new ApiException(ErrorCode.AUTH_INVALID, "Telefon numarasi veya sifre hatali."));
        return toAuthResponse(user);
    }

    private void validateUniqueness(String phoneNumber, String email) {
        if (userAccountRepository.existsByPhoneNumber(phoneNumber)) {
            throw new ApiException(ErrorCode.PHONE_EXISTS);
        }
        if (email != null && !email.isBlank() && userAccountRepository.existsByEmail(email)) {
            throw new ApiException(ErrorCode.EMAIL_EXISTS);
        }
    }

    private AuthResponse toAuthResponse(UserAccount user) {
        return new AuthResponse(
                user.getId(),
                user.getFullName(),
                user.getPhoneNumber(),
                user.getRole().name(),
                user.getReputationScore(),
                jwtService.generateToken(user)
        );
    }
}
