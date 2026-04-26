package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.ShareLandingService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.nio.charset.StandardCharsets;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;

@RestController
@Validated
@RequestMapping
public class ShareLandingController {

    private static final MediaType HTML_UTF8 = new MediaType(MediaType.TEXT_HTML, StandardCharsets.UTF_8);

    private final ShareLandingService shareLandingService;

    public ShareLandingController(ShareLandingService shareLandingService) {
        this.shareLandingService = shareLandingService;
    }

    @PostMapping("/api/v1/share-links")
    @ResponseStatus(HttpStatus.CREATED)
    public ResponseEntity<ShareLandingService.CreateShareLinkResponse> createShareLink(
            @Valid @RequestBody CreateShareLinkRequest request
    ) {
        var response = shareLandingService.createShareLink(new ShareLandingService.CreateShareLinkCommand(
                request.source(),
                request.platformHint(),
                request.headline(),
                request.storyText(),
                request.phraseText(),
                request.phraseTranslation(),
                request.recommendationTitle(),
                request.recommendationReason(),
                request.spaceId(),
                request.activityId(),
                request.childName(),
                request.installationId(),
                request.eventKey(),
                request.fallbackReason()
        ));
        return ResponseEntity.status(HttpStatus.CREATED)
                .header(ShareLandingService.RESULT_HEADER, "create")
                .header(ShareLandingService.AUDIT_HEADER, "recorded")
                .header(ShareLandingService.FAILURE_REASON_HEADER, "")
                .body(response);
    }

    @GetMapping(value = "/share/{token}", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> landingPage(
            @PathVariable("token") String token,
            HttpServletRequest request
    ) {
        var response = shareLandingService.renderLanding(token, request.getHeader(HttpHeaders.USER_AGENT));
        return htmlResponse(response.status().value(), response.result(), response.failureReason(), response.auditStatus().name(), response.html(), null);
    }

    @GetMapping(value = "/share/{token}/open-app", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> openApp(
            @PathVariable("token") String token,
            @RequestParam(value = "platform", required = false) String platform,
            HttpServletRequest request
    ) {
        var response = shareLandingService.resolveOpenApp(token, platform, request.getHeader(HttpHeaders.USER_AGENT));
        return htmlResponse(response.status().value(), response.result(), response.failureReason(), response.auditStatus().name(), response.html(), response.location());
    }

    @GetMapping(value = "/share/{token}/download", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> downloadFallback(
            @PathVariable("token") String token,
            @RequestParam(value = "platform", required = false) String platform,
            HttpServletRequest request
    ) {
        var response = shareLandingService.resolveDownloadFallback(token, platform, request.getHeader(HttpHeaders.USER_AGENT));
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
                .header(ShareLandingService.RESULT_HEADER, result)
                .header(ShareLandingService.AUDIT_HEADER, auditStatus.toLowerCase())
                .header(ShareLandingService.FAILURE_REASON_HEADER, failureReason == null ? "" : failureReason);
        if (location != null) {
            builder.location(location);
        }
        return builder.body(html == null ? "" : html);
    }

    public record CreateShareLinkRequest(
            @NotBlank @Size(max = 32) String source,
            @Size(max = 16) String platformHint,
            @NotBlank @Size(max = 80) String headline,
            @NotBlank @Size(max = 280) String storyText,
            @Size(max = 120) String phraseText,
            @Size(max = 120) String phraseTranslation,
            @Size(max = 120) String recommendationTitle,
            @Size(max = 160) String recommendationReason,
            @Size(max = 64) String spaceId,
            @Size(max = 64) String activityId,
            @Size(max = 80) String childName,
            @Size(max = 64) String installationId,
            @Size(max = 120) String eventKey,
            @Size(max = 120) String fallbackReason
    ) {
    }
}
