package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.DistributionProperties;
import java.net.URI;
import java.time.Clock;
import java.time.Instant;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.util.HtmlUtils;
import org.springframework.web.util.UriComponentsBuilder;

@Service
public class DistributionService {

    public static final String RESULT_HEADER = "X-Release-Distribution-Result";
    public static final String AUDIT_HEADER = "X-Release-Distribution-Audit";

    private static final MediaPalette PALETTE = new MediaPalette(
            "#FFF8F0",
            "#FFFFFF",
            "#FF8C42",
            "#E67A30",
            "#2D2926",
            "#6B5E57",
            "#D94B3C",
            "#3B8577"
    );

    private final DistributionProperties properties;
    private final DistributionRepository repository;
    private final Clock clock = Clock.systemUTC();

    public DistributionService(DistributionProperties properties, DistributionRepository repository) {
        this.properties = properties;
        this.repository = repository;
    }

    public PageResponse renderDownloadPage(String channel, String source, String platform, String userAgent) {
        return renderPage(RouteKind.DOWNLOAD, channel, source, platform, userAgent);
    }

    public PageResponse renderUpgradePage(String channel, String source, String platform, String userAgent) {
        return renderPage(RouteKind.UPGRADE, channel, source, platform, userAgent);
    }

    public RedirectResponse resolveDownloadRedirect(String channel, String source, String platform) {
        return resolveRedirect(RouteKind.DOWNLOAD, channel, source, platform);
    }

    public RedirectResponse resolveUpgradeRedirect(String channel, String source, String platform) {
        return resolveRedirect(RouteKind.UPGRADE, channel, source, platform);
    }

    private PageResponse renderPage(RouteKind routeKind, String rawChannel, String rawSource, String rawPlatform, String userAgent) {
        var request = normalize(routeKind, rawChannel, rawSource, rawPlatform, userAgent);
        if (request.error() != null) {
            var auditStatus = recordAudit(request, request.error().result(), request.error().failureReason());
            return new PageResponse(
                    HttpStatus.BAD_REQUEST,
                    request.error().result(),
                    auditStatus,
                    renderPageHtml(routeKind, request, Map.of(), request.error().message(), true, false, request.error().failureReason())
            );
        }

        var targets = request.availableTargets();
        if (targets.isEmpty()) {
            var failureReason = "channel_unconfigured";
            var auditStatus = recordAudit(request, "unavailable", failureReason);
            return new PageResponse(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "unavailable",
                    auditStatus,
                    renderPageHtml(routeKind, request, targets, "当前渠道暂未提供可用安装入口。", false, true, failureReason)
            );
        }

        var preferredPlatform = request.preferredPlatform();
        var preferredMissing = preferredPlatform != null && !targets.containsKey(preferredPlatform);
        var result = preferredMissing ? "unavailable" : "page_view";
        var failureReason = preferredMissing ? "platform_target_missing" : null;
        var message = preferredMissing
                ? "当前渠道暂未提供该平台入口，请改用下方其它可用平台。"
                : routeKind.heroDescription();
        var auditStatus = recordAudit(request, result, failureReason);
        return new PageResponse(
                HttpStatus.OK,
                result,
                auditStatus,
                renderPageHtml(routeKind, request, targets, message, false, preferredMissing, failureReason)
        );
    }

    private RedirectResponse resolveRedirect(RouteKind routeKind, String rawChannel, String rawSource, String rawPlatform) {
        var request = normalize(routeKind, rawChannel, rawSource, rawPlatform, null);
        if (request.error() != null) {
            var auditStatus = recordAudit(request, request.error().result(), request.error().failureReason());
            return RedirectResponse.error(
                    HttpStatus.BAD_REQUEST,
                    request.error().result(),
                    auditStatus,
                    renderRedirectErrorHtml(routeKind, request.error().message(), request.error().failureReason())
            );
        }

        if (request.requestedPlatform() == null) {
            var auditStatus = recordAudit(request, "invalid_platform", "platform_required");
            return RedirectResponse.error(
                    HttpStatus.BAD_REQUEST,
                    "invalid_platform",
                    auditStatus,
                    renderRedirectErrorHtml(routeKind, "缺少 platform 参数，无法决定跳转目标。", "platform_required")
            );
        }

        var targetUrl = request.availableTargets().get(request.requestedPlatform());
        if (targetUrl == null || targetUrl.isBlank()) {
            var auditStatus = recordAudit(request, "unavailable", "platform_target_missing");
            return RedirectResponse.error(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "unavailable",
                    auditStatus,
                    renderRedirectErrorHtml(routeKind, "当前渠道暂未提供该平台入口，请返回下载页查看其它可用平台。", "platform_target_missing")
            );
        }

        var auditStatus = recordAudit(request, "redirect", null);
        return RedirectResponse.redirect("redirect", auditStatus, URI.create(targetUrl));
    }

