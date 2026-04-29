package com.reportt.complaintapp.repository;

import com.reportt.complaintapp.domain.EvidenceMedia;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EvidenceMediaRepository extends JpaRepository<EvidenceMedia, Long> {

    List<EvidenceMedia> findByComplaintReportIdOrderByCreatedAtAsc(Long complaintReportId);
}
