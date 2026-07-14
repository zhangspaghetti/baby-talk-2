package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.MentorProperties;
import com.zhangspaghetti.babytalk.palace.MemPalacePromptBuilder;
import com.zhangspaghetti.babytalk.palace.PalaceSearchService;
import com.zhangspaghetti.babytalk.practice.catalog.PracticeCatalogService;
import com.zhangspaghetti.babytalk.practice.catalog.model.CachedActivity;
import com.zhangspaghetti.babytalk.practice.catalog.model.CachedPhrase;
import com.zhangspaghetti.babytalk.web.ContractException;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

@Service
public class MentorService {

    private static final Logger log = LoggerFactory.getLogger(MentorService.class);
    private static final int SUMMARY_MAX_LENGTH = 240;
    private static final int PREVIEW_MAX_LENGTH = 72;
    private static final Pattern JSON_BLOCK_PATTERN = Pattern.compile("\\{\\s*\"activities\"\\s*:", Pattern.DOTALL);

    private final MentorRepository repository;
    private final AuthConsentSyncRepository authConsentSyncRepository;
    private final MentorProvider mentorProvider;
    private final MentorProperties properties;
    private final ConversationSessionService conversationSessionService;
    private final TransactionTemplate transactionTemplate;
    private final PalaceSearchService palaceSearchService;
    private final ObjectMapper objectMapper;
    private final PracticeCatalogService catalogService;
    private final Clock clock = Clock.systemUTC();

    public MentorService(
            MentorRepository repository,
            AuthConsentSyncRepository authConsentSyncRepository,
            MentorProvider mentorProvider,
            MentorProperties properties,
            ConversationSessionService conversationSessionService,
            PlatformTransactionManager txManager,
            PalaceSearchService palaceSearchService,
            ObjectMapper objectMapper,
            PracticeCatalogService catalogService
    ) {
        this.repository = repository;
        this.authConsentSyncRepository = authConsentSyncRepository;
        this.mentorProvider = mentorProvider;
        this.properties = properties;
        this.conversationSessionService = conversationSessionService;
        this.transactionTemplate = new TransactionTemplate(txManager);
        this.palaceSearchService = palaceSearchService;
        this.objectMapper = objectMapper;
        this.catalogService = catalogService;
    }

