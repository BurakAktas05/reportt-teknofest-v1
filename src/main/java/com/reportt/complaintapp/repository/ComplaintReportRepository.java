package com.reportt.complaintapp.repository;

import com.reportt.complaintapp.domain.ComplaintReport;
import com.reportt.complaintapp.domain.UserAccount;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ComplaintReportRepository extends JpaRepository<ComplaintReport, Long> {

    List<ComplaintReport> findByCitizenOrderByCreatedAtDesc(UserAccount citizen);

    List<ComplaintReport> findByAssignedStationIdOrderByCreatedAtDesc(Long stationId);
}
