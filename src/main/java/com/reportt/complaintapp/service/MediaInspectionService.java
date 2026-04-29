package com.reportt.complaintapp.service;

import com.reportt.complaintapp.domain.enums.ReportCategory;
import java.nio.file.Path;

public interface MediaInspectionService {

    /**
     * Medya dosyasını analiz eder.
     *
     * @param mediaFile analiz edilecek dosya
     * @param contentType dosya tipi
     * @param category ihbar kategorisi
     * @param description V2: NLP aciliyet analizi için ihbar açıklama metni
     * @return analiz sonucu
     */
    MediaInspectionResult inspect(Path mediaFile, String contentType, ReportCategory category, String description);
}