    private AuditStatus recordAudit(NormalizedRequest request, String result, String failureReason) {
        try {
            repository.insertEvent(
                    new DistributionRepository.EventRow(
                            request.routeKind().slug(),
                            request.channel(),
                            request.source(),
                            request.auditPlatform(),
                            result,
                            failureReason,
                            Instant.now(clock)
                    )
            );
            return AuditStatus.RECORDED;
        } catch (DataAccessException exception) {
            return AuditStatus.FAILED;
        }
    }

    private NormalizedRequest normalize(
            RouteKind routeKind,
            String rawChannel,
            String rawSource,
            String rawPlatform,
            String userAgent
    ) {
        var defaultSource = defaultSource(routeKind);
        var channel = normalizeOrDefault(rawChannel, properties.defaultChannel());
        if (channel == null) {
            return NormalizedRequest.error(routeKind, properties.defaultChannel(), defaultSource, null, null,
                    ValidationError.invalidChannel("缺少 channel 参数。", "channel_blank"));
        }
        var channelConfig = properties.channels().get(channel);
        if (channelConfig == null) {
            return NormalizedRequest.error(routeKind, channel, defaultSource, null, null,
                    ValidationError.invalidChannel("当前分发链接使用了未知 channel。", "unknown_channel"));
        }

        var source = normalizeOrDefault(rawSource, defaultSource);
        if (source == null) {
            return NormalizedRequest.error(routeKind, channel, defaultSource, null, channelConfig,
                    ValidationError.invalidSource("缺少 source 参数。", "source_blank"));
        }
        if (!properties.allowedSources().contains(source)) {
            return NormalizedRequest.error(routeKind, channel, source, null, channelConfig,
                    ValidationError.invalidSource("当前分发链接使用了未知 source。", "unknown_source"));
        }

        String requestedPlatform = null;
        if (rawPlatform != null) {
            requestedPlatform = normalizeKey(rawPlatform);
            if (requestedPlatform == null) {
                return NormalizedRequest.error(routeKind, channel, source, null, channelConfig,
                        ValidationError.invalidPlatform("platform 参数不能为空。", "platform_blank"));
            }
            if (!configuredPlatforms().contains(requestedPlatform)) {
                return NormalizedRequest.error(routeKind, channel, source, requestedPlatform, channelConfig,
                        ValidationError.invalidPlatform("当前分发链接使用了未知 platform。", "unknown_platform"));
            }
        }

        var preferredPlatform = requestedPlatform != null ? requestedPlatform : detectPlatform(userAgent);
        return new NormalizedRequest(
                routeKind,
                channel,
                source,
                requestedPlatform,
                preferredPlatform,
                availableTargets(channelConfig),
                null
        );
    }

    private Map<String, String> availableTargets(DistributionProperties.ChannelProperties channelProperties) {
        var normalized = new LinkedHashMap<String, String>();
        channelProperties.platforms().entrySet().stream()
                .sorted((left, right) -> comparePlatforms(normalizeKey(left.getKey()), normalizeKey(right.getKey())))
                .forEach(entry -> {
                    var platform = normalizeKey(entry.getKey());
                    if (platform == null || entry.getValue() == null || entry.getValue().isBlank()) {
                        return;
                    }
                    normalized.put(platform, entry.getValue().trim());
                });
        return normalized;
    }

    private Set<String> configuredPlatforms() {
        return properties.channels().values().stream()
                .flatMap(channel -> channel.platforms().keySet().stream())
                .map(this::normalizeKey)
                .filter(value -> value != null && !value.isBlank())
                .collect(java.util.stream.Collectors.toSet());
    }