    /**
     * 三阶段 chat 编排——provider 调用不再占用数据库连接：
     * <ol>
     *   <li>阶段 1（预提交检查）：输入校验 + session 解析 + rate limit + chat_requested audit + blocked fallback</li>
     *   <li>阶段 2（无事务）：调用 mentorProvider.respond()，数据库连接已归还连接池</li>
     *   <li>阶段 3（新事务）：写 turn + response_delivered / error audit</li>
     * </ol>
     */
    public ChatResponse chat(ChatCommand command, String sessionIdHeader) {
        // === 阶段 1：预提交检查 — 验证 + session + rate limit + audit ===
        // 这里不再包一层大事务，避免并发时“外层事务 + REQUIRES_NEW rate-limit”同时占用两条连接。
        // 各个需要持久化的 audit/turn 写入点自行提交，rate-limit 仍由独立事务保证 insert+count 的可见性。
        var phase1Result = executePhase1(command, sessionIdHeader);

        // Blocked fallback 完全在阶段 1 内处理
        if (phase1Result.earlyResponse() != null) {
            return phase1Result.earlyResponse();
        }

        // === 阶段 2：无事务 — provider 调用 ===
        // 数据库连接已归还连接池，provider 耗时不再占用连接
        try {
            var providerResponse = mentorProvider.respond(new MentorProvider.ProviderRequest(
                    phase1Result.effectiveCorrelationId(),
                    phase1Result.installationId(),
                    phase1Result.surface(),
                    phase1Result.mode(),
                    phase1Result.prompt(),
                    phase1Result.requestSummary(),
                    phase1Result.association().authenticated(),
                    phase1Result.now(),
                    phase1Result.conversationId(),
                    command.childAgeMonths()
            ));
            var responseText = normalizeProviderResponse(providerResponse.responseText());
            var responseSummary = providerResponse.responseSummary() == null || providerResponse.responseSummary().isBlank()
                    ? summarizeResponse(responseText)
                    : trimSummary(providerResponse.responseSummary());

            // === 阶段 3：新事务 — 写 turn + response audit ===
            transactionTemplate.execute(status -> {
                repository.insertTurn(turnRow(
                        phase1Result.effectiveCorrelationId(),
                        phase1Result.installationId(),
                        phase1Result.association(),
                        phase1Result.surface(),
                        phase1Result.mode(),
                        "success",
                        "response_delivered",
                        phase1Result.requestSummary(),
                        responseSummary,
                        responseText,
                        false,
                        false,
                        phase1Result.now()
                ));
                repository.insertAudit(auditRow(
                        phase1Result.effectiveCorrelationId(),
                        phase1Result.installationId(),
                        phase1Result.association(),
                        "chat_response_delivered",
                        "response_delivered",
                        "success",
                        phase1Result.requestSummary(),
                        responseSummary,
                        phase1Result.association().authenticated() ? "session_attached" : "anonymous_installation",
                        null,
                        false,
                        false,
                        phase1Result.now()
                ));
                return null;
            });

            return new ChatResponse(
                    phase1Result.effectiveCorrelationId(),
                    phase1Result.conversationId(),
                    responseText,
                    "ok",
                    "response_delivered",
                    false,
                    false,
                    phase1Result.association().authenticated(),
                    new RateLimitStatus(false, properties.rateLimitMaxRequests(), phase1Result.remaining(), properties.rateLimitWindow().toSeconds()),
                    phase1Result.now()
            );
        } catch (MentorProvider.ProviderTimeoutException exception) {
            // provider 异常的 error audit 在阶段 3 新事务中写入
            transactionTemplate.execute(status -> {
                repository.insertAudit(auditRow(
                        phase1Result.effectiveCorrelationId(),
                        phase1Result.installationId(),
                        phase1Result.association(),
                        "provider_timeout",
                        "provider_timeout",
                        "error",
                        phase1Result.requestSummary(),
                        null,
                        trimSummary(exception.getMessage()),
                        "provider_timeout",
                        true,
                        false,
                        phase1Result.now()
                ));
                return null;
            });
            throw contractError(
                    HttpStatus.GATEWAY_TIMEOUT,
                    "provider_timeout",
                    "小禾老师暂时没有来得及回应，请稍后再试。",
                    phase1Result.effectiveCorrelationId(),
                    "provider_timeout",
                    true,
                    false,
                    Map.of("remaining", phase1Result.remaining())
            );
        } catch (MentorProvider.ProviderMalformedResponseException exception) {
            transactionTemplate.execute(status -> {
                repository.insertAudit(auditRow(
                        phase1Result.effectiveCorrelationId(),
                        phase1Result.installationId(),
                        phase1Result.association(),
                        "provider_malformed_response",
                        "provider_malformed_response",
                        "error",
                        phase1Result.requestSummary(),
                        null,
                        trimSummary(exception.getMessage()),
                        "provider_malformed_response",
                        true,
                        false,
                        phase1Result.now()
                ));
                return null;
            });
            throw contractError(
                    HttpStatus.BAD_GATEWAY,
                    "provider_malformed_response",
                    "上游回应格式异常，已安全拦截。",
                    phase1Result.effectiveCorrelationId(),
                    "provider_malformed_response",
                    true,
                    false,
                    Map.of("remaining", phase1Result.remaining())
            );
        } catch (MentorProvider.ProviderUnavailableException exception) {
            transactionTemplate.execute(status -> {
                repository.insertAudit(auditRow(
                        phase1Result.effectiveCorrelationId(),
                        phase1Result.installationId(),
                        phase1Result.association(),
                        "provider_unavailable",
                        "provider_unavailable",
                        "error",
                        phase1Result.requestSummary(),
                        null,
                        trimSummary(exception.getMessage()),
                        "provider_unavailable",
                        true,
                        false,
                        phase1Result.now()
                ));
                return null;
            });
            throw contractError(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "provider_unavailable",
                    "小禾老师暂时不可用，请稍后再试。",
                    phase1Result.effectiveCorrelationId(),
                    "provider_unavailable",
                    true,
                    false,
                    Map.of("remaining", phase1Result.remaining())
            );
        }
    }

