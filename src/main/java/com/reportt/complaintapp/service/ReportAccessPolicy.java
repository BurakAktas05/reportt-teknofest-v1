package com.reportt.complaintapp.service;

import com.reportt.complaintapp.domain.ComplaintReport;
import com.reportt.complaintapp.domain.UserAccount;
import com.reportt.complaintapp.domain.enums.UserRole;
import com.reportt.complaintapp.exception.ApiException;
import com.reportt.complaintapp.exception.ErrorCode;
import org.springframework.stereotype.Component;

@Component
public class ReportAccessPolicy {

    public void assertCitizenCanCreate(UserAccount actor) {
        if (actor.getRole() != UserRole.CITIZEN) {
            throw new ApiException(ErrorCode.ONLY_CITIZEN_CAN_REPORT);
        }
    }

    public void assertOfficerCapabilities(UserAccount actor) {
        if (actor.getRole() == UserRole.CITIZEN) {
            throw new ApiException(ErrorCode.OFFICER_ONLY);
        }
    }

    public void assertCanAccessReport(ComplaintReport report, UserAccount actor) {
        if (actor.getRole() == UserRole.CITIZEN && !report.getCitizen().getId().equals(actor.getId())) {
            throw new ApiException(ErrorCode.REPORT_ACCESS_DENIED);
        }
        if (actor.getRole() == UserRole.OFFICER) {
            if (actor.getAssignedStation() == null || !report.getAssignedStation().getId().equals(actor.getAssignedStation().getId())) {
                throw new ApiException(ErrorCode.REPORT_ACCESS_DENIED);
            }
        }
    }
}