    private int comparePlatforms(String left, String right) {
        var leftOrder = platformOrder(left);
        var rightOrder = platformOrder(right);
        if (leftOrder != rightOrder) {
            return Integer.compare(leftOrder, rightOrder);
        }
        if (left == null) {
            return right == null ? 0 : 1;
        }
        if (right == null) {
            return -1;
        }
        return left.compareTo(right);
    }

    private int platformOrder(String platform) {
        if (platform == null) {
            return Integer.MAX_VALUE;
        }
        return switch (platform) {
            case "android" -> 0;
            case "ios" -> 1;
            default -> 9;
        };
    }

    private String defaultSource(RouteKind routeKind) {
        return routeKind == RouteKind.DOWNLOAD
                ? properties.downloadDefaultSource()
                : properties.upgradeDefaultSource();
    }

    private String normalizeOrDefault(String rawValue, String defaultValue) {
        if (rawValue == null) {
            return defaultValue;
        }
        return normalizeKey(rawValue);
    }

    private String normalizeKey(String rawValue) {
        if (rawValue == null || rawValue.isBlank()) {
            return null;
        }
        return rawValue.trim().toLowerCase(Locale.ROOT).replace('-', '_');
    }

    private String detectPlatform(String userAgent) {
        if (userAgent == null || userAgent.isBlank()) {
            return null;
        }
        var normalized = userAgent.toLowerCase(Locale.ROOT);
        if (normalized.contains("android")) {
            return "android";
        }
        if (normalized.contains("iphone") || normalized.contains("ipad") || normalized.contains("ios")) {
            return "ios";
        }
        return null;
    }

