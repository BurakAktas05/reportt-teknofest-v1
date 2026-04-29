package com.reportt.complaintapp.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.reportt.complaintapp.config.MediaAnalysisProperties;
import com.reportt.complaintapp.domain.enums.MediaAnalysisStatus;
import com.reportt.complaintapp.domain.enums.ReportCategory;
import java.io.IOException;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import org.springframework.stereotype.Service;

/**
 * Python media_guard.py betiğini çalıştırarak medya analizi + NLP aciliyet skoru üretir.
 *
 * <p>V2 ile eklenen {@code --description} parametresi sayesinde Python tarafında
 * NLP tabanlı aciliyet skoru (1–10) hesaplanır.</p>
 */
@Service
public class PythonMediaInspectionService implements MediaInspectionService {

    private final MediaAnalysisProperties properties;
    private final ObjectMapper objectMapper;

    public PythonMediaInspectionService(MediaAnalysisProperties properties, ObjectMapper objectMapper) {
        this.properties = properties;
        this.objectMapper = objectMapper;
    }

    @Override
    public MediaInspectionResult inspect(Path mediaFile, String contentType, ReportCategory category, String description) {
        if (!properties.enabled()) {
            return MediaInspectionResult.failed("Otomatik medya analizi devre disi.");
        }

        List<String> command = new ArrayList<>(List.of(
                properties.pythonCommand(),
                properties.scriptPath(),
                "--file", mediaFile.toAbsolutePath().toString(),
                "--content-type", contentType == null ? "" : contentType,
                "--category", category.name()
        ));

        // V2: NLP için açıklama metni gönder
        if (description != null && !description.isBlank()) {
            command.add("--description");
            command.add(description);
        }

        ProcessBuilder processBuilder = new ProcessBuilder(command);
        processBuilder.redirectErrorStream(true);

        try {
            Process process = processBuilder.start();
            boolean finished = process.waitFor(properties.timeoutSeconds(), TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                return MediaInspectionResult.failed("Otomatik analiz zaman asimina ugradi.");
            }

            String output = new String(process.getInputStream().readAllBytes());
            if (process.exitValue() != 0) {
                return MediaInspectionResult.failed("Python analiz servisi hata verdi.");
            }

            JsonNode root = objectMapper.readTree(output);
            return new MediaInspectionResult(
                    MediaAnalysisStatus.valueOf(root.path("analysisStatus").asText("FAILED")),
                    root.path("summary").asText("Analiz sonucu alinamadi."),
                    root.hasNonNull("outdoorConfidence") ? root.get("outdoorConfidence").asDouble() : null,
                    root.hasNonNull("selfieRisk") ? root.get("selfieRisk").asDouble() : null,
                    root.hasNonNull("detectedPlate") ? root.get("detectedPlate").asText() : null,
                    root.path("reviewRequired").asBoolean(true),
                    output,
                    // V2: urgencyScore ve nlpSummary
                    root.hasNonNull("urgencyScore") ? root.get("urgencyScore").asInt() : null,
                    root.hasNonNull("nlpSummary") ? root.get("nlpSummary").asText() : null
            );
        } catch (IOException exception) {
            return MediaInspectionResult.failed("Python analiz servisine erisilemedi.");
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            return MediaInspectionResult.failed("Analiz islemi yarida kesildi.");
        } catch (RuntimeException exception) {
            return MediaInspectionResult.failed("Analiz cevabi islenemedi.");
        }
    }
}