    /**
     * 阶段 1 内部逻辑：输入校验 → session 解析 → rate limit → audit → blocked fallback。
        * 每个需要持久化的 audit/turn 写入点在各自调用处提交；rate-limit 仍使用独立事务保证并发可见性。
     */
    private Phase1Result executePhase1(ChatCommand command, String sessionIdHeader) {
        var now = Instant.now(clock);
        var installationId = normalizeInstallationId(command.installationId());
        var prompt = normalizePrompt(command.prompt());
        var surface = normalizeAllowed(command.surface(), "surface", properties.allowedSurfaces());
        var mode = normalizeAllowed(command.mode(), "mode", properties.allowedModes());
        var correlationId = normalizeCorrelationId(command.correlationId());
        var effectiveCorrelationId = correlationId == null ? "mentor_" + UUID.randomUUID() : correlationId;
        var requestSummary = buildRequestSummary(surface, mode, prompt, command.contextSummary());
        var association = resolveSession(sessionIdHeader, installationId, effectiveCorrelationId, requestSummary, now);

        // 解析 conversationId：null/blank → 新 UUID, 超时 → 新 UUID + WARN, 未超时 → 原 ID
        var resolvedConversationId = conversationSessionService.resolveConversationId(command.conversationId());

        // 先 INSERT chat_requested audit 占位，再 COUNT 窗口内请求数（修复并发 TOCTOU 竞态）
        var currentCount = repository.insertAuditAndCountWindow(
                auditRow(
                        effectiveCorrelationId,
                        installationId,
                        association,
                        "chat_requested",
                        "request_received",
                        "accepted",
                        requestSummary,
                        null,
                        association.authenticated() ? "session_attached" : "anonymous_installation",
                        null,
                        false,
                        false,
                        now
                ),
                now.minus(properties.rateLimitWindow())
        );
        if (currentCount > properties.rateLimitMaxRequests()) {
            repository.insertAudit(auditRow(
                    effectiveCorrelationId,
                    installationId,
                    association,
                    "rate_limited",
                    "rate_limited",
                    "rejected",
                    requestSummary,
                    null,
                    "installation_window_limit_exceeded",
                    "mentor_rate_limited",
                    true,
                    true,
                    now
            ));
            throw contractError(
                    HttpStatus.TOO_MANY_REQUESTS,
                    "mentor_rate_limited",
                    "当前求助太频繁了，请稍后再试。",
                    effectiveCorrelationId,
                    "rate_limited",
                    true,
                    true,
                    Map.of(
                            "limit", properties.rateLimitMaxRequests(),
                            "windowSeconds", properties.rateLimitWindow().toSeconds(),
                            "remaining", 0
                    )
            );
        }

        var remaining = Math.max(0, properties.rateLimitMaxRequests() - currentCount);
        if (isBlockedPrompt(prompt)) {
            var fallbackText = buildBlockedFallbackText();
            var responseSummary = summarizeResponse(fallbackText);
            repository.insertTurn(turnRow(
                    effectiveCorrelationId,
                    installationId,
                    association,
                    surface,
                    mode,
                    "fallback",
                    "blocked_fallback",
                    requestSummary,
                    responseSummary,
                    fallbackText,
                    false,
                    true,
                    now
            ));
            repository.insertAudit(auditRow(
                    effectiveCorrelationId,
                    installationId,
                    association,
                    "blocked_fallback",
                    "blocked_fallback",
                    "fallback",
                    requestSummary,
                    responseSummary,
                    "policy_boundary_triggered",
                    "blocked_fallback",
                    false,
                    false,
                    now
            ));
            return new Phase1Result(
                    effectiveCorrelationId,
                    installationId,
                    association,
                    surface,
                    mode,
                    prompt,
                    requestSummary,
                    remaining,
                    now,
                    resolvedConversationId,
                    new ChatResponse(
                            effectiveCorrelationId,
                            resolvedConversationId,
                            fallbackText,
                            "blocked_fallback",
                            "blocked_fallback",
                            false,
                            true,
                            association.authenticated(),
                            new RateLimitStatus(false, properties.rateLimitMaxRequests(), remaining, properties.rateLimitWindow().toSeconds()),
                            now
                    )
            );
        }

        return new Phase1Result(
                effectiveCorrelationId,
                installationId,
                association,
                surface,
                mode,
                prompt,
                requestSummary,
                remaining,
                now,
                resolvedConversationId,
                null
        );
    }

    /**
     * 练习生成 — 独立管线，不经过 chat 三阶段（无 rate limit、无 turn 记录）。
     * <ol>
     *   <li>验证 installationId 和 surface=practice</li>
     *   <li>构建 practice system prompt（复用 L1 知识宫殿预检索）</li>
     *   <li>调用 mentorProvider.respond() 获取 LLM 原始响应</li>
     *   <li>尝试 JSON 解析为 PracticeGenerateResponse</li>
     *   <li>JSON 解析失败时尝试正则提取或返回 fallback 空 response</li>
     * </ol>
     */
    public PracticeGenerateResponse generatePractice(PracticeGenerateCommand command, String sessionIdHeader) {
        var now = Instant.now(clock);
        var installationId = normalizeInstallationId(command.installationId());
        var surface = requireTrimmed(command.surface(), "surface").toLowerCase(Locale.ROOT);
        if (!"practice".equals(surface)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_surface",
                    "practice generate 端点仅接受 surface=practice。",
                    Map.of("phase", "invalid_surface", "allowed", List.of("practice")));
        }

        var babyAgeMonths = normalizePracticeBabyAgeMonths(command.babyAgeMonths());
        var sceneTag = normalizePracticeSceneTag(command.sceneTag());
        var correlationId = "practice_" + UUID.randomUUID();
        var userPrompt = buildPracticeUserPrompt(babyAgeMonths, sceneTag);
        var requestSummary = buildRequestSummary(surface, "practice_generate", userPrompt, null);
        var association = resolveSession(sessionIdHeader, installationId, correlationId, requestSummary, now);

