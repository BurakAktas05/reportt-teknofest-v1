package com.reportt.complaintapp.api.report;

import com.reportt.complaintapp.dto.report.CaptureSessionResponse;
import com.reportt.complaintapp.dto.report.CreateReportRequest;
import com.reportt.complaintapp.dto.report.FeedbackRequest;
import com.reportt.complaintapp.dto.report.FeedbackResponse;
import com.reportt.complaintapp.dto.report.ReportResponse;
import com.reportt.complaintapp.dto.report.ReportStatusUpdateRequest;
import com.reportt.complaintapp.service.CaptureSessionService;
import com.reportt.complaintapp.service.ComplaintService;
import com.reportt.complaintapp.service.CurrentUserService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/reports")
public class ComplaintController {

    private final ComplaintService complaintService;
    private final CaptureSessionService captureSessionService;
    private final CurrentUserService currentUserService;

    public ComplaintController(
            ComplaintService complaintService,
            CaptureSessionService captureSessionService,
            CurrentUserService currentUserService
    ) {
        this.complaintService = complaintService;
        this.captureSessionService = captureSessionService;
        this.currentUserService = currentUserService;
    }

    @PostMapping("/capture-sessions")
    @ResponseStatus(HttpStatus.CREATED)
    public CaptureSessionResponse createCaptureSession() {
        return captureSessionService.createSession(currentUserService.getCurrentUser());
    }

    @PostMapping(consumes = {"multipart/form-data"})
    @ResponseStatus(HttpStatus.CREATED)
    public ReportResponse createReport(
            @Valid @RequestPart("payload") CreateReportRequest payload,
            @RequestPart("files") List<MultipartFile> files
    ) {
        return complaintService.createReport(currentUserService.getCurrentUser(), payload, files);
    }

    @GetMapping("/my")
    public List<ReportResponse> myReports() {
        return complaintService.listCitizenReports(currentUserService.getCurrentUser());
    }

    @GetMapping("/assigned")
    public List<ReportResponse> assignedReports() {
        return complaintService.listAssignedReports(currentUserService.getCurrentUser());
    }

    @GetMapping("/{reportId}")
    public ReportResponse reportDetail(@PathVariable Long reportId) {
        return complaintService.getReport(reportId, currentUserService.getCurrentUser());
    }

    @PostMapping("/{reportId}/feedback")
    @ResponseStatus(HttpStatus.CREATED)
    public FeedbackResponse addFeedback(@PathVariable Long reportId, @Valid @RequestBody FeedbackRequest payload) {
        return complaintService.addFeedback(reportId, currentUserService.getCurrentUser(), payload);
    }

    @PatchMapping("/{reportId}/status")
    public ReportResponse updateStatus(@PathVariable Long reportId, @Valid @RequestBody ReportStatusUpdateRequest payload) {
        return complaintService.updateStatus(reportId, currentUserService.getCurrentUser(), payload);
    }
}
