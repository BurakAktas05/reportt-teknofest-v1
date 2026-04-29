package com.reportt.complaintapp.service;

import com.reportt.complaintapp.domain.ComplaintReport;
import com.reportt.complaintapp.domain.PoliceStation;
import com.reportt.complaintapp.domain.UserAccount;
import com.reportt.complaintapp.domain.enums.UserRole;
import com.reportt.complaintapp.exception.ApiException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * ReportAccessPolicy birim testleri.
 * Rol bazlı erişim kontrolünü doğrular.
 */
class ReportAccessPolicyTest {

    private ReportAccessPolicy policy;
    private UserAccount citizen1;
    private UserAccount citizen2;
    private UserAccount officer;
    private ComplaintReport report;
    private PoliceStation station;

    @BeforeEach
    void setUp() {
        policy = new ReportAccessPolicy();

        station = new PoliceStation();
        station.setId(100L);

        citizen1 = new UserAccount();
        citizen1.setId(1L);
        citizen1.setRole(UserRole.CITIZEN);

        citizen2 = new UserAccount();
        citizen2.setId(2L);
        citizen2.setRole(UserRole.CITIZEN);

        officer = new UserAccount();
        officer.setId(3L);
        officer.setRole(UserRole.OFFICER);
        officer.setAssignedStation(station);

        report = new ComplaintReport();
        report.setId(10L);
        report.setCitizen(citizen1);
        report.setAssignedStation(station);
    }

    @Test
    @DisplayName("Vatandaş kendi ihbarına erişebilmeli")
    void citizenShouldAccessOwnReport() {
        assertDoesNotThrow(() -> policy.assertCanAccessReport(report, citizen1));
    }

    @Test
    @DisplayName("Vatandaş başkasının ihbarına erişememeli")
    void citizenShouldNotAccessOthersReport() {
        assertThrows(ApiException.class, () -> policy.assertCanAccessReport(report, citizen2));
    }

    @Test
    @DisplayName("Memur aynı karakola atanmış ihbara erişebilmeli")
    void officerShouldAccessStationReport() {
        assertDoesNotThrow(() -> policy.assertCanAccessReport(report, officer));
    }

    @Test
    @DisplayName("Memur farklı karakol ihbarına erişememeli")
    void officerShouldNotAccessDifferentStationReport() {
        PoliceStation otherStation = new PoliceStation();
        otherStation.setId(999L);
        officer.setAssignedStation(otherStation);

        assertThrows(ApiException.class, () -> policy.assertCanAccessReport(report, officer));
    }

    @Test
    @DisplayName("Sadece CITIZEN ihbar oluşturabilmeli")
    void onlyCitizenCanCreateReport() {
        assertDoesNotThrow(() -> policy.assertCitizenCanCreate(citizen1));
        assertThrows(ApiException.class, () -> policy.assertCitizenCanCreate(officer));
    }
}