        var currentCount = repository.insertAuditAndCountWindow(
                auditRow(
                        correlationId,
                        installationId,
                        association,
                        "practice_requested",
                        "request_received",
                        "accepted",
                        requestSummary,
                        null,
                        association.authenticated() ? "session_attached" : "anonymous_installation",
                        null,
                        false,
                        false,
                        now
                ),
                now.minus(properties.rateLimitWindow())
        );
        if (currentCount > properties.rateLimitMaxRequests()) {
            repository.insertAudit(auditRow(
                    correlationId,
                    installationId,
                    association,
                    "rate_limited",
                    "rate_limited",
                    "rejected",
                    requestSummary,
                    null,
                    "installation_window_limit_exceeded",
                    "mentor_rate_limited",
                    true,
                    true,
                    now
            ));
            throw contractError(
                    HttpStatus.TOO_MANY_REQUESTS,
                    "mentor_rate_limited",
                    "当前求助太频繁了，请稍后再试。",
                    correlationId,
                    "rate_limited",
                    true,
                    true,
                    Map.of(
                            "limit", properties.rateLimitMaxRequests(),
                            "windowSeconds", properties.rateLimitWindow().toSeconds(),
                            "remaining", 0
                    )
            );
        }

        var resolvedConversationId = conversationSessionService.resolveConversationId(command.conversationId());
        log.info("practice.generate: surface=practice, babyAgeMonths={}, sceneTag={}, authenticated={}",
                babyAgeMonths, sceneTag, association.authenticated());

        // ── Cache hit: skip LLM call if activity already in DB ──
        if (sceneTag != null) {
            var cached = catalogService.findActivityBySceneTag(sceneTag);
            if (cached.isPresent()) {
                log.info("practice.generate: cache hit for sceneTag={}, activityId={}", sceneTag, cached.get().id());
                var cachedPhrases = catalogService.findPhrasesByActivityId(cached.get().id());
                return buildCachedResponse(cached.get(), cachedPhrases);
            }
        }

        String systemPrompt = MemPalacePromptBuilder.buildPracticeSystemPrompt(
                babyAgeMonths, sceneTag, palaceSearchService);

        String rawResponse;
        try {
            var providerResponse = mentorProvider.respond(new MentorProvider.ProviderRequest(
                    correlationId,
                    installationId,
                    surface,
                    "single_turn",
                    userPrompt,
                    "practice_generate:age=%d,scene=%s".formatted(babyAgeMonths, sceneTag),
                    false,
                    now,
                    resolvedConversationId
            ));
            rawResponse = providerResponse.responseText();
        } catch (MentorProvider.ProviderTimeoutException e) {
            log.warn("practice.generate: provider timeout", e);
            throw new ContractException(HttpStatus.GATEWAY_TIMEOUT, "provider_timeout",
                    "练习生成超时，请稍后再试。", Map.of("phase", "provider_timeout", "retryable", true));
        } catch (MentorProvider.ProviderUnavailableException e) {
            log.warn("practice.generate: provider unavailable", e);
            throw new ContractException(HttpStatus.SERVICE_UNAVAILABLE, "provider_unavailable",
                    "服务暂时不可用，请稍后再试。", Map.of("phase", "provider_unavailable", "retryable", true));
        } catch (MentorProvider.ProviderMalformedResponseException e) {
            log.warn("practice.generate: provider malformed response", e);
            return PracticeGenerateResponse.empty();
        }

        if (rawResponse == null || rawResponse.isBlank()) {
            log.warn("practice.generate: provider returned empty response");
            return PracticeGenerateResponse.empty();
        }

        var parsed = parsePracticeResponse(rawResponse);

        // ── Write-through: persist LLM-generated content to catalog ──
        if (sceneTag != null && !parsed.activities().isEmpty()) {
            var persisted = persistToCatalog(sceneTag, parsed);
            if (persisted != null) {
                return persisted;
            }
        }

