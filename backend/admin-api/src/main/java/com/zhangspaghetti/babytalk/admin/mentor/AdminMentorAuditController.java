package com.zhangspaghetti.babytalk.admin.mentor;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/mentor")
@Validated
@PreAuthorize("hasAuthority('mentor:audit')")
public class AdminMentorAuditController {

    private final AdminMentorAuditService adminMentorAuditService;

    public AdminMentorAuditController(AdminMentorAuditService adminMentorAuditService) {
        this.adminMentorAuditService = adminMentorAuditService;
    }

    @GetMapping("/audits")
    public List<AdminMentorAuditService.QueueIncidentView> listAudits(
            @RequestParam(required = false) @Size(max = 128, message = "installationId 过长。") String installationId,
            @RequestParam(required = false) @Size(max = 64, message = "flag 过长。") String flag,
            @RequestParam(required = false) @Min(value = 1, message = "limit 至少为 1。") Integer limit
    ) {
        return adminMentorAuditService.listAudits(installationId, flag, limit);
    }

    @GetMapping("/audits/{correlationId}")
    public AdminMentorAuditService.AuditDetailView getAudit(
            @PathVariable @NotBlank(message = "correlationId 不能为空。") @Size(max = 96, message = "correlationId 过长。") String correlationId
    ) {
        return adminMentorAuditService.getAudit(correlationId);
    }
}
