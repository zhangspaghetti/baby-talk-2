package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.DistributionService;
import jakarta.servlet.http.HttpServletRequest;
import java.nio.charset.StandardCharsets;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

@Controller
public class DistributionController {

    private static final MediaType HTML_UTF8 = new MediaType(MediaType.TEXT_HTML, StandardCharsets.UTF_8);

    private final DistributionService distributionService;

    public DistributionController(DistributionService distributionService) {
        this.distributionService = distributionService;
    }

    @GetMapping(value = "/download", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> downloadPage(
            @RequestParam(value = "channel", required = false) String channel,
            @RequestParam(value = "source", required = false) String source,
            @RequestParam(value = "platform", required = false) String platform,
            HttpServletRequest request
    ) {
        var response = distributionService.renderDownloadPage(channel, source, platform, request.getHeader(HttpHeaders.USER_AGENT));
        return htmlResponse(response.status().value(), response.result(), response.auditStatus().name(), response.html(), null);
    }

    @GetMapping(value = "/upgrade", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> upgradePage(
            @RequestParam(value = "channel", required = false) String channel,
            @RequestParam(value = "source", required = false) String source,
            @RequestParam(value = "platform", required = false) String platform,
            HttpServletRequest request
    ) {
        var response = distributionService.renderUpgradePage(channel, source, platform, request.getHeader(HttpHeaders.USER_AGENT));
        return htmlResponse(response.status().value(), response.result(), response.auditStatus().name(), response.html(), null);
    }

    @GetMapping(value = "/download/redirect", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> downloadRedirect(
            @RequestParam(value = "channel", required = false) String channel,
            @RequestParam(value = "source", required = false) String source,
            @RequestParam(value = "platform", required = false) String platform
    ) {
        var response = distributionService.resolveDownloadRedirect(channel, source, platform);
        return htmlResponse(response.status().value(), response.result(), response.auditStatus().name(), response.html(), response.location());
    }

    @GetMapping(value = "/upgrade/redirect", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> upgradeRedirect(
            @RequestParam(value = "channel", required = false) String channel,
            @RequestParam(value = "source", required = false) String source,
            @RequestParam(value = "platform", required = false) String platform
    ) {
        var response = distributionService.resolveUpgradeRedirect(channel, source, platform);
        return htmlResponse(response.status().value(), response.result(), response.auditStatus().name(), response.html(), response.location());
    }

    private ResponseEntity<String> htmlResponse(
            int status,
            String result,
            String auditStatus,
            String html,
            java.net.URI location
    ) {
        var builder = ResponseEntity.status(status)
                .contentType(HTML_UTF8)
                .header(DistributionService.RESULT_HEADER, result)
                .header(DistributionService.AUDIT_HEADER, auditStatus.toLowerCase());
        if (location != null) {
            builder.location(location);
        }
        return builder.body(html == null ? "" : html);
    }
}