        return parsed;
    }

    /**
     * Build a PracticeGenerateResponse from cached DB records.
     */
    private PracticeGenerateResponse buildCachedResponse(
            CachedActivity activity,
            List<CachedPhrase> phrases) {
        var phraseDtos = phrases.stream()
                .map(p -> new PhraseDto(p.id(), p.english(), p.chinese(), p.pronunciation(), p.difficulty()))
                .toList();
        var activityDto = new ActivityDto(
                activity.id(),
                activity.titleZh(),
                null,
                null,
                activity.coachTip(),
                phraseDtos
        );
        return new PracticeGenerateResponse(List.of(activityDto));
    }

    /**
     * Write-through: classify sceneTag to a space, insert activity + phrases.
     * Returns a new PracticeGenerateResponse with DB IDs populated, or null on failure.
     */
    private PracticeGenerateResponse persistToCatalog(String sceneTag, PracticeGenerateResponse parsed) {
        try {
            return transactionTemplate.execute(status -> {
                var spaceSlug = classifySceneTagToSpaceSlug(sceneTag);
                var spaceId = catalogService.insertSpace(spaceSlug, spaceSlug);
                var activitySlug = "llm_" + sanitizeSlug(sceneTag) + "_" +
                        UUID.randomUUID().toString().replace("-", "").substring(0, 8);

                var activityId = catalogService.insertActivity(
                        activitySlug, spaceId, sceneTag, sceneTag, null);

                var enrichedActivities = new ArrayList<ActivityDto>();
                for (int i = 0; i < parsed.activities().size(); i++) {
                    var act = parsed.activities().get(i);
                    var enrichedPhrases = new ArrayList<PhraseDto>();
                    for (int j = 0; j < act.phrases().size(); j++) {
                        var phrase = act.phrases().get(j);
                        var phraseSlug = activitySlug + "_" + (j + 1);
                        var phraseId = catalogService.insertPhrase(
                                phraseSlug, activityId, j + 1,
                                phrase.english(), phrase.chinese(),
                                phrase.pronunciation(), phrase.difficulty());
                        enrichedPhrases.add(new PhraseDto(
                                phraseId, phrase.english(), phrase.chinese(),
                                phrase.pronunciation(), phrase.difficulty()));
                    }
                    enrichedActivities.add(new ActivityDto(
                            activityId, act.title(), act.summary(),
                            act.sceneTag(), act.coachTip(), enrichedPhrases));
                }
                log.info("practice.generate: persisted to catalog, activitySlug={}, activityId={}",
                        activitySlug, activityId);
                return new PracticeGenerateResponse(enrichedActivities);
            });
        } catch (Exception e) {
            // Write-through failure should not break the response
            log.warn("practice.generate: catalog write-through failed", e);
            return null;
        }
    }

    /**
     * Classify a sceneTag into a space slug. Maps known tags to seeded spaces,
     * falls back to a generic slug.
     */
    private String classifySceneTagToSpaceSlug(String sceneTag) {
        var lower = sceneTag.toLowerCase(Locale.ROOT);
        if (lower.contains("bath") || lower.contains("diaper") || lower.contains("wash") || lower.contains("dressing")) {
            return "daily_care";
        }
        if (lower.contains("feed") || lower.contains("meal") || lower.contains("bed") || lower.contains("sleep")) {
            return "family_rhythm";
        }
        return "general_practice";
    }

    /**
     * Sanitize a sceneTag for use as a slug component: lowercase, replace spaces
     * and non-alphanumerics with underscores, collapse runs, trim edges.
     */
    private String sanitizeSlug(String sceneTag) {
        return sceneTag.toLowerCase(Locale.ROOT)
                .replaceAll("[^a-z0-9]+", "_")
                .replaceAll("_+", "_")
                .replaceAll("^_|_$", "");
    }

    /**
     * 尝试将 LLM 原始响应解析为 PracticeGenerateResponse。
     * 先尝试直接 JSON 解析；失败后尝试从响应中提取 JSON 块；最终 fallback 为空 response。
     */
    PracticeGenerateResponse parsePracticeResponse(String rawResponse) {
        // 先尝试直接解析
        try {
            return objectMapper.readValue(rawResponse.trim(), PracticeGenerateResponse.class);
        } catch (JacksonException e) {
            log.debug("practice.generate: direct JSON parse failed, trying regex extraction");
        }

        // 尝试从文本中提取 JSON 块（LLM 可能包裹在 markdown code fence 中）
        String extracted = extractJsonBlock(rawResponse);
        if (extracted != null) {
            try {
                return objectMapper.readValue(extracted, PracticeGenerateResponse.class);
            } catch (JacksonException e) {
                log.warn("practice.generate: JSON parse fallback failed, rawResponse.length={}", rawResponse.length());
                log.debug("practice.generate: full LLM response for diagnosis: {}", rawResponse);
            }
        } else {
            log.warn("practice.generate: no JSON block found in response, rawResponse.length={}", rawResponse.length());
            log.debug("practice.generate: full LLM response for diagnosis: {}", rawResponse);
        }

        return PracticeGenerateResponse.empty();
    }

    /**
     * 从 LLM 响应中提取 JSON 块 — 处理 markdown code fence 或裸 JSON。
     */
    private String extractJsonBlock(String rawResponse) {
        // 尝试匹配 ```json ... ``` 或 ``` ... ```
        var codeFencePattern = Pattern.compile("```(?:json)?\\s*(\\{.*?})\\s*```", Pattern.DOTALL);
        Matcher matcher = codeFencePattern.matcher(rawResponse);
        if (matcher.find()) {
            return matcher.group(1);
        }

        // 尝试匹配裸 JSON 对象（从 { 到最后的 }）
        Matcher jsonMatcher = JSON_BLOCK_PATTERN.matcher(rawResponse);
        if (jsonMatcher.find()) {
            int start = jsonMatcher.start();
            int braceCount = 0;
            for (int i = start; i < rawResponse.length(); i++) {
                char c = rawResponse.charAt(i);
                if (c == '{') {
                    braceCount++;
                } else if (c == '}') {
                    braceCount--;
                }
                if (braceCount == 0) {
                    return rawResponse.substring(start, i + 1);
                }
            }
        }

        return null;
    }

    @Transactional(readOnly = true)
    public int countTurns() {
        return repository.countTurns();
    }

    @Transactional(readOnly = true)
    public int countAuditRows() {
        return repository.countAuditRows();
    }

    @Transactional(readOnly = true)
    public MentorRepository.TurnRow findTurnByCorrelationId(String correlationId) {
        return repository.findTurnByCorrelationId(correlationId)
                .orElse(null);
    }

    @Transactional(readOnly = true)
    public java.util.List<MentorRepository.AuditRow> listAuditRowsByCorrelationId(String correlationId) {
        return repository.listAuditRowsByCorrelationId(correlationId);
    }

    private SessionAssociation resolveSession(
            String sessionIdHeader,
            String installationId,
            String correlationId,
            String requestSummary,
            Instant now
    ) {
        if (sessionIdHeader == null || sessionIdHeader.isBlank()) {
            return SessionAssociation.anonymous();
        }
        var normalizedSessionId = normalizeSessionId(sessionIdHeader);
        var session = authConsentSyncRepository.findSessionAnyStatus(normalizedSessionId)
                .orElse(null);
        if (session == null) {
            repository.insertAudit(auditRow(
                    correlationId,
                    installationId,
                    new SessionAssociation(null, normalizedSessionId, false),
                    "invalid_session",
                    "invalid_session",
                    "rejected",
                    requestSummary,
                    null,
                    "session_not_found",
                    "invalid_session",
                    true,
                    false,
                    now
            ));
            throw contractError(
                    HttpStatus.UNAUTHORIZED,
                    "invalid_session",
                    "登录状态已失效，请重新登录后再试。",
                    correlationId,
                    "invalid_session",
                    true,
                    false,
                    Map.of()
            );
        }
        var association = new SessionAssociation(session.accountId(), session.sessionId(), true);
        if (!installationId.equals(session.installationId())) {
            repository.insertAudit(auditRow(
                    correlationId,
                    installationId,
                    association,
                    "session_installation_mismatch",
                    "session_installation_mismatch",
                    "rejected",
                    requestSummary,
                    null,
                    "installation_id_not_owned_by_session",
                    "session_installation_mismatch",
                    false,
                    false,
                    now
            ));
            throw contractError(
                    HttpStatus.FORBIDDEN,
                    "session_installation_mismatch",
                    "当前登录状态与 installationId 不匹配。",
                    correlationId,
                    "session_installation_mismatch",
                    false,
                    false,
                    Map.of()
            );
        }
        if ("deleted".equals(session.accountStatus()) || "deleted".equals(session.sessionStatus())
                || "deleted".equals(session.latestConsentStatus())) {
            repository.insertAudit(auditRow(
                    correlationId,
                    installationId,
                    association,
                    "account_deleted",
                    "account_deleted",
                    "rejected",
                    requestSummary,
                    null,
                    "deleted_account_or_session",
                    "account_deleted",
                    false,
                    false,
                    now
            ));
            throw contractError(
                    HttpStatus.FORBIDDEN,
                    "account_deleted",
                    "账号已删除，当前登录态不能继续在线求助。",
                    correlationId,
                    "account_deleted",
                    false,
                    false,
                    Map.of()
            );
        }
        if ("revoked".equals(session.sessionStatus()) || "revoked".equals(session.latestConsentStatus())) {
            repository.insertAudit(auditRow(
                    correlationId,
                    installationId,
                    association,
                    "consent_revoked",
                    "consent_revoked",
                    "rejected",
                    requestSummary,
                    null,
                    "revoked_session_or_consent",
                    "consent_revoked",
                    true,
                    false,
                    now
            ));
            throw contractError(
                    HttpStatus.FORBIDDEN,
                    "consent_revoked",
                    "同意状态不可用，请重新登录并再次同意后再试。",
                    correlationId,
                    "consent_revoked",
                    true,
                    false,
                    Map.of()
            );
        }
        if (!"active".equals(session.sessionStatus())) {
            repository.insertAudit(auditRow(
                    correlationId,
                    installationId,
                    association,
                    "invalid_session",
                    "invalid_session",
                    "rejected",
                    requestSummary,
                    null,
                    "session_not_active",
                    "invalid_session",
                    true,
                    false,
                    now
            ));
            throw contractError(
                    HttpStatus.UNAUTHORIZED,
                    "invalid_session",
                    "登录状态已失效，请重新登录后再试。",
                    correlationId,
                    "invalid_session",
                    true,
                    false,
                    Map.of()
            );
        }
        return association;
    }

    private MentorRepository.TurnRow turnRow(
            String correlationId,
            String installationId,
            SessionAssociation association,
            String surface,
            String mode,
            String result,
            String phase,
            String requestSummary,
            String responseSummary,
            String responseText,
            boolean retryable,
            boolean blockedFallback,
            Instant createdAt
    ) {
        return new MentorRepository.TurnRow(
                "mentor_turn_" + UUID.randomUUID(),
                correlationId,
                installationId,
                association.sessionIdHint(),
                association.accountIdHint(),
                surface,
                mode,
                result,
                phase,
                requestSummary,
                responseSummary,
                responseText,
                properties.providerMode(),
                blockedFallback,
                retryable,
                createdAt
        );
    }

    private MentorRepository.AuditRow auditRow(
            String correlationId,
            String installationId,
            SessionAssociation association,
            String eventType,
            String phase,
            String result,
            String requestSummary,
            String responseSummary,
            String reason,
            String failureCode,
            boolean retryable,
            boolean rateLimited,
            Instant createdAt
    ) {
        return new MentorRepository.AuditRow(
                correlationId,
                installationId,
                association.sessionIdHint(),
                association.accountIdHint(),
                eventType,
                phase,
                result,
                requestSummary,
                responseSummary,
                trimSummary(reason),
                failureCode,
                retryable,
                rateLimited,
                createdAt
        );
    }

    private ContractException contractError(
            HttpStatus status,
            String code,
            String message,
            String correlationId,
            String phase,
            boolean retryable,
            boolean rateLimited,
            Map<String, Object> extraDetails
    ) {
        var details = new LinkedHashMap<String, Object>();
        details.put("correlationId", correlationId);
        details.put("phase", phase);
        details.put("retryable", retryable);
        details.put("rateLimited", rateLimited);
        details.putAll(extraDetails);
        return new ContractException(status, code, message, details);
    }

    private String normalizeInstallationId(String installationId) {
        var normalized = requireTrimmed(installationId, "installationId");
        if (normalized.length() > 128) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_installation_id", "installationId 过长。", Map.of("phase", "invalid_installation_id"));
        }
        return normalized;
    }

    private String normalizePrompt(String prompt) {
        var normalized = requireTrimmed(prompt, "prompt");
        if (normalized.length() > properties.promptMaxLength()) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "prompt_too_long",
                    "prompt 超过允许长度。",
                    Map.of("phase", "prompt_too_long", "maxLength", properties.promptMaxLength())
            );
        }
        return normalized;
    }

    private int normalizePracticeBabyAgeMonths(int babyAgeMonths) {
        if (babyAgeMonths < 0 || babyAgeMonths > 36) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_baby_age_months",
                    "babyAgeMonths 超出允许范围。",
                    Map.of("phase", "invalid_baby_age_months", "min", 0, "max", 36)
            );
        }
        return babyAgeMonths;
    }

    private String normalizePracticeSceneTag(String sceneTag) {
        if (sceneTag == null || sceneTag.isBlank()) {
            return null;
        }
        var normalized = sceneTag.trim();
        if (normalized.length() > 64) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_sceneTag",
                    "sceneTag 过长。",
                    Map.of("phase", "invalid_sceneTag", "maxLength", 64)
            );
        }
        return normalized;
    }

    private String normalizeAllowed(String value, String fieldName, java.util.List<String> allowedValues) {
        var normalized = requireTrimmed(value, fieldName).toLowerCase(Locale.ROOT);
        var allowed = allowedValues.stream().map(item -> item.toLowerCase(Locale.ROOT)).toList();
        if (!allowed.contains(normalized)) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_" + fieldName,
                    fieldName + " 非法。",
                    Map.of("phase", "invalid_" + fieldName, "allowed", allowedValues)
            );
        }
        return normalized;
    }

    private String normalizeCorrelationId(String correlationId) {
        if (correlationId == null || correlationId.isBlank()) {
            return null;
        }
        var normalized = correlationId.trim();
        if (normalized.length() > 96) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_correlation_id",
                    "correlationId 过长。",
                    Map.of("phase", "invalid_correlation_id")
            );
        }
        return normalized;
    }

    private String normalizeSessionId(String sessionId) {
        var normalized = requireTrimmed(sessionId, "sessionId");
        if (normalized.length() > 128) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_session_id",
                    "sessionId 过长。",
                    Map.of("phase", "invalid_session_id")
            );
        }
        return normalized;
    }

    private String normalizeProviderResponse(String responseText) {
        if (responseText == null || responseText.isBlank()) {
            throw new MentorProvider.ProviderMalformedResponseException("provider 返回空文本。");
        }
        var normalized = responseText.trim();
        if (normalized.length() > properties.responseMaxLength()) {
            throw new MentorProvider.ProviderMalformedResponseException("provider 返回文本超过允许长度。");
        }
        return normalized;
    }

    private String requireTrimmed(String value, String fieldName) {
        if (value == null || value.isBlank()) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "missing_" + fieldName,
                    fieldName + " 不能为空。",
                    Map.of("phase", "missing_" + fieldName)
            );
        }
        return value.trim();
    }

    private boolean isBlockedPrompt(String prompt) {
        var lowerPrompt = prompt.toLowerCase(Locale.ROOT);
        return properties.blockedKeywords().stream()
                .filter(item -> item != null && !item.isBlank())
                .map(item -> item.toLowerCase(Locale.ROOT))
                .anyMatch(lowerPrompt::contains);
    }

    private String buildBlockedFallbackText() {
        return "我先不给出可能伤害宝宝或让关系变糟的做法。先把自己和宝宝都放到安全位置，只说一句：\"I'm here with you.\" 如果你担心安全，请先找身边的大人或专业支持。";
    }

    private String buildRequestSummary(String surface, String mode, String prompt, String contextSummary) {
        var preview = safePreview(prompt);
        var contextLength = contextSummary == null ? 0 : contextSummary.trim().length();
        return trimSummary(
                "surface=%s;mode=%s;prompt.len=%d;prompt.preview=%s;context.present=%s;context.len=%d"
                        .formatted(surface, mode, prompt.length(), preview, contextLength > 0, contextLength)
        );
    }

    private String buildPracticeUserPrompt(int babyAgeMonths, String sceneTag) {
        String userPrompt = "请为 %d 个月大的宝宝生成英语启蒙练习。".formatted(babyAgeMonths);
        if (sceneTag != null) {
            userPrompt += " 场景：%s。".formatted(sceneTag);
        }
        return userPrompt;
    }

    private String summarizeResponse(String responseText) {
        return trimSummary("response.len=%d;preview=%s".formatted(responseText.length(), safePreview(responseText)));
    }

    private String safePreview(String value) {
        var compact = value.replaceAll("\\s+", " ").trim();
        compact = compact.replaceAll("1\\d{10}", "[redacted-phone]");
        compact = compact.replaceAll("(?i)(sess|token|challenge)_[A-Za-z0-9_-]+", "$1_[redacted]");
        compact = compact.replaceAll("\\b\\d{4,8}\\b", "[redacted-code]");
        if (compact.length() <= PREVIEW_MAX_LENGTH) {
            return compact;
        }
        return compact.substring(0, PREVIEW_MAX_LENGTH) + "…";
    }

    private String trimSummary(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        var compact = value.replaceAll("\\s+", " ").trim();
        if (compact.length() <= SUMMARY_MAX_LENGTH) {
            return compact;
        }
        return compact.substring(0, SUMMARY_MAX_LENGTH);
    }

    public record ChatCommand(
            String installationId,
            String prompt,
            String surface,
            String mode,
            String correlationId,
            String contextSummary,
            String conversationId,
            Integer childAgeMonths
    ) {
        public ChatCommand(
                String installationId,
                String prompt,
                String surface,
                String mode,
                String correlationId,
                String contextSummary,
                String conversationId
        ) {
            this(installationId, prompt, surface, mode, correlationId, contextSummary, conversationId, null);
        }
    }

    public record ChatResponse(
            String correlationId,
            String conversationId,
            String responseText,
            String code,
            String phase,
            boolean retryable,
            boolean fallbackUsed,
            boolean authenticated,
            RateLimitStatus rateLimit,
            Instant respondedAt
    ) {
    }

    public record RateLimitStatus(
            boolean limited,
            int limit,
            int remaining,
            long windowSeconds
    ) {
    }

    private record SessionAssociation(
            String accountIdHint,
            String sessionIdHint,
            boolean authenticated
    ) {
        static SessionAssociation anonymous() {
            return new SessionAssociation(null, null, false);
        }
    }

    /**
     * 阶段 1 执行结果：携带后续阶段所需的所有上下文。
     * earlyResponse 非 null 时表示 blocked fallback，直接返回不进入阶段 2/3。
     */
    private record Phase1Result(
            String effectiveCorrelationId,
            String installationId,
            SessionAssociation association,
            String surface,
            String mode,
            String prompt,
            String requestSummary,
            int remaining,
            Instant now,
            String conversationId,
            ChatResponse earlyResponse
    ) {
    }

    // ─── Practice 练习生成 records ───────────────────────

    public record PracticeGenerateCommand(
            String installationId,
            String surface,
            int babyAgeMonths,
            String sceneTag,
            String conversationId
    ) {
    }

    public record PracticeGenerateResponse(
            List<ActivityDto> activities
    ) {
        public static PracticeGenerateResponse empty() {
            return new PracticeGenerateResponse(List.of());
        }
    }

    public record ActivityDto(
            Long activityId,
            String title,
            String summary,
            String sceneTag,
            String coachTip,
            List<PhraseDto> phrases
    ) {
    }

    public record PhraseDto(
            Long phraseId,
            String english,
            String chinese,
            String pronunciation,
            String difficulty
    ) {
    }
}
