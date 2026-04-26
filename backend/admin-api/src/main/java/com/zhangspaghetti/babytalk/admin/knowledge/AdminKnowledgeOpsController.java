package com.zhangspaghetti.babytalk.admin.knowledge;

import com.zhangspaghetti.babytalk.admin.auth.AdminApiContractException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.io.IOException;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@Validated
@RequestMapping("/api/admin/knowledge")
public class AdminKnowledgeOpsController {

    private final AdminKnowledgeOpsService adminKnowledgeOpsService;

    public AdminKnowledgeOpsController(AdminKnowledgeOpsService adminKnowledgeOpsService) {
        this.adminKnowledgeOpsService = adminKnowledgeOpsService;
    }

    @GetMapping("/ingestion/jobs")
    @PreAuthorize("hasAuthority('rag:read')")
    public List<AdminKnowledgeOpsService.IngestionJobView> listIngestionJobs(
            @RequestParam(required = false) @Size(max = 32, message = "status 过长。") String status,
            @RequestParam(required = false) @Min(value = 1, message = "limit 至少为 1。") Integer limit
    ) {
        return adminKnowledgeOpsService.listIngestionJobs(status, limit);
    }

    @GetMapping("/ingestion/jobs/{jobId}")
    @PreAuthorize("hasAuthority('rag:read')")
    public AdminKnowledgeOpsService.IngestionJobView getIngestionJob(
            @PathVariable @NotBlank(message = "jobId 不能为空。") @Size(max = 36, message = "jobId 过长。") String jobId
    ) {
        return adminKnowledgeOpsService.getIngestionJob(jobId);
    }

    @PostMapping(value = "/ingestion/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAuthority('rag:write')")
    public ResponseEntity<AdminKnowledgeOpsService.IngestionJobMutationView> uploadIngestion(
            @RequestParam(value = "file", required = false) MultipartFile file,
            @RequestParam(value = "bookTitle", required = false) @Size(max = 255, message = "bookTitle 过长。") String bookTitle
    ) {
        if (file == null || file.isEmpty()) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_knowledge_ingestion_file",
                    "上传文件不能为空。",
                    Map.of("field", "file"));
        }
        try (var inputStream = file.getInputStream()) {
            return ResponseEntity.accepted().body(adminKnowledgeOpsService.uploadIngestion(
                    file.getOriginalFilename(),
                    inputStream,
                    file.getContentType(),
                    bookTitle));
        } catch (IOException exception) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_knowledge_ingestion_file",
                    "上传文件读取失败。",
                    Map.of("field", "file"));
        }
    }

    @PostMapping("/ingestion/jobs/{jobId}/retry")
    @PreAuthorize("hasAuthority('rag:write')")
    public ResponseEntity<AdminKnowledgeOpsService.IngestionJobMutationView> retryIngestionJob(
            @PathVariable @NotBlank(message = "jobId 不能为空。") @Size(max = 36, message = "jobId 过长。") String jobId
    ) {
        return ResponseEntity.accepted().body(adminKnowledgeOpsService.retryIngestionJob(jobId));
    }

    @GetMapping("/kg/contradictions")
    @PreAuthorize("hasAuthority('kg:read')")
    public List<AdminKnowledgeOpsService.ContradictionQueueItemView> listContradictions(
            @RequestParam(required = false) @Size(max = 32, message = "status 过长。") String status,
            @RequestParam(required = false) @Min(value = 1, message = "limit 至少为 1。") Integer limit
    ) {
        return adminKnowledgeOpsService.listContradictions(status, limit);
    }

    @GetMapping("/kg/contradictions/{contradictionId}")
    @PreAuthorize("hasAuthority('kg:read')")
    public AdminKnowledgeOpsService.ContradictionDetailView getContradiction(
            @PathVariable @NotBlank(message = "contradictionId 不能为空。")
            @Size(max = 36, message = "contradictionId 过长。") String contradictionId
    ) {
        return adminKnowledgeOpsService.getContradiction(contradictionId);
    }

    @GetMapping("/kg/contradictions/{contradictionId}/notifications")
    @PreAuthorize("hasAuthority('kg:read')")
    public List<AdminKnowledgeOpsService.NotificationView> listNotifications(
            @PathVariable @NotBlank(message = "contradictionId 不能为空。")
            @Size(max = 36, message = "contradictionId 过长。") String contradictionId,
            @RequestParam(required = false) @Min(value = 1, message = "limit 至少为 1。") Integer limit
    ) {
        return adminKnowledgeOpsService.listNotifications(contradictionId, limit);
    }

    @PatchMapping("/kg/contradictions/{contradictionId}/resolve")
    @PreAuthorize("hasAuthority('kg:review')")
    public AdminKnowledgeOpsService.ContradictionDetailView resolveContradiction(
            @PathVariable @NotBlank(message = "contradictionId 不能为空。")
            @Size(max = 36, message = "contradictionId 过长。") String contradictionId,
            @Valid @RequestBody(required = false) ResolveContradictionRequest request
    ) {
        return adminKnowledgeOpsService.resolveContradiction(
                contradictionId,
                request == null ? null : request.adminNotes()
        );
    }

    @PatchMapping("/kg/notifications/{notificationId}/read")
    @PreAuthorize("hasAuthority('kg:review')")
    public AdminKnowledgeOpsService.NotificationView markNotificationRead(
            @PathVariable @NotBlank(message = "notificationId 不能为空。")
            @Size(max = 36, message = "notificationId 过长。") String notificationId
    ) {
        return adminKnowledgeOpsService.markNotificationRead(notificationId);
    }

    record ResolveContradictionRequest(
            @Size(max = 500, message = "adminNotes 过长。") String adminNotes
    ) {
    }
}
