package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.CaregiverInviteService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Validated
@RequestMapping("/api/v1")
public class CaregiverInviteController {

    private final CaregiverInviteService caregiverInviteService;

    public CaregiverInviteController(CaregiverInviteService caregiverInviteService) {
        this.caregiverInviteService = caregiverInviteService;
    }

    @PostMapping("/caregiver-invites")
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

    @PostMapping("/caregiver-invites/accept")
    public CaregiverInviteService.AcceptInviteResponse acceptInvite(
            @RequestHeader("X-Session-Id") String sessionId,
            @Valid @RequestBody AcceptInviteRequest request
    ) {
        return caregiverInviteService.acceptInvite(
                sessionId,
                new CaregiverInviteService.AcceptInviteCommand(request.token(), request.source())
        );
    }

    @PostMapping("/caregiver-invites/{token}/revoke")
    public CaregiverInviteService.RevokeInviteResponse revokeInvite(
            @RequestHeader("X-Session-Id") String sessionId,
            @PathVariable("token") String token
    ) {
        return caregiverInviteService.revokeInvite(sessionId, token);
    }

    @GetMapping("/household/shared-context")
    public CaregiverInviteService.SharedContextResponse fetchSharedContext(
            @RequestHeader("X-Session-Id") String sessionId
    ) {
        return caregiverInviteService.fetchSharedContext(sessionId);
    }

    public record CreateInviteRequest(@NotBlank String role, @NotBlank String source) {
    }

    public record AcceptInviteRequest(@NotBlank String token, @NotBlank String source) {
    }
}