    private String renderPageHtml(
            RouteKind routeKind,
            NormalizedRequest request,
            Map<String, String> targets,
            String summary,
            boolean invalid,
            boolean unavailable,
            String failureReason
    ) {
        var heroTitle = invalid ? "分发链接无效" : routeKind.heroTitle();
        var ctas = new StringBuilder();
        for (var entry : targets.entrySet()) {
            var platform = entry.getKey();
            var href = UriComponentsBuilder.fromPath(routeKind.redirectPath())
                    .queryParam("channel", request.channel())
                    .queryParam("source", request.source())
                    .queryParam("platform", platform)
                    .build()
                    .toUriString();
            var recommended = platform.equals(request.preferredPlatform());
            ctas.append("""
                    <li class=\"cta-item\">
                      <a class=\"cta-link\" href=\"%s\">%s%s</a>
                    </li>
                    """.formatted(
                    HtmlUtils.htmlEscape(href),
                    HtmlUtils.htmlEscape(platformLabel(platform)),
                    recommended ? " · 推荐" : ""
            ));
        }

        var alertClass = invalid ? "alert error" : unavailable ? "alert warning" : "alert info";
        var auditBanner = request.error() == null && request.routeKind() != null ? "" : "";
        var auditNotice = "";
        return """
                <!doctype html>
                <html lang=\"zh-CN\">
                <head>
                  <meta charset=\"utf-8\" />
                  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
                  <meta name=\"release-distribution-route\" content=\"%s\" />
                  <meta name=\"release-distribution-result\" content=\"%s\" />
                  <meta name=\"release-distribution-failure-reason\" content=\"%s\" />
                  <title>%s</title>
                  <style>
                    :root {
                      color-scheme: light;
                      --bg-base: %s;
                      --bg-surface: %s;
                      --accent: %s;
                      --accent-dark: %s;
                      --text-primary: %s;
                      --text-secondary: %s;
                      --error: %s;
                      --info: %s;
                    }
                    * { box-sizing: border-box; }
                    body {
                      margin: 0;
                      font-family: "PingFang SC", "Noto Sans SC", "Microsoft YaHei", sans-serif;
                      background: var(--bg-base);
                      color: var(--text-primary);
                    }
                    main {
                      max-width: 720px;
                      margin: 0 auto;
                      padding: 32px 20px 56px;
                    }
                    .surface {
                      background: var(--bg-surface);
                      border-radius: 24px;
                      padding: 28px 24px;
                      box-shadow: 0 8px 24px rgba(45,41,38,0.12);
                    }
                    h1 { margin: 0 0 12px; font-size: 30px; line-height: 1.2; }
                    p { margin: 0; line-height: 1.7; color: var(--text-secondary); }
                    .meta {
                      margin-top: 20px;
                      display: flex;
                      flex-wrap: wrap;
                      gap: 8px;
                    }
                    .meta span {
                      padding: 6px 10px;
                      border-radius: 9999px;
                      background: #FFF0E5;
                      color: var(--accent-dark);
                      font-size: 13px;
                    }
                    .alert {
                      margin-top: 20px;
                      border-radius: 16px;
                      padding: 14px 16px;
                      font-size: 14px;
                    }
                    .alert.info { background: rgba(59,133,119,0.12); color: var(--info); }
                    .alert.warning { background: rgba(230,168,23,0.14); color: #8A5A00; }
                    .alert.error { background: rgba(217,75,60,0.12); color: var(--error); }
                    .cta-list {
                      list-style: none;
                      margin: 24px 0 0;
                      padding: 0;
                      display: grid;
                      gap: 12px;
                    }
                    .cta-link {
                      display: block;
                      text-decoration: none;
                      background: var(--accent);
                      color: white;
                      padding: 15px 18px;
                      border-radius: 16px;
                      font-weight: 700;
                    }
                    .cta-link:hover { background: var(--accent-dark); }
                    .footnote { margin-top: 18px; font-size: 13px; }
                    .audit-warning {
                      margin-top: 16px;
                      padding: 12px 14px;
                      border-radius: 14px;
                      background: rgba(217,75,60,0.10);
                      color: var(--error);
                      font-size: 13px;
                    }
                  </style>
                </head>
                <body>
                  <main data-route=\"%s\" data-result=\"%s\" data-failure-reason=\"%s\">
                    <section class=\"surface\">
                      <h1>%s</h1>
                      <p>%s</p>
                      <div class=\"meta\">
                        <span>channel · %s</span>
                        <span>source · %s</span>
                        <span>入口 · %s</span>
                      </div>
                      <div class=\"%s\">%s</div>
                      <ul class=\"cta-list\">%s</ul>
                      %s
                      <p class=\"footnote\">如果当前平台没有可用入口，请联系发布同学确认 channel/source 配置是否已补齐。</p>
                    </section>
                  </main>
                </body>
                </html>
                """.formatted(
                routeKind.slug(),
                invalid ? "invalid" : unavailable ? "unavailable" : "page_view",
                HtmlUtils.htmlEscape(failureReason == null ? "" : failureReason),
                HtmlUtils.htmlEscape(heroTitle),
                PALETTE.bgBase(),
                PALETTE.bgSurface(),
                PALETTE.accent(),
                PALETTE.accentDark(),
                PALETTE.textPrimary(),
                PALETTE.textSecondary(),
                PALETTE.error(),
                PALETTE.info(),
                routeKind.slug(),
                invalid ? "invalid" : unavailable ? "unavailable" : "page_view",
                HtmlUtils.htmlEscape(failureReason == null ? "" : failureReason),
                HtmlUtils.htmlEscape(heroTitle),
                HtmlUtils.htmlEscape(summary),
                HtmlUtils.htmlEscape(request.channel()),
                HtmlUtils.htmlEscape(request.source()),
                HtmlUtils.htmlEscape(routeKind.slug()),
                alertClass,
                HtmlUtils.htmlEscape(summary),
                ctas,
                auditNotice + auditBanner
        );
    }

    private String renderRedirectErrorHtml(RouteKind routeKind, String message, String failureReason) {
        return """
                <!doctype html>
                <html lang=\"zh-CN\">
                <head>
                  <meta charset=\"utf-8\" />
                  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
                  <meta name=\"release-distribution-result\" content=\"error\" />
                  <meta name=\"release-distribution-failure-reason\" content=\"%s\" />
                  <title>跳转失败</title>
                </head>
                <body style=\"font-family: PingFang SC, Microsoft YaHei, sans-serif; background: %s; color: %s; padding: 32px;\">
                  <main style=\"max-width: 560px; margin: 0 auto; background: %s; border-radius: 24px; padding: 24px;\">
                    <h1 style=\"margin-top: 0;\">无法继续跳转</h1>
                    <p style=\"line-height: 1.7; color: %s;\">%s</p>
                    <p style=\"margin-top: 16px;\"><a href=\"%s\" style=\"color: %s;\">返回 %s 页面</a></p>
                  </main>
                </body>
                </html>
                """.formatted(
                HtmlUtils.htmlEscape(failureReason == null ? "" : failureReason),
                PALETTE.bgBase(),
                PALETTE.textPrimary(),
                PALETTE.bgSurface(),
                PALETTE.textSecondary(),
                HtmlUtils.htmlEscape(message),
                HtmlUtils.htmlEscape(routeKind.pagePath()),
                PALETTE.accentDark(),
                routeKind.slug()
        );
    }

