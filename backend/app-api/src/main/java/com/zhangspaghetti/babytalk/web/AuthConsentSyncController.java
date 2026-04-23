package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Validated
@RequestMapping("/api/v1")
public class AuthConsentSyncController {

    private final AuthConsentSyncService authConsentSyncService;

    public AuthConsentSyncController(AuthConsentSyncService authConsentSyncService) {
        this.authConsentSyncService = authConsentSyncService;
    }

    @PostMapping("/auth/challenges")
    @ResponseStatus(HttpStatus.CREATED)
    public AuthConsentSyncService.ChallengeResponse createChallenge(@Valid @RequestBody CreateChallengeRequest request) {
        return authConsentSyncService.createChallenge(request.phoneNumber());
    }

    @PostMapping("/auth/verify")
    public AuthConsentSyncService.SessionResponse verifyChallenge(@Valid @RequestBody VerifyChallengeRequest request) {
        return authConsentSyncService.verifyChallenge(
                request.challengeId(),
                request.verificationCode(),
                request.installationId()
        );
    }

    @PostMapping("/auth/refresh")
    public AuthConsentSyncService.SessionResponse refresh(@Valid @RequestBody RefreshTokenRequest request) {
        return authConsentSyncService.refresh(request.refreshToken());
    }

    @PostMapping("/auth/logout")
    public AuthConsentSyncService.LogoutResponse logout(@Valid @RequestBody RefreshTokenRequest request) {
        return authConsentSyncService.logout(request.refreshToken());
    }

    @PostMapping("/consent/accept")
    public AuthConsentSyncService.ConsentResponse acceptConsent(
            @RequestHeader("X-Session-Id") String sessionId,
            @Valid @RequestBody AcceptConsentRequest request
    ) {
        return authConsentSyncService.acceptConsent(sessionId, request.consentVersion());
    }

    @PostMapping("/consent/revoke")
    public AuthConsentSyncService.ConsentResponse revokeConsent(
            @RequestHeader("X-Session-Id") String sessionId,
            @Valid @RequestBody RevokeConsentRequest request
    ) {
        return authConsentSyncService.revokeConsent(sessionId, request.reason());
    }

    @DeleteMapping("/account")
    public AuthConsentSyncService.DeleteResponse deleteAccount(
            @RequestHeader("X-Session-Id") String sessionId,
            @Valid @RequestBody DeleteAccountRequest request
    ) {
        return authConsentSyncService.deleteAccount(sessionId, request.reason());
    }

    @PostMapping("/sync/events")
    public AuthConsentSyncService.SyncBatchResponse ingestEvents(
            @RequestHeader("X-Session-Id") String sessionId,
            @Valid @RequestBody SyncBatchRequest request
    ) {
        var events = request.events().stream()
                .map(event -> new AuthConsentSyncService.SyncEventRequest(
                        event.eventKey(),
                        event.localEventId(),
                        event.installationId(),
                        event.spaceId(),
                        event.activityId(),
                        event.phraseId(),
                        event.reactionType(),
                        event.clientTimestamp()
                ))
                .toList();
        return authConsentSyncService.ingestEvents(sessionId, request.installationId(), events);
    }

    @GetMapping("/bootstrap")
    public AuthConsentSyncService.BootstrapResponse bootstrap(
            @RequestHeader("X-Session-Id") String sessionId,
            @RequestParam("installationId") String installationId
    ) {
        return authConsentSyncService.bootstrap(sessionId, installationId);
    }

    public record CreateChallengeRequest(@NotBlank String phoneNumber) {
    }

    public record VerifyChallengeRequest(
            @NotBlank String challengeId,
            @NotBlank String verificationCode,
            @NotBlank String installationId
    ) {
    }

    public record RefreshTokenRequest(
            @NotBlank(message = "refreshToken 不能为空。")
            @Size(max = 4096, message = "refreshToken 过长。")
            String refreshToken
    ) {
    }

    public record AcceptConsentRequest(@NotBlank String consentVersion) {
    }

    public record RevokeConsentRequest(String reason) {
    }

    public record DeleteAccountRequest(String reason) {
    }

    public record SyncBatchRequest(
            @NotBlank String installationId,
            @NotEmpty List<@Valid SyncEventPayload> events
    ) {
    }

    public record SyncEventPayload(
            @NotBlank String eventKey,
            @NotBlank String localEventId,
            @NotBlank String installationId,
            @NotBlank String spaceId,
            @NotBlank String activityId,
            @NotBlank String phraseId,
            @NotBlank String reactionType,
            Instant clientTimestamp
    ) {
    }
}
