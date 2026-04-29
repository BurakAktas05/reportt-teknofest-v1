package com.reportt.complaintapp.service;

import com.reportt.complaintapp.domain.enums.ReportCategory;
import java.nio.file.Path;

public interface MediaInspectionService {

    MediaInspectionResult inspect(Path mediaFile, String contentType, ReportCategory category);
}
