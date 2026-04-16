package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.CaregiverInviteService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.nio.charset.StandardCharsets;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Validated
public class CaregiverInviteController {

    private static final MediaType HTML_UTF8 = new MediaType(MediaType.TEXT_HTML, StandardCharsets.UTF_8);

    private final CaregiverInviteService caregiverInviteService;

    public CaregiverInviteController(CaregiverInviteService caregiverInviteService) {
        this.caregiverInviteService = caregiverInviteService;
    }

    @PostMapping("/api/v1/caregiver-invites")
    @ResponseStatus(HttpStatus.CREATED)
    public CaregiverInviteService.CreateInviteResponse createInvite(
            @RequestHeader("X-Session-Id") String sessionId,
            @Valid @RequestBody CreateInviteRequest request
    ) {
        return caregiverInviteService.createInvite(
                sessionId,
                new CaregiverInviteService.CreateInviteCommand(request.role(), request.source())
        );
    }

    @PostMapping("/api/v1/caregiver-invites/accept")
    public CaregiverInviteService.AcceptInviteResponse acceptInvite(
            @RequestHeader("X-Session-Id") String sessionId,
            @Valid @RequestBody AcceptInviteRequest request
    ) {
        return caregiverInviteService.acceptInvite(
                sessionId,
                new CaregiverInviteService.AcceptInviteCommand(request.token(), request.source())
        );
    }

    @PostMapping("/api/v1/caregiver-invites/{token}/revoke")
    public CaregiverInviteService.RevokeInviteResponse revokeInvite(
            @RequestHeader("X-Session-Id") String sessionId,
            @PathVariable("token") String token
    ) {
        return caregiverInviteService.revokeInvite(sessionId, token);
    }

    @GetMapping("/api/v1/household/shared-context")
    public CaregiverInviteService.SharedContextResponse fetchSharedContext(
            @RequestHeader("X-Session-Id") String sessionId
    ) {
        return caregiverInviteService.fetchSharedContext(sessionId);
    }

    @GetMapping(value = "/invite/{token}", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> landingPage(
            @PathVariable("token") String token,
            HttpServletRequest request
    ) {
        var response = caregiverInviteService.renderLanding(token, request.getHeader(HttpHeaders.USER_AGENT));
        return htmlResponse(response.status().value(), response.result(), response.failureReason(), response.auditStatus().name(), response.html(), null);
    }

    @GetMapping(value = "/invite/{token}/open-app", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> openApp(
            @PathVariable("token") String token,
            @RequestParam(value = "platform", required = false) String platform,
            HttpServletRequest request
    ) {
        var response = caregiverInviteService.resolveOpenApp(token, platform, request.getHeader(HttpHeaders.USER_AGENT));
        return htmlResponse(response.status().value(), response.result(), response.failureReason(), response.auditStatus().name(), response.html(), response.location());
    }

    @GetMapping(value = "/invite/{token}/download", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> downloadFallback(
            @PathVariable("token") String token,
            @RequestParam(value = "platform", required = false) String platform,
            HttpServletRequest request
    ) {
        var response = caregiverInviteService.resolveDownloadFallback(token, platform, request.getHeader(HttpHeaders.USER_AGENT));
        return htmlResponse(response.status().value(), response.result(), response.failureReason(), response.auditStatus().name(), response.html(), response.location());
    }

    private ResponseEntity<String> htmlResponse(
            int status,
            String result,
            String failureReason,
            String auditStatus,
            String html,
            java.net.URI location
    ) {
        var builder = ResponseEntity.status(status)
                .contentType(HTML_UTF8)
                .header(CaregiverInviteService.RESULT_HEADER, result)
                .header(CaregiverInviteService.AUDIT_HEADER, auditStatus.toLowerCase())
                .header(CaregiverInviteService.FAILURE_REASON_HEADER, failureReason == null ? "" : failureReason);
        if (location != null) {
            builder.location(location);
        }
        return builder.body(html == null ? "" : html);
    }

    public record CreateInviteRequest(@NotBlank String role, @NotBlank String source) {
    }

    public record AcceptInviteRequest(@NotBlank String token, @NotBlank String source) {
    }
}
