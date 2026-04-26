package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.ShareLandingProperties;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.util.HtmlUtils;
import org.springframework.web.util.UriComponentsBuilder;

@Service
public class ShareLandingService {

    public static final String RESULT_HEADER = "X-Share-Landing-Result";
    public static final String AUDIT_HEADER = "X-Share-Landing-Audit";
    public static final String FAILURE_REASON_HEADER = "X-Share-Landing-Failure-Reason";

    private static final Pattern TOKEN_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{8,64}$");
    private static final Set<String> ALLOWED_PLATFORMS = Set.of("android", "ios");
    private static final MediaPalette PALETTE = new MediaPalette(
            "#FFF8F0",
            "#FFFFFF",
            "#F5F0EB",
            "#FFF0E5",
            "#FF8C42",
            "#E67A30",
            "#2D2926",
            "#6B5E57",
            "#D94B3C",
            "#3B8577"
    );

    private final ShareLandingProperties properties;
    private final ShareLandingRepository repository;
    private final SecureRandom secureRandom = new SecureRandom();
    private final Clock clock = Clock.systemUTC();

    public ShareLandingService(ShareLandingProperties properties, ShareLandingRepository repository) {
        this.properties = properties;
        this.repository = repository;
    }

    @Transactional
    public CreateShareLinkResponse createShareLink(CreateShareLinkCommand command) {
        var source = normalizeRequired(command.source(), "source", "invalid_share_source", "source 不能为空。", properties.allowedSources());
        var platformHint = normalizeKey(command.platformHint());
        if (platformHint != null && !ALLOWED_PLATFORMS.contains(platformHint)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_share_platform", "platformHint 非法。", Map.of("platformHint", platformHint));
        }
        rejectSensitiveField("childName", command.childName());
        rejectSensitiveField("installationId", command.installationId());
        rejectSensitiveField("eventKey", command.eventKey());
        rejectSensitiveField("fallbackReason", command.fallbackReason());

        var headline = requireTrimmed(command.headline(), "headline", "missing_headline", "headline 不能为空。");
        var storyText = requireTrimmed(command.storyText(), "storyText", "missing_story_text", "storyText 不能为空。");
        var phraseText = trimToNull(command.phraseText());
        var phraseTranslation = trimToNull(command.phraseTranslation());
        var recommendationTitle = trimToNull(command.recommendationTitle());
        var recommendationReason = trimToNull(command.recommendationReason());
        var spaceId = trimToNull(command.spaceId());
        var activityId = trimToNull(command.activityId());

        if (phraseText == null && recommendationTitle == null) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_share_payload",
                    "分享内容至少需要包含 latestImpact 或 continuity recommendation 的脱敏摘要。",
                    Map.of("required", List.of("phraseText", "recommendationTitle"))
            );
        }

        var now = Instant.now(clock);
        var token = generateToken();
        var expiresAt = now.plus(properties.defaultLinkTtl());
        var shareCard = new ShareLandingRepository.ShareCardRow(
                token,
                source,
                headline,
                storyText,
                phraseText,
                phraseTranslation,
                recommendationTitle,
                recommendationReason,
                spaceId,
                activityId,
                platformHint,
                now,
                expiresAt
        );
        try {
            repository.insertShareCard(shareCard);
            repository.insertEvent(new ShareLandingRepository.EventRow(
                    token,
                    source,
                    "create",
                    platformHint,
                    "create",
                    null,
                    now
            ));
        } catch (DataAccessException exception) {
            throw new ContractException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "share_storage_unavailable",
                    "分享链接暂时无法创建，请稍后重试。",
                    Map.of("retryable", true)
            );
        }

        return new CreateShareLinkResponse(token, publicShareUrl(token), expiresAt);
    }

    public PageResponse renderLanding(String rawToken, String userAgent) {
        var preferredPlatform = detectPlatform(userAgent);
        var resolution = resolveShare(rawToken, "landing", preferredPlatform);
        if (resolution.mode() != ResolutionMode.ACTIVE) {
            return resolution.toPageResponse(renderLandingHtml(resolution, preferredPlatform, Map.of(), null));
        }

        var openAppTargets = availableOpenAppTargets();
        var result = openAppTargets.isEmpty() ? "unavailable" : "page_view";
        var failureReason = openAppTargets.isEmpty() ? "open_app_unconfigured" : null;
        var auditStatus = recordAudit(resolution.snapshot(), "landing", preferredPlatform, result, failureReason);
        return new PageResponse(
                result.equals("page_view") ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE,
                result,
                failureReason,
                auditStatus,
                renderLandingHtml(resolution, preferredPlatform, openAppTargets, failureReason)
        );
    }

    public RedirectResponse resolveOpenApp(String rawToken, String rawPlatform, String userAgent) {
        var requestedPlatform = normalizeKey(rawPlatform);
        if (requestedPlatform != null && !ALLOWED_PLATFORMS.contains(requestedPlatform)) {
            return invalidRoute(rawToken, "open_app", requestedPlatform, "unknown_platform", "当前平台参数无效，无法继续打开 app。", "/share/%s".formatted(safeToken(rawToken)));
        }
        var preferredPlatform = requestedPlatform != null ? requestedPlatform : detectPlatform(userAgent);
        var resolution = resolveShare(rawToken, "open_app", preferredPlatform);
        if (resolution.mode() != ResolutionMode.ACTIVE) {
            return resolution.toRedirectError(renderRedirectErrorHtml(
                    resolution,
                    preferredPlatform,
                    "无法继续打开 app，请先返回分享页确认链接状态。",
                    "/share/%s".formatted(HtmlUtils.htmlEscape(safeToken(rawToken)))
            ));
        }

        var platform = requestedPlatform != null
                ? requestedPlatform
                : preferredPlatform != null ? preferredPlatform : resolution.snapshot().platformHint();
        if (platform == null) {
            var auditStatus = recordAudit(resolution.snapshot(), "open_app", null, "unavailable", "platform_unresolved");
            return RedirectResponse.error(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "unavailable",
                    "platform_unresolved",
                    auditStatus,
                    renderRedirectErrorHtml(
                            resolution,
                            null,
                            "暂时无法判断设备平台，请返回分享页或直接进入下载页。",
                            downloadFallbackRoute(resolution.snapshot().token(), null)
                    )
            );
        }

        var target = availableOpenAppTargets().get(platform);
        if (target == null || target.isBlank()) {
            var auditStatus = recordAudit(resolution.snapshot(), "open_app", platform, "unavailable", "platform_target_missing");
            return RedirectResponse.error(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "unavailable",
                    "platform_target_missing",
                    auditStatus,
                    renderRedirectErrorHtml(
                            resolution,
                            platform,
                            "当前平台暂未配置安全的打开 app 入口，请先进入下载页。",
                            downloadFallbackRoute(resolution.snapshot().token(), platform)
                    )
            );
        }

        var location = UriComponentsBuilder.fromUriString(target)
                .queryParam("token", resolution.snapshot().token())
                .queryParamIfPresent("spaceId", optionalValue(resolution.snapshot().spaceId()))
                .queryParamIfPresent("activityId", optionalValue(resolution.snapshot().activityId()))
                .build(true)
                .toUri();
        var auditStatus = recordAudit(resolution.snapshot(), "open_app", platform, "open_app_redirect", null);
        return RedirectResponse.redirect("open_app_redirect", null, auditStatus, location);
    }

    public RedirectResponse resolveDownloadFallback(String rawToken, String rawPlatform, String userAgent) {
        var requestedPlatform = normalizeKey(rawPlatform);
        if (requestedPlatform != null && !ALLOWED_PLATFORMS.contains(requestedPlatform)) {
            return invalidRoute(rawToken, "download", requestedPlatform, "unknown_platform", "当前平台参数无效，无法继续前往下载页。", "/share/%s".formatted(safeToken(rawToken)));
        }
        var preferredPlatform = requestedPlatform != null ? requestedPlatform : detectPlatform(userAgent);
        var resolution = resolveShare(rawToken, "download", preferredPlatform);
        if (resolution.mode() != ResolutionMode.ACTIVE) {
            return resolution.toRedirectError(renderRedirectErrorHtml(
                    resolution,
                    preferredPlatform,
                    "当前分享链接不可继续回流，请返回下载页获取最新版本。",
                    directDownloadFallback(preferredPlatform)
            ));
        }

        if (properties.downloadFallbackPath() == null || properties.downloadFallbackPath().isBlank()) {
            var auditStatus = recordAudit(resolution.snapshot(), "download", preferredPlatform, "unavailable", "download_fallback_unconfigured");
            return RedirectResponse.error(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "unavailable",
                    "download_fallback_unconfigured",
                    auditStatus,
                    renderRedirectErrorHtml(
                            resolution,
                            preferredPlatform,
                            "下载回流入口暂不可用，请稍后再试。",
                            "/share/%s".formatted(resolution.snapshot().token())
                    )
            );
        }

        var auditStatus = recordAudit(resolution.snapshot(), "download", preferredPlatform, "download_fallback", null);
        return RedirectResponse.redirect("download_fallback", null, auditStatus, URI.create(directDownloadFallback(preferredPlatform)));
    }

    private RedirectResponse invalidRoute(
            String rawToken,
            String entrypoint,
            String platform,
            String failureReason,
            String message,
            String fallbackHref
    ) {
        var auditStatus = recordAudit(new ShareLandingRepository.ShareCardRow(
                safeToken(rawToken),
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                Instant.now(clock),
                Instant.now(clock)
        ), entrypoint, platform, "invalid", failureReason);
        var resolution = ShareResolution.invalid(safeToken(rawToken), failureReason, HttpStatus.BAD_REQUEST);
        return RedirectResponse.error(
                HttpStatus.BAD_REQUEST,
                "invalid",
                failureReason,
                auditStatus,
                renderRedirectErrorHtml(resolution, platform, message, fallbackHref)
        );
    }

    private ShareResolution resolveShare(String rawToken, String entrypoint, String platform) {
        var token = trimToNull(rawToken);
        if (token == null) {
            var auditStatus = recordAudit(null, entrypoint, platform, "invalid", "token_blank");
            return ShareResolution.invalid(safeToken(rawToken), "token_blank", auditStatus, HttpStatus.BAD_REQUEST);
        }
        if (!TOKEN_PATTERN.matcher(token).matches()) {
            var auditStatus = recordAudit(null, entrypoint, platform, "invalid", "token_malformed");
            return ShareResolution.invalid(token, "token_malformed", auditStatus, HttpStatus.BAD_REQUEST);
        }

        final ShareLandingRepository.ShareCardRow snapshot;
        try {
            snapshot = repository.findByToken(token).orElse(null);
        } catch (DataAccessException exception) {
            return ShareResolution.unavailable(token, "storage_unavailable", AuditStatus.FAILED, HttpStatus.SERVICE_UNAVAILABLE);
        }
        if (snapshot == null) {
            var auditStatus = recordAudit(null, entrypoint, platform, "invalid", "token_not_found", token, null);
            return ShareResolution.invalid(token, "token_not_found", auditStatus, HttpStatus.NOT_FOUND);
        }
        if (snapshot.expiresAt().isBefore(Instant.now(clock))) {
            var auditStatus = recordAudit(snapshot, entrypoint, platform, "expired", "token_expired");
            return ShareResolution.expired(snapshot, "token_expired", auditStatus, HttpStatus.GONE);
        }
        return ShareResolution.active(snapshot);
    }

    private AuditStatus recordAudit(ShareLandingRepository.ShareCardRow snapshot, String entrypoint, String platform, String result, String failureReason) {
        return recordAudit(snapshot, entrypoint, platform, result, failureReason, snapshot == null ? null : snapshot.token(), snapshot == null ? null : snapshot.source());
    }

    private AuditStatus recordAudit(
            ShareLandingRepository.ShareCardRow snapshot,
            String entrypoint,
            String platform,
            String result,
            String failureReason,
            String token,
            String source
    ) {
        try {
            repository.insertEvent(new ShareLandingRepository.EventRow(
                    token == null ? "unknown" : token,
                    source,
                    entrypoint,
                    platform,
                    result,
                    failureReason,
                    Instant.now(clock)
            ));
            return AuditStatus.RECORDED;
        } catch (DataAccessException exception) {
            return AuditStatus.FAILED;
        }
    }

    private String renderLandingHtml(
            ShareResolution resolution,
            String preferredPlatform,
            Map<String, String> openAppTargets,
            String failureReason
    ) {
        var snapshot = resolution.snapshot();
        var title = switch (resolution.mode()) {
            case ACTIVE -> snapshot.headline();
            case INVALID -> "分享链接不可用";
            case EXPIRED -> "这份成长分享已过期";
            case UNAVAILABLE -> "分享暂时不可用";
        };
        var summary = switch (resolution.mode()) {
            case ACTIVE -> snapshot.storyText();
            case INVALID -> "这个分享链接无效，可能已经被改写或复制不完整。";
            case EXPIRED -> "这份成长分享已超过有效期，请让家长重新生成新的分享卡片。";
            case UNAVAILABLE -> "分享页暂时不可访问，请稍后重试或直接进入下载页。";
        };
        var ogDescription = resolution.mode() == ResolutionMode.ACTIVE
                ? buildOgDescription(snapshot)
                : summary;
        var pageResult = switch (resolution.mode()) {
            case ACTIVE -> failureReason == null ? "page_view" : "unavailable";
            case INVALID -> "invalid";
            case EXPIRED -> "expired";
            case UNAVAILABLE -> "unavailable";
        };
        var pageFailureReason = resolution.mode() == ResolutionMode.ACTIVE ? failureReason : resolution.failureReason();

        var platformButtons = new StringBuilder();
        if (resolution.mode() == ResolutionMode.ACTIVE) {
            for (var entry : orderTargets(openAppTargets).entrySet()) {
                var platform = entry.getKey();
                var href = UriComponentsBuilder.fromPath("/share/{token}/open-app")
                        .queryParam("platform", platform)
                        .buildAndExpand(snapshot.token())
                        .toUriString();
                platformButtons.append("""
                        <a class=\"cta-link\" href=\"%s\">打开 app · %s%s</a>
                        """.formatted(
                        HtmlUtils.htmlEscape(href),
                        HtmlUtils.htmlEscape(platformLabel(platform)),
                        platform.equals(preferredPlatform) ? " · 推荐" : ""
                ));
            }
        }
        var fallbackHref = resolution.mode() == ResolutionMode.ACTIVE
                ? downloadFallbackRoute(snapshot.token(), preferredPlatform)
                : directDownloadFallback(preferredPlatform);
        var chipMarkup = resolution.mode() == ResolutionMode.ACTIVE ? buildChipMarkup(snapshot) : "";
        var quoteBlock = resolution.mode() == ResolutionMode.ACTIVE ? buildQuoteBlock(snapshot) : "";
        var recommendationBlock = resolution.mode() == ResolutionMode.ACTIVE ? buildRecommendationBlock(snapshot) : "";
        var tokenForUrl = snapshot != null ? snapshot.token() : resolution.token();

        return """
                <!doctype html>
                <html lang=\"zh-CN\">
                <head>
                  <meta charset=\"utf-8\" />
                  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
                  <meta name=\"share-result\" content=\"%s\" />
                  <meta name=\"share-failure-reason\" content=\"%s\" />
                  <meta property=\"og:locale\" content=\"zh_CN\" />
                  <meta property=\"og:type\" content=\"article\" />
                  <meta property=\"og:site_name\" content=\"Baby Talk\" />
                  <meta property=\"og:url\" content=\"%s\" />
                  <meta property=\"og:title\" content=\"%s\" />
                  <meta property=\"og:description\" content=\"%s\" />
                  <title>%s · Baby Talk</title>
                  <style>
                    :root {
                      color-scheme: light;
                      --bg-base: %s;
                      --bg-surface: %s;
                      --bg-sunken: %s;
                      --bg-accent-soft: %s;
                      --accent: %s;
                      --accent-dark: %s;
                      --text-primary: %s;
                      --text-secondary: %s;
                      --error: %s;
                      --english: %s;
                    }
                    * { box-sizing: border-box; }
                    body {
                      margin: 0;
                      min-height: 100vh;
                      background: linear-gradient(180deg, var(--bg-base) 0%%, var(--bg-sunken) 100%%);
                      color: var(--text-primary);
                      font-family: \"PingFang SC\", \"Noto Sans SC\", \"Microsoft YaHei\", sans-serif;
                    }
                    main {
                      max-width: 430px;
                      margin: 0 auto;
                      padding: 24px 16px 48px;
                    }
                    .card {
                      background: var(--bg-surface);
                      border-radius: 24px;
                      padding: 24px 20px;
                      box-shadow: 0 8px 24px rgba(45,41,38,0.12);
                    }
                    .eyebrow {
                      display: inline-flex;
                      align-items: center;
                      gap: 8px;
                      padding: 6px 12px;
                      border-radius: 9999px;
                      background: var(--bg-accent-soft);
                      color: var(--accent-dark);
                      font-size: 11px;
                      font-weight: 700;
                      letter-spacing: 0.06em;
                      text-transform: uppercase;
                    }
                    h1 {
                      margin: 16px 0 12px;
                      font-size: 28px;
                      line-height: 1.3;
                    }
                    .summary {
                      margin: 0;
                      color: var(--text-secondary);
                      font-size: 15px;
                      line-height: 1.7;
                    }
                    .quote {
                      margin-top: 20px;
                      padding: 18px 16px;
                      border-radius: 16px;
                      background: rgba(59,133,119,0.08);
                    }
                    .quote-title {
                      margin: 0 0 8px;
                      color: var(--text-secondary);
                      font-size: 13px;
                    }
                    .quote-text {
                      margin: 0;
                      color: var(--english);
                      font-family: Fraunces, Georgia, serif;
                      font-size: 24px;
                      line-height: 1.3;
                    }
                    .quote-translation {
                      margin-top: 8px;
                      color: var(--text-secondary);
                      font-size: 14px;
                    }
                    .recommendation {
                      margin-top: 16px;
                      padding: 16px;
                      border-radius: 16px;
                      background: var(--bg-sunken);
                    }
                    .recommendation h2 {
                      margin: 0 0 8px;
                      font-size: 16px;
                    }
                    .recommendation p {
                      margin: 0;
                      color: var(--text-secondary);
                      line-height: 1.6;
                    }
                    .chips {
                      margin-top: 18px;
                      display: flex;
                      flex-wrap: wrap;
                      gap: 8px;
                    }
                    .chip {
                      border-radius: 9999px;
                      background: var(--bg-accent-soft);
                      color: var(--accent-dark);
                      padding: 6px 10px;
                      font-size: 12px;
                    }
                    .status {
                      margin-top: 18px;
                      padding: 14px 16px;
                      border-radius: 16px;
                      background: rgba(255,140,66,0.10);
                      color: var(--text-secondary);
                      line-height: 1.6;
                      font-size: 14px;
                    }
                    .status.error {
                      background: rgba(217,75,60,0.10);
                      color: var(--error);
                    }
                    .actions {
                      margin-top: 20px;
                      display: grid;
                      gap: 12px;
                    }
                    .cta-link {
                      display: block;
                      width: 100%%;
                      border: 0;
                      border-radius: 16px;
                      padding: 14px 16px;
                      background: var(--accent);
                      color: white;
                      font-weight: 700;
                      text-align: center;
                      text-decoration: none;
                    }
                    .cta-link.secondary {
                      background: var(--bg-accent-soft);
                      color: var(--accent-dark);
                    }
                    .footnote {
                      margin-top: 18px;
                      color: var(--text-secondary);
                      font-size: 13px;
                      line-height: 1.6;
                    }
                  </style>
                </head>
                <body>
                  <main data-result=\"%s\" data-failure-reason=\"%s\">
                    <section class=\"card\">
                      <span class=\"eyebrow\">Baby Talk · 成长分享</span>
                      <h1>%s</h1>
                      <p class=\"summary\">%s</p>
                      %s
                      %s
                      %s
                      <div class=\"status %s\">%s</div>
                      <div class=\"actions\">
                        %s
                        <a class=\"cta-link secondary\" href=\"%s\">去下载页继续</a>
                      </div>
                      <p class=\"footnote\">公开分享页只保留脱敏后的成长瞬间，不会暴露宝宝姓名、账号或安装信息。</p>
                    </section>
                  </main>
                </body>
                </html>
                """.formatted(
                HtmlUtils.htmlEscape(pageResult),
                HtmlUtils.htmlEscape(nullToEmpty(pageFailureReason)),
                HtmlUtils.htmlEscape(publicShareUrl(tokenForUrl)),
                HtmlUtils.htmlEscape(title),
                HtmlUtils.htmlEscape(ogDescription),
                HtmlUtils.htmlEscape(title),
                PALETTE.bgBase(),
                PALETTE.bgSurface(),
                PALETTE.bgSunken(),
                PALETTE.bgAccentSoft(),
                PALETTE.accent(),
                PALETTE.accentDark(),
                PALETTE.textPrimary(),
                PALETTE.textSecondary(),
                PALETTE.error(),
                PALETTE.english(),
                HtmlUtils.htmlEscape(pageResult),
                HtmlUtils.htmlEscape(nullToEmpty(pageFailureReason)),
                HtmlUtils.htmlEscape(title),
                HtmlUtils.htmlEscape(summary),
                quoteBlock,
                recommendationBlock,
                chipMarkup,
                (resolution.mode() == ResolutionMode.INVALID || resolution.mode() == ResolutionMode.EXPIRED || resolution.mode() == ResolutionMode.UNAVAILABLE) ? "error" : "",
                HtmlUtils.htmlEscape(statusMessage(resolution, preferredPlatform, failureReason)),
                platformButtons,
                HtmlUtils.htmlEscape(fallbackHref)
        );
    }

    private String renderRedirectErrorHtml(ShareResolution resolution, String platform, String message, String fallbackHref) {
        var token = resolution.snapshot() != null ? resolution.snapshot().token() : resolution.token();
        return """
                <!doctype html>
                <html lang=\"zh-CN\">
                <head>
                  <meta charset=\"utf-8\" />
                  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
                  <meta name=\"share-result\" content=\"%s\" />
                  <meta name=\"share-failure-reason\" content=\"%s\" />
                  <title>无法继续跳转 · Baby Talk</title>
                </head>
                <body style=\"margin:0;background:%s;color:%s;font-family:PingFang SC,Microsoft YaHei,sans-serif;\">
                  <main style=\"max-width:430px;margin:0 auto;padding:24px 16px 48px;\">
                    <section style=\"background:%s;border-radius:24px;padding:24px 20px;box-shadow:0 8px 24px rgba(45,41,38,0.12);\">
                      <h1 style=\"margin:0 0 12px;font-size:24px;line-height:1.3;\">无法继续跳转</h1>
                      <p style=\"margin:0;color:%s;line-height:1.7;\">%s</p>
                      <p style=\"margin:18px 0 0;display:grid;gap:12px;\">
                        <a href=\"%s\" style=\"display:block;text-align:center;padding:14px 16px;border-radius:16px;background:%s;color:white;text-decoration:none;font-weight:700;\">去下载页继续</a>
                        <a href=\"/share/%s\" style=\"display:block;text-align:center;padding:14px 16px;border-radius:16px;background:%s;color:%s;text-decoration:none;font-weight:700;\">返回分享页</a>
                      </p>
                      <p style=\"margin-top:18px;color:%s;font-size:13px;\">平台：%s</p>
                    </section>
                  </main>
                </body>
                </html>
                """.formatted(
                HtmlUtils.htmlEscape(resultForResolution(resolution)),
                HtmlUtils.htmlEscape(nullToEmpty(resolution.failureReason())),
                PALETTE.bgBase(),
                PALETTE.textPrimary(),
                PALETTE.bgSurface(),
                PALETTE.textSecondary(),
                HtmlUtils.htmlEscape(message),
                HtmlUtils.htmlEscape(fallbackHref),
                PALETTE.accent(),
                HtmlUtils.htmlEscape(token),
                PALETTE.bgAccentSoft(),
                PALETTE.accentDark(),
                PALETTE.textSecondary(),
                HtmlUtils.htmlEscape(platform == null ? "unknown" : platformLabel(platform))
        );
    }

    private String buildQuoteBlock(ShareLandingRepository.ShareCardRow snapshot) {
        if (snapshot.phraseText() == null) {
            return "";
        }
        var translation = snapshot.phraseTranslation() == null
                ? ""
                : "<p class=\"quote-translation\">%s</p>".formatted(HtmlUtils.htmlEscape(snapshot.phraseTranslation()));
        return """
                <section class=\"quote\">
                  <p class=\"quote-title\">今天说出口的一句英语</p>
                  <p class=\"quote-text\">%s</p>
                  %s
                </section>
                """.formatted(HtmlUtils.htmlEscape(snapshot.phraseText()), translation);
    }

    private String buildRecommendationBlock(ShareLandingRepository.ShareCardRow snapshot) {
        if (snapshot.recommendationTitle() == null) {
            return "";
        }
        var reason = snapshot.recommendationReason() == null ? "继续保持这个节奏。" : snapshot.recommendationReason();
        return """
                <section class=\"recommendation\">
                  <h2>%s</h2>
                  <p>%s</p>
                </section>
                """.formatted(
                HtmlUtils.htmlEscape(snapshot.recommendationTitle()),
                HtmlUtils.htmlEscape(reason)
        );
    }

    private String buildChipMarkup(ShareLandingRepository.ShareCardRow snapshot) {
        var chips = new ArrayList<String>();
        if (snapshot.source() != null) {
            chips.add("来源 · " + sourceLabel(snapshot.source()));
        }
        if (snapshot.spaceId() != null) {
            chips.add("space · " + snapshot.spaceId());
        }
        if (snapshot.activityId() != null) {
            chips.add("activity · " + snapshot.activityId());
        }
        if (chips.isEmpty()) {
            return "";
        }
        var markup = new StringBuilder("<div class=\"chips\">");
        for (var chip : chips) {
            markup.append("<span class=\"chip\">%s</span>".formatted(HtmlUtils.htmlEscape(chip)));
        }
        markup.append("</div>");
        return markup.toString();
    }

    private String statusMessage(ShareResolution resolution, String preferredPlatform, String failureReason) {
        if (resolution.mode() == ResolutionMode.INVALID) {
            return "这个分享链接无效，请让家长重新发送新的分享卡片。";
        }
        if (resolution.mode() == ResolutionMode.EXPIRED) {
            return "这份分享已经过期。为了保护隐私，请让家长重新生成新链接。";
        }
        if (resolution.mode() == ResolutionMode.UNAVAILABLE) {
            return "分享页暂时不可用，请稍后再试或直接进入下载页。";
        }
        if (failureReason == null) {
            return preferredPlatform == null
                    ? "你可以直接打开 app，或先进入下载页安装 Baby Talk。"
                    : "系统已按当前设备推荐按钮，你也可以改用下载页继续。";
        }
        if ("open_app_unconfigured".equals(failureReason)) {
            return "当前未配置可公开的打开 app 入口，请先进入下载页。";
        }
        return "当前入口暂不可用，请先进入下载页继续。";
    }

    private String resultForResolution(ShareResolution resolution) {
        return switch (resolution.mode()) {
            case ACTIVE -> "page_view";
            case INVALID -> "invalid";
            case EXPIRED -> "expired";
            case UNAVAILABLE -> "unavailable";
        };
    }

    private String buildOgDescription(ShareLandingRepository.ShareCardRow snapshot) {
        var parts = new ArrayList<String>();
        parts.add(snapshot.storyText());
        if (snapshot.phraseText() != null) {
            parts.add("英文短语：" + snapshot.phraseText());
        }
        if (snapshot.recommendationTitle() != null) {
            parts.add("继续练习：" + snapshot.recommendationTitle());
        }
        return String.join(" · ", parts);
    }

    private Map<String, String> availableOpenAppTargets() {
        var ordered = new LinkedHashMap<String, String>();
        orderTargets(properties.openAppTargets()).forEach((platform, target) -> {
            if (platform == null || target == null || target.isBlank()) {
                return;
            }
            if (ALLOWED_PLATFORMS.contains(platform)) {
                ordered.put(platform, target.trim());
            }
        });
        return ordered;
    }

    private Map<String, String> orderTargets(Map<String, String> rawTargets) {
        var ordered = new LinkedHashMap<String, String>();
        if (rawTargets == null || rawTargets.isEmpty()) {
            return ordered;
        }
        if (rawTargets.containsKey("android")) {
            ordered.put("android", rawTargets.get("android"));
        }
        if (rawTargets.containsKey("ios")) {
            ordered.put("ios", rawTargets.get("ios"));
        }
        rawTargets.forEach((platform, target) -> {
            if (!ordered.containsKey(platform)) {
                ordered.put(platform, target);
            }
        });
        return ordered;
    }

    private String publicShareUrl(String token) {
        var baseUrl = properties.publicBaseUrl().endsWith("/")
                ? properties.publicBaseUrl().substring(0, properties.publicBaseUrl().length() - 1)
                : properties.publicBaseUrl();
        return baseUrl + "/share/" + token;
    }

    private String downloadFallbackRoute(String token, String platform) {
        var builder = UriComponentsBuilder.fromPath("/share/{token}/download")
                .buildAndExpand(token)
                .toUriString();
        if (platform == null) {
            return builder;
        }
        return UriComponentsBuilder.fromPath(builder)
                .queryParam("platform", platform)
                .build()
                .toUriString();
    }

    private String directDownloadFallback(String platform) {
        var builder = UriComponentsBuilder.fromPath(properties.downloadFallbackPath())
                .queryParam("source", properties.downloadFallbackSource());
        if (platform != null) {
            builder.queryParam("platform", platform);
        }
        return builder.build().toUriString();
    }

    private String generateToken() {
        var randomBytes = new byte[12];
        secureRandom.nextBytes(randomBytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);
    }

    private void rejectSensitiveField(String fieldName, String rawValue) {
        if (trimToNull(rawValue) != null) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_share_payload",
                    "分享 payload 不能包含内部或敏感字段。",
                    Map.of("field", fieldName)
            );
        }
    }

    private String normalizeRequired(
            String rawValue,
            String fieldName,
            String code,
            String message,
            Set<String> allowedValues
    ) {
        var normalized = normalizeKey(rawValue);
        if (normalized == null) {
            throw new ContractException(HttpStatus.BAD_REQUEST, code, message, Map.of("field", fieldName));
        }
        if (allowedValues != null && !allowedValues.contains(normalized)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, code, "source 非法。", Map.of(fieldName, normalized));
        }
        return normalized;
    }

    private String requireTrimmed(String rawValue, String fieldName, String code, String message) {
        var normalized = trimToNull(rawValue);
        if (normalized == null) {
            throw new ContractException(HttpStatus.BAD_REQUEST, code, message, Map.of("field", fieldName));
        }
        return normalized;
    }

    private String normalizeKey(String rawValue) {
        if (rawValue == null || rawValue.isBlank()) {
            return null;
        }
        return rawValue.trim().toLowerCase(Locale.ROOT).replace('-', '_');
    }

    private String trimToNull(String rawValue) {
        if (rawValue == null || rawValue.isBlank()) {
            return null;
        }
        return rawValue.trim();
    }

    private java.util.Optional<String> optionalValue(String rawValue) {
        var normalized = trimToNull(rawValue);
        if (normalized == null) {
            return java.util.Optional.empty();
        }
        return java.util.Optional.of(normalized);
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

    private String sourceLabel(String source) {
        return switch (source) {
            case "latest_impact" -> "latestImpact";
            case "continuity_recommendation" -> "continuity";
            case "paired_progress" -> "impact + continuity";
            default -> source;
        };
    }

    private String platformLabel(String platform) {
        return switch (platform) {
            case "android" -> "Android";
            case "ios" -> "iPhone / iPad";
            default -> platform;
        };
    }

    private String safeToken(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            return "unknown";
        }
        return rawToken.trim();
    }

    private String nullToEmpty(String value) {
        return value == null ? "" : value;
    }

    public record CreateShareLinkCommand(
            String source,
            String platformHint,
            String headline,
            String storyText,
            String phraseText,
            String phraseTranslation,
            String recommendationTitle,
            String recommendationReason,
            String spaceId,
            String activityId,
            String childName,
            String installationId,
            String eventKey,
            String fallbackReason
    ) {
    }

    public record CreateShareLinkResponse(
            String token,
            String shareUrl,
            Instant expiresAt
    ) {
    }

    public record PageResponse(
            HttpStatus status,
            String result,
            String failureReason,
            AuditStatus auditStatus,
            String html
    ) {
    }

    public record RedirectResponse(
            HttpStatus status,
            String result,
            String failureReason,
            AuditStatus auditStatus,
            URI location,
            String html
    ) {
        public static RedirectResponse redirect(String result, String failureReason, AuditStatus auditStatus, URI location) {
            return new RedirectResponse(HttpStatus.FOUND, result, failureReason, auditStatus, location, "");
        }

        public static RedirectResponse error(
                HttpStatus status,
                String result,
                String failureReason,
                AuditStatus auditStatus,
                String html
        ) {
            return new RedirectResponse(status, result, failureReason, auditStatus, null, html);
        }
    }

    public enum AuditStatus {
        RECORDED,
        FAILED
    }

    private enum ResolutionMode {
        ACTIVE,
        INVALID,
        EXPIRED,
        UNAVAILABLE
    }

    private record ShareResolution(
            ResolutionMode mode,
            ShareLandingRepository.ShareCardRow snapshot,
            String token,
            String failureReason,
            AuditStatus auditStatus,
            HttpStatus status
    ) {
        static ShareResolution active(ShareLandingRepository.ShareCardRow snapshot) {
            return new ShareResolution(ResolutionMode.ACTIVE, snapshot, snapshot.token(), null, AuditStatus.RECORDED, HttpStatus.OK);
        }

        static ShareResolution invalid(String token, String failureReason, AuditStatus auditStatus, HttpStatus status) {
            return new ShareResolution(ResolutionMode.INVALID, null, token, failureReason, auditStatus, status);
        }

        static ShareResolution invalid(String token, String failureReason, HttpStatus status) {
            return new ShareResolution(ResolutionMode.INVALID, null, token, failureReason, AuditStatus.RECORDED, status);
        }

        static ShareResolution expired(ShareLandingRepository.ShareCardRow snapshot, String failureReason, AuditStatus auditStatus, HttpStatus status) {
            return new ShareResolution(ResolutionMode.EXPIRED, snapshot, snapshot.token(), failureReason, auditStatus, status);
        }

        static ShareResolution unavailable(String token, String failureReason, AuditStatus auditStatus, HttpStatus status) {
            return new ShareResolution(ResolutionMode.UNAVAILABLE, null, token, failureReason, auditStatus, status);
        }

        PageResponse toPageResponse(String html) {
            return new PageResponse(status, resultForMode(), failureReason, auditStatus, html);
        }

        RedirectResponse toRedirectError(String html) {
            return RedirectResponse.error(status, resultForMode(), failureReason, auditStatus, html);
        }

        private String resultForMode() {
            return switch (mode) {
                case ACTIVE -> "page_view";
                case INVALID -> "invalid";
                case EXPIRED -> "expired";
                case UNAVAILABLE -> "unavailable";
            };
        }
    }

    private record MediaPalette(
            String bgBase,
            String bgSurface,
            String bgSunken,
            String bgAccentSoft,
            String accent,
            String accentDark,
            String textPrimary,
            String textSecondary,
            String error,
            String english
    ) {
    }
}
