package com.reportt.complaintapp.service;

import com.reportt.complaintapp.domain.UserAccount;
import com.reportt.complaintapp.exception.ApiException;
import com.reportt.complaintapp.exception.ErrorCode;
import com.reportt.complaintapp.repository.UserAccountRepository;
import com.reportt.complaintapp.security.CustomUserPrincipal;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

@Service
public class CurrentUserService {

    private final UserAccountRepository userAccountRepository;

    public CurrentUserService(UserAccountRepository userAccountRepository) {
        this.userAccountRepository = userAccountRepository;
    }

    public UserAccount getCurrentUser() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof CustomUserPrincipal principal)) {
            throw new ApiException(ErrorCode.AUTH_REQUIRED);
        }

        return userAccountRepository.findById(principal.getId())
                .orElseThrow(() -> new ApiException(ErrorCode.AUTH_INVALID, "Kullanici bulunamadi."));
    }
}