    private String platformLabel(String platform) {
        return switch (platform) {
            case "android" -> "Android 下载";
            case "ios" -> "iPhone / iPad 安装";
            default -> platform;
        };
    }

    public record PageResponse(
            HttpStatus status,
            String result,
            AuditStatus auditStatus,
            String html
    ) {
    }

    public record RedirectResponse(
            HttpStatus status,
            String result,
            AuditStatus auditStatus,
            URI location,
            String html
    ) {
        public static RedirectResponse redirect(String result, AuditStatus auditStatus, URI location) {
            return new RedirectResponse(HttpStatus.FOUND, result, auditStatus, location, "");
        }

        public static RedirectResponse error(HttpStatus status, String result, AuditStatus auditStatus, String html) {
            return new RedirectResponse(status, result, auditStatus, null, html);
        }
    }

    public enum AuditStatus {
        RECORDED,
        FAILED
    }

    private enum RouteKind {
        DOWNLOAD("download", "/download", "/download/redirect", "下载 Baby Talk", "选择你的设备，即可进入正式下载入口。"),
        UPGRADE("upgrade", "/upgrade", "/upgrade/redirect", "升级 Baby Talk", "你的版本需要更新后才能继续使用，请选择可用平台继续升级。");

        private final String slug;
        private final String pagePath;
        private final String redirectPath;
        private final String heroTitle;
        private final String heroDescription;

        RouteKind(String slug, String pagePath, String redirectPath, String heroTitle, String heroDescription) {
            this.slug = slug;
            this.pagePath = pagePath;
            this.redirectPath = redirectPath;
            this.heroTitle = heroTitle;
            this.heroDescription = heroDescription;
        }

        public String slug() {
            return slug;
        }

        public String pagePath() {
            return pagePath;
        }

        public String redirectPath() {
            return redirectPath;
        }

        public String heroTitle() {
            return heroTitle;
        }

        public String heroDescription() {
            return heroDescription;
        }

        public String defaultSource() {
            return this == DOWNLOAD ? "public_link" : "version_gate";
        }
    }

    private record NormalizedRequest(
            RouteKind routeKind,
            String channel,
            String source,
            String requestedPlatform,
            String preferredPlatform,
            Map<String, String> availableTargets,
            ValidationError error
    ) {
        static NormalizedRequest error(
                RouteKind routeKind,
                String channel,
                String source,
                String requestedPlatform,
                DistributionProperties.ChannelProperties channelProperties,
                ValidationError error
        ) {
            return new NormalizedRequest(
                    routeKind,
                    channel,
                    source,
                    requestedPlatform,
                    requestedPlatform,
                    channelProperties == null ? Map.of() : Map.copyOf(channelProperties.platforms()),
                    error
            );
        }

        String auditPlatform() {
            return requestedPlatform != null ? requestedPlatform : preferredPlatform;
        }
    }

    private record ValidationError(String result, String message, String failureReason) {
        static ValidationError invalidChannel(String message, String failureReason) {
            return new ValidationError("invalid_channel", message, failureReason);
        }

        static ValidationError invalidSource(String message, String failureReason) {
            return new ValidationError("invalid_source", message, failureReason);
        }

        static ValidationError invalidPlatform(String message, String failureReason) {
            return new ValidationError("invalid_platform", message, failureReason);
        }
    }

    private record MediaPalette(
            String bgBase,
            String bgSurface,
            String accent,
            String accentDark,
            String textPrimary,
            String textSecondary,
            String error,
            String info
    ) {
    }
}
