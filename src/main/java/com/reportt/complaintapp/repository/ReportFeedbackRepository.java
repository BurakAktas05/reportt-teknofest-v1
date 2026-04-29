package com.reportt.complaintapp.repository;

import com.reportt.complaintapp.domain.ReportFeedback;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReportFeedbackRepository extends JpaRepository<ReportFeedback, Long> {

    List<ReportFeedback> findByComplaintReportIdOrderByCreatedAtAsc(Long complaintReportId);
}
