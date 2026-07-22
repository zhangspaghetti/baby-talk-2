package com.zhangspaghetti.babytalk.practice.generated;

import cn.hutool.core.util.StrUtil;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGeneratedContentValidator;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGeneratedContentValidator.InvalidGeneratedContentException;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGeneratedContentValidator.RejectedGeneratedContentException;
import com.zhangspaghetti.babytalk.practice.discovery.PolicyTextMatcher;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryCustomSceneProperties;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyProperties;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextCanonicalizer;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextSecurityConfiguration;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextSecurityPolicy;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiProviderManager;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PracticeGeneratedContentService {

    private static final String STATUS_DRAFT = "draft";
    private static final String STATUS_ACTIVE = "active";
    private static final String OWNER_INSTALLATION = "installation";
    private static final String OWNER_ACCOUNT = "account";
    private static final String OWNER_PROFILE = "profile";
    private static final String ERROR_GENERATION_IN_PROGRESS = "generation_in_progress";
    private static final String ERROR_GENERATION_UNAVAILABLE = "generation_unavailable";
    private static final String ERROR_GENERATION_TIMEOUT = "generation_timeout";
    private static final String ERROR_GENERATED_CONTENT_REJECTED = "generated_content_rejected";
    private static final String ERROR_GENERATION_INVALID_OUTPUT = "generation_invalid_output";
    private static final String ERROR_INVALID_CUSTOM_SCENE_TEXT = "invalid_custom_scene_text";
    private static final String ERROR_UNSAFE_CUSTOM_SCENE_TEXT = "unsafe_custom_scene_text";
    private static final String ERROR_UNSUPPORTED_CUSTOM_SCENE_TEXT = "unsupported_custom_scene_text";
    private static final String ERROR_CUSTOM_SCENE_RATE_LIMITED = "custom_scene_rate_limited";
    private static final int MIN_CUSTOM_SCENE_CHARS = 4;
    private static final int MAX_CUSTOM_SCENE_CHARS = 80;
    private static final int MAX_NORMALIZED_SCENE_TEXT_CODE_POINTS = 160;
    private static final int MAX_DRAFT_RESERVATION_ATTEMPTS = 5;
    private static final int CONTENT_REFRESH_EPOCH = 1;
    private static final Duration DRAFT_TTL = Duration.ofMinutes(5);
    private static final Duration INSTALLATION_ACTIVE_RETENTION = Duration.ofDays(30);
    private static final Duration INSTALLATION_TERMINAL_RETENTION = Duration.ofDays(7);
    private static final int MIN_CLEANUP_LIMIT = 1;
    private static final int MAX_CLEANUP_LIMIT = 100;
    private final PracticeGeneratedContentQueryMapper queryMapper;
    private final CustomSceneGenerator generationService;
    private final CustomSceneGeneratedContentValidator generatedContentValidator;
    private final PracticeDiscoveryCustomSceneProperties customSceneProperties;
    private final PracticeDiscoveryPolicyProperties policyProperties;
    private final PracticeGeneratedContentOwnerProperties ownerProperties;
    private final PracticeGeneratedContentKeyFactory keyFactory;
    private final SceneTextCanonicalizer sceneTextCanonicalizer;
    private final SceneTextSecurityPolicy sceneTextSecurityPolicy;
    private final PolicyTextMatcher policyTextMatcher;
    private final Clock clock;
    private final PracticeGeneratedContentCommands commands;
    private final CustomSceneGenerationOrchestrator orchestrator;
    private final VersionedResourceRegistry resourceRegistry;
    private final PracticeAiProviderManager providerManager;

    @Autowired
    public PracticeGeneratedContentService(
            PracticeGeneratedContentQueryMapper queryMapper,
            PracticeGeneratedContentCommands commands,
            CustomSceneGenerator generationService,
            CustomSceneGeneratedContentValidator generatedContentValidator,
            CustomSceneGenerationOrchestrator orchestrator,
            VersionedResourceRegistry resourceRegistry,
            org.springframework.beans.factory.ObjectProvider<PracticeAiProviderManager> providerManager,
            PracticeDiscoveryCustomSceneProperties customSceneProperties,
            PracticeDiscoveryPolicyProperties policyProperties,
            PracticeGeneratedContentOwnerProperties ownerProperties,
            PracticeGeneratedContentKeyFactory keyFactory,
            SceneTextCanonicalizer sceneTextCanonicalizer,
            SceneTextSecurityPolicy sceneTextSecurityPolicy,
            PolicyTextMatcher policyTextMatcher
    ) {
        this(queryMapper, commands, generationService, generatedContentValidator,
                orchestrator, resourceRegistry, providerManager.getIfAvailable(), customSceneProperties,
                policyProperties, Clock.systemUTC(), ownerProperties, keyFactory,
                sceneTextCanonicalizer, sceneTextSecurityPolicy, policyTextMatcher);
    }

    PracticeGeneratedContentService(
            PracticeGeneratedContentQueryMapper queryMapper,
            PracticeGeneratedContentCommands commands,
            CustomSceneGenerator generationService,
            CustomSceneGeneratedContentValidator generatedContentValidator,
            PracticeDiscoveryCustomSceneProperties customSceneProperties,
            PracticeDiscoveryPolicyProperties policyProperties,
            Clock clock,
            PracticeGeneratedContentOwnerProperties ownerProperties
    ) {
        this(queryMapper, commands, generationService, generatedContentValidator, null, null, null, customSceneProperties,
                policyProperties, clock, ownerProperties, new PracticeGeneratedContentKeyFactory(ownerProperties),
                new SceneTextCanonicalizer(),
                new SceneTextSecurityPolicy(policyProperties, new PolicyTextMatcher(new SceneTextCanonicalizer()),
                        SceneTextSecurityConfiguration.configuredSpoofChecker()),
                new PolicyTextMatcher(new SceneTextCanonicalizer()));
    }

    private PracticeGeneratedContentService(
            PracticeGeneratedContentQueryMapper queryMapper,
            PracticeGeneratedContentCommands commands,
            CustomSceneGenerator generationService,
            CustomSceneGeneratedContentValidator generatedContentValidator,
            CustomSceneGenerationOrchestrator orchestrator,
            VersionedResourceRegistry resourceRegistry,
            PracticeAiProviderManager providerManager,
            PracticeDiscoveryCustomSceneProperties customSceneProperties,
            PracticeDiscoveryPolicyProperties policyProperties,
            Clock clock,
            PracticeGeneratedContentOwnerProperties ownerProperties,
            PracticeGeneratedContentKeyFactory keyFactory,
            SceneTextCanonicalizer sceneTextCanonicalizer,
            SceneTextSecurityPolicy sceneTextSecurityPolicy,
            PolicyTextMatcher policyTextMatcher
    ) {
        this.queryMapper = queryMapper;
        this.commands = java.util.Objects.requireNonNull(commands, "practice generated content commands are required");
        this.generationService = generationService;
        this.generatedContentValidator = generatedContentValidator;
        this.orchestrator = orchestrator;
        this.resourceRegistry = resourceRegistry;
        this.providerManager = providerManager;
        this.customSceneProperties = customSceneProperties;
        if (policyProperties == null || ownerProperties == null) {
            throw new IllegalArgumentException("practice generated content typed properties are required");
        }
        this.policyProperties = policyProperties;
        this.ownerProperties = ownerProperties;
        this.keyFactory = java.util.Objects.requireNonNull(keyFactory, "practice generated content key factory is required");
        this.sceneTextCanonicalizer = java.util.Objects.requireNonNull(
                sceneTextCanonicalizer, "scene text canonicalizer is required");
        this.sceneTextSecurityPolicy = java.util.Objects.requireNonNull(
                sceneTextSecurityPolicy, "scene text security policy is required");
        this.policyTextMatcher = java.util.Objects.requireNonNull(
                policyTextMatcher, "policy text matcher is required");
        this.clock = clock;
        var normalizedSecret = ownerProperties.keySecret();
        if (customSceneProperties.enabled()
                && !customSceneProperties.providerDisabled()
                && (normalizedSecret == null || normalizedSecret.getBytes(StandardCharsets.UTF_8).length < 32)) {
            throw new IllegalArgumentException("owner key secret must be explicitly configured with at least 32 bytes");
        }
    }

    public DraftReservation reserveDraft(PracticeGeneratedContentEntity entity) {
        return commands.reserveDraft(entity, reservationPolicy(entity.ownerScope()));
    }

    public Optional<PracticeGeneratedContentEntity> activateDraft(PracticeGeneratedContentEntity entity) {
        return commands.activate(entity);
    }

    public void rejectDraft(String generatedContentId, String generationErrorCode, OffsetDateTime updatedAt) {
        commands.reject(
                generatedContentId,
                generationErrorCode,
                false,
                updatedAt,
                updatedAt.plus(INSTALLATION_TERMINAL_RETENTION));
    }

    public void expireDraft(String generatedContentId, String generationErrorCode, OffsetDateTime updatedAt) {
        commands.expire(
                generatedContentId,
                generationErrorCode,
                true,
                updatedAt,
                updatedAt.plus(INSTALLATION_TERMINAL_RETENTION));
    }

    public Optional<PracticeGeneratedContentEntity> findActiveOrPromotedByGeneratedContentId(String generatedContentId) {
        return Optional.ofNullable(queryMapper.findActiveByGeneratedContentId(
                generatedContentId, ownerKeyVersion(), nowUtc()));
    }

    public Optional<PracticeGeneratedContentEntity> findActiveOrPromotedByFingerprint(
            String ownerKey,
            String surface,
            String mode,
            String requestFingerprint,
            String promptVersion,
            String strategyVersion
    ) {
        return Optional.ofNullable(queryMapper.findActiveByFingerprint(
                ownerKey,
                ownerKeyVersion(),
                surface,
                mode,
                requestFingerprint,
                promptVersion,
                CONTENT_REFRESH_EPOCH,
                nowUtc()));
    }

    public int countRecentGenerationAttempts(String ownerKey, String surface, String mode, OffsetDateTime createdAtFrom) {
        return queryMapper.countRecentDraftReservations(
                ownerKey, ownerKeyVersion(), surface, mode, createdAtFrom);
    }

    public List<PracticeGeneratedContentEntity> findInstallationCleanupCandidates(
            String installationRefHash,
            OffsetDateTime retentionExpiresAtOrBefore,
            int limit
    ) {
        return queryMapper.findInstallationCleanupCandidates(
                ownerKeyVersion(), installationRefHash, retentionExpiresAtOrBefore, boundCleanupLimit(limit));
    }

    @Transactional
    public int deleteExpiredInstallationRows(OffsetDateTime retentionExpiresAtOrBefore, int limit) {
        return commands.deleteExpiredInstallationRows(
                retentionExpiresAtOrBefore, boundCleanupLimit(limit));
    }

    @Transactional
    public int expireStaleDrafts(OffsetDateTime generationExpiresAtOrBefore, int limit) {
        var now = generationExpiresAtOrBefore.withOffsetSameInstant(ZoneOffset.UTC);
        return commands.interruptStaleExecutions(
                now,
                now.plus(INSTALLATION_TERMINAL_RETENTION),
                boundCleanupLimit(limit));
    }

    @Transactional
    public int deleteAccountOwned(String accountId) {
        return commands.deleteAccountOwned(accountId);
    }

    public void requireCustomSceneGenerationAvailable() {
        if (!customSceneProperties.enabled() || customSceneProperties.providerDisabled()) {
            throw generationUnavailable("provider_disabled");
        }
    }

    public PracticeGeneratedContentEntity generateCustomScene(
            CustomSceneDiscoveryRequest request
    ) {
        requireCustomSceneGenerationAvailable();
        var forms = sceneTextCanonicalizer.derive(request.customSceneText());
        sceneTextSecurityPolicy.requireSafe(forms);
        var normalizedSceneText = validateDisplayLength(forms.displayText());
        var owner = resolveOwner(request);
        var requestFingerprint = fingerprint(request, owner, forms.securityText());
        var existing = queryMapper.findLiveByFingerprint(
                owner.ownerKey(),
                ownerKeyVersion(),
                request.surface(),
                request.mode(),
                requestFingerprint,
                generationProfileVersion(),
                CONTENT_REFRESH_EPOCH);
        var firstReservationAttempt = isDueInstallationActive(existing) ? 1 : 0;
        if (existing != null) {
            if (isActiveOrPromoted(existing)) {
                if (isReusableActiveOrPromoted(existing)) {
                    return existing;
                }
            } else if (!isExpiredDraft(existing)) {
                throw generationInProgress(existing.generatedContentId());
            }
        }
        for (var offset = 0; offset < MAX_DRAFT_RESERVATION_ATTEMPTS; offset++) {
            var reservationAttempt = firstReservationAttempt + offset;
            var draft = draftRow(
                    request, owner, requestFingerprint, normalizedSceneText,
                    reservationAttempt);
            DraftReservation reservation;
            try {
                reservation = reserveDraft(draft);
            } catch (GeneratedContentIdConflictException exception) {
                continue;
            } catch (PracticeGenerationRateLimitExceededException exception) {
                var window = customSceneProperties.burstWindow();
                throw rateLimited(
                        owner.ownerScope(), exception.limit(), exception.windowName(), window);
            }

            var reserved = reservation.content();
            if (isActiveOrPromoted(reserved)) {
                return reserved;
            }
            if (!STATUS_DRAFT.equals(reserved.status())) {
                throw generationInProgress(reserved.generatedContentId());
            }
            if (!reservation.created()) {
                if (isExpiredDraft(reserved)) {
                    expireDraft(reserved.generatedContentId(), "draft_expired");
                    continue;
                }
                throw generationInProgress(reserved.generatedContentId());
            }
            return generateAndActivate(request, owner, requestFingerprint, normalizedSceneText, reserved);
        }

        throw generationInProgress(generatedContentId(owner, requestFingerprint, firstReservationAttempt));
    }

    private ReservationPolicy reservationPolicy(String ownerScope) {
        var now = nowUtc();
        var caps = rateLimitCaps(ownerScope);
        return new ReservationPolicy(
                now,
                now.minus(customSceneProperties.burstWindow()),
                caps.burstLimit(),
                now.plus(INSTALLATION_TERMINAL_RETENTION));
    }

    private PracticeGeneratedContentEntity executeOrchestratedGeneration(
            PracticeGeneratedContentEntity reserved,
            OwnerContext owner
    ) {
        var registry = java.util.Objects.requireNonNull(resourceRegistry, "versioned resource registry is required");
        var profile = registry.currentGenerationProfile();
        var caps = rateLimitCaps(owner.ownerScope());
        try {
            var result = orchestrator.execute(new CustomSceneGenerationOrchestrator.GenerationExecution(
                    reserved,
                    nowUtc().minus(customSceneProperties.dailyWindow()),
                    caps.dailyLimit(),
                    profile,
                    registry.qualityRubric(),
                    java.util.Set.copyOf(registry.minimumEvidencePolicy().requiredClaimCoverage()),
                    contentConstraints()));
            if (STATUS_ACTIVE.equals(result.status())) {
                return result;
            }
            throw terminalGenerationFailure(result);
        } catch (PracticeGenerationRateLimitExceededException exception) {
            throw rateLimited(owner.ownerScope(), caps.dailyLimit(), "daily", customSceneProperties.dailyWindow());
        } catch (CustomSceneGenerationOrchestrator.GenerationExecutionException exception) {
            throw generationUnavailable(exception.code(), exception.retryable(), exception);
        }
    }

    private PracticeGeneratedContentEntity generateAndActivate(
            CustomSceneDiscoveryRequest request,
            OwnerContext owner,
            String requestFingerprint,
            String normalizedSceneText,
            PracticeGeneratedContentEntity reserved
    ) {

        if (orchestrator != null) {
            return executeOrchestratedGeneration(reserved, owner);
        }

        var caps = rateLimitCaps(owner.ownerScope());
        var startDecision = commands.startGeneration(
                reserved.generatedContentId(),
                nowUtc().minus(customSceneProperties.dailyWindow()),
                caps.dailyLimit(),
                nowUtc());
        if (startDecision == GenerationStartDecision.DAILY_LIMIT_EXCEEDED) {
            expireDraft(reserved.generatedContentId(), "generation_rate_limited");
            throw rateLimited(
                    owner.ownerScope(), caps.dailyLimit(), "daily", customSceneProperties.dailyWindow());
        }
        if (startDecision != GenerationStartDecision.STARTED) {
            throw generationInProgress(reserved.generatedContentId());
        }

        CustomSceneGenerator.GeneratedPracticeContentCandidate candidate;
        try {
            candidate = generationService.generate(new CustomSceneGenerator.GeneratorRequest(
                    reserved.generatedContentId(),
                    1,
                    normalizedSceneText,
                    request.ageRange(),
                    request.parentGoal(),
                    request.locale(),
                    null,
                    null,
                    contentConstraints()
            ));
        } catch (CustomSceneGenerator.GenerationUnavailableException exception) {
            if (exception.retryable()) {
                bestEffortExpireDraft(reserved.generatedContentId(), exception.reason(), exception);
            } else {
                bestEffortRejectDraft(reserved.generatedContentId(), exception.reason(), exception);
            }
            throw generationUnavailable(exception.reason(), exception.retryable(), exception);
        } catch (CustomSceneGenerator.GenerationTimeoutException exception) {
            bestEffortExpireDraft(reserved.generatedContentId(), ERROR_GENERATION_TIMEOUT, exception);
            throw generationTimeout(exception);
        } catch (RuntimeException exception) {
            bestEffortExpireDraft(reserved.generatedContentId(), "provider_failure", exception);
            throw generationUnavailable("provider_failure", true, exception);
        }

        var validated = validateGeneratedOutput(reserved.generatedContentId(), candidate, normalizedSceneText);
        try {
            var activated = activateDraft(activeRow(reserved, validated, requestFingerprint))
                    .or(() -> findActiveOrPromotedByFingerprint(
                            owner.ownerKey(),
                            request.surface(),
                            request.mode(),
                            requestFingerprint,
                            generationProfileVersion(),
                            strategyVersion()))
                    .orElseThrow(() -> generationInProgress(reserved.generatedContentId()));
            if (!isActiveOrPromoted(activated)) {
                throw generationInProgress(activated.generatedContentId());
            }
            return activated;
        } catch (ContractException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            bestEffortExpireDraft(reserved.generatedContentId(), "activation_failure", exception);
            throw generationUnavailable("activation_failure", true, exception);
        }
    }

    private CustomSceneGenerator.GeneratedPracticeContentCandidate validateGeneratedOutput(
            String generatedContentId,
            CustomSceneGenerator.GeneratedPracticeContentCandidate candidate,
            String normalizedSceneText
    ) {
        try {
            return generatedContentValidator.normalizeAndValidate(
                    candidate,
                    contentConstraints(),
                    new CustomSceneGeneratedContentValidator.GeneratedOutputValidationContext(normalizedSceneText)
            );
        } catch (RejectedGeneratedContentException exception) {
            bestEffortRejectDraft(generatedContentId, ERROR_GENERATED_CONTENT_REJECTED, exception);
            var contract = new ContractException(
                    HttpStatus.UNPROCESSABLE_ENTITY,
                    ERROR_GENERATED_CONTENT_REJECTED,
                    "生成内容不适合展示。",
                    Map.of("reason", exception.reason())
            );
            contract.initCause(exception);
            throw contract;
        } catch (InvalidGeneratedContentException exception) {
            bestEffortRejectDraft(generatedContentId, ERROR_GENERATION_INVALID_OUTPUT, exception);
            var contract = new ContractException(
                    HttpStatus.BAD_GATEWAY,
                    ERROR_GENERATION_INVALID_OUTPUT,
                    "生成内容结构不合法。",
                    Map.of("field", exception.fieldName(), "retryable", false)
            );
            contract.initCause(exception);
            throw contract;
        } catch (RuntimeException exception) {
            bestEffortExpireDraft(generatedContentId, "validation_failure", exception);
            throw generationUnavailable("validation_failure", true, exception);
        }
    }

    private CustomSceneGenerator.ContentConstraints contentConstraints() {
        return customSceneProperties.fakeProvider()
                ? CustomSceneGenerator.ContentConstraints.fakeProviderDefaults()
                : CustomSceneGenerator.ContentConstraints.defaults();
    }

    private PracticeGeneratedContentEntity draftRow(
            CustomSceneDiscoveryRequest request,
            OwnerContext owner,
            String requestFingerprint,
            String normalizedSceneText,
            int reservationAttempt
    ) {
        var now = nowUtc();
        var row = new PracticeGeneratedContentEntity();
        row.setGeneratedContentId(generatedContentId(owner, requestFingerprint, reservationAttempt));
        row.setOwnerScope(owner.ownerScope());
        row.setOwnerKey(owner.ownerKey());
        row.setOwnerKeyVersion(ownerKeyVersion());
        row.setAccountId(owner.accountId());
        row.setInstallationRefHash(owner.installationRefHash());
        row.setProfileId(owner.profileId());
        row.setSurface(request.surface());
        row.setMode(request.mode());
        row.setRequestFingerprint(requestFingerprint);
        row.setNormalizedSceneText(normalizedSceneText);
        row.setAgeRange(request.ageRange());
        row.setParentGoal(request.parentGoal());
        row.setLocale(request.locale());
        row.setStatus(STATUS_DRAFT);
        row.setGenerationProfileVersion(generationProfileVersion());
        row.setGenerationProfileHash(generationProfileHash());
        row.setRubricVersion(rubricVersion());
        row.setRubricContentHash(rubricContentHash());
        row.setEvidencePolicyVersion(evidencePolicyVersion());
        row.setEvidencePolicyContentHash(evidencePolicyContentHash());
        var routingVersion = providerManager == null ? "legacy-fake-routing-v1" : providerManager.routingPolicyVersion();
        var routingHash = providerManager == null
                ? keyFactory.stableDigest("provider-routing|" + routingVersion)
                : providerManager.routingPolicyHash();
        row.setProviderRoutingPolicyVersion(routingVersion);
        row.setProviderRoutingPolicyHash(routingHash);
        row.setGenerationAttemptLimit(customSceneProperties.maxGenerationAttempts());
        row.setContentRefreshEpoch(CONTENT_REFRESH_EPOCH);
        row.setContentVersion(1);
        row.setGenerationExpiresAt(now.plus(DRAFT_TTL));
        row.setRetentionExpiresAt(OWNER_INSTALLATION.equals(owner.ownerScope())
                ? now.plus(INSTALLATION_ACTIVE_RETENTION)
                : null);
        row.setCreatedAt(now);
        row.setUpdatedAt(now);
        return row;
    }

    private PracticeGeneratedContentEntity activeRow(
            PracticeGeneratedContentEntity draft,
            CustomSceneGenerator.GeneratedPracticeContentCandidate candidate,
            String requestFingerprint
    ) {
        var slugHash = keyFactory.stableDigest(
                draft.ownerKey() + "|" + requestFingerprint + "|" + promptVersion() + "|"
                        + strategyVersion() + "|" + draft.generatedContentId());
        var now = nowUtc();
        var row = new PracticeGeneratedContentEntity();
        row.setGeneratedContentId(draft.generatedContentId());
        row.setOwnerScope(draft.ownerScope());
        row.setOwnerKey(draft.ownerKey());
        row.setOwnerKeyVersion(draft.ownerKeyVersion());
        row.setAccountId(draft.accountId());
        row.setInstallationRefHash(draft.installationRefHash());
        row.setProfileId(draft.profileId());
        row.setSurface(draft.surface());
        row.setMode(draft.mode());
        row.setRequestFingerprint(draft.requestFingerprint());
        row.setAgeRange(draft.ageRange());
        row.setParentGoal(draft.parentGoal());
        row.setLocale(draft.locale());
        row.setSpaceSlug("gen_scene_" + slugHash.substring(0, 20));
        row.setActivitySlug("gen_activity_" + slugHash.substring(20, 40));
        row.setPhraseSlug("gen_phrase_" + slugHash.substring(40, 60));
        row.setSpaceTitleZh(candidate.spaceTitleZh());
        row.setActivityTitleZh(candidate.activityTitleZh());
        row.setSceneTagEn(candidate.sceneTagEn());
        row.setTprActionZh(candidate.tprActionZh());
        row.setDeliveryGuidanceZh(candidate.deliveryGuidanceZh());
        row.setEnglishText(candidate.englishText());
        row.setChineseText(candidate.chineseText());
        row.setPronunciationHint(candidate.pronunciationHint());
        row.setDifficulty(candidate.difficulty());
        row.setGenerationSource(candidate.generationSource());
        row.setStatus(STATUS_ACTIVE);
        row.setGenerationProfileVersion(draft.generationProfileVersion());
        row.setGenerationProfileHash(draft.generationProfileHash());
        row.setRubricVersion(draft.rubricVersion());
        row.setRubricContentHash(draft.rubricContentHash());
        row.setEvidencePolicyVersion(draft.evidencePolicyVersion());
        row.setEvidencePolicyContentHash(draft.evidencePolicyContentHash());
        row.setProviderRoutingPolicyVersion(draft.providerRoutingPolicyVersion());
        row.setProviderRoutingPolicyHash(draft.providerRoutingPolicyHash());
        row.setGenerationAttemptLimit(draft.generationAttemptLimit());
        row.setContentRefreshEpoch(draft.contentRefreshEpoch());
        row.setContentVersion(draft.contentVersion());
        row.setRetentionExpiresAt(OWNER_INSTALLATION.equals(draft.ownerScope())
                ? now.plus(INSTALLATION_ACTIVE_RETENTION)
                : null);
        row.setCreatedAt(draft.createdAt());
        row.setUpdatedAt(now);
        return row;
    }

    private OwnerContext resolveOwner(CustomSceneDiscoveryRequest request) {
        if (trimToNull(request.profileId()) != null) {
            var accountId = trimToNull(request.accountId());
            if (accountId == null) {
                throw new ContractException(
                        HttpStatus.BAD_REQUEST,
                        "invalid_generated_content_owner",
                        "profile owner 缺少 accountId。"
                );
            }
            return new OwnerContext(
                    OWNER_PROFILE,
                    keyFactory.ownerKey(OWNER_PROFILE, accountId + ":" + request.profileId()),
                    accountId,
                    null,
                    request.profileId()
            );
        }

        var accountId = trimToNull(request.accountId());
        if (accountId != null) {
            return new OwnerContext(
                    OWNER_ACCOUNT,
                    keyFactory.ownerKey(OWNER_ACCOUNT, accountId),
                    accountId,
                    null,
                    null
            );
        }

        var installationId = trimToNull(request.installationId());
        if (installationId == null) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_installation_id",
                    "installationId 不合法。",
                    Map.of("field", "installationId")
            );
        }
        return new OwnerContext(
                OWNER_INSTALLATION,
                keyFactory.ownerKey(OWNER_INSTALLATION, installationId),
                null,
                keyFactory.installationRefHash(installationId),
                null
        );
    }

    private String fingerprint(CustomSceneDiscoveryRequest request, OwnerContext owner, String securitySceneText) {
        return keyFactory.requestFingerprint(
                owner.ownerKey(),
                new PracticeGeneratedContentKeyFactory.RequestFingerprintMaterial(
                        request.surface(),
                        request.mode(),
                        securitySceneText,
                        request.ageRange(),
                        request.parentGoal(),
                        request.locale(),
                        generationProfileVersion(),
                        rubricVersion(),
                        evidencePolicyVersion(),
                        CONTENT_REFRESH_EPOCH));
    }

    private String generatedContentId(OwnerContext owner, String requestFingerprint, int reservationAttempt) {
        var base = "pgc_" + keyFactory.stableDigest(owner.ownerKey()
                + "|" + requestFingerprint
                + "|" + generationProfileVersion()
                + "|" + generationProfileStrategyVersion()).substring(0, 32);
        if (reservationAttempt == 0) {
            return base;
        }
        return base + "_" + keyFactory.stableDigest(
                base + "|retry=" + reservationAttempt + "|" + UUID.randomUUID()).substring(0, 8);
    }

    private String promptVersion() {
        return customSceneProperties.promptVersion();
    }

    private String generationProfileVersion() {
        return resourceRegistry == null
                ? promptVersion()
                : resourceRegistry.currentGenerationProfile().version();
    }

    private String generationProfileHash() {
        return resourceRegistry == null
                ? keyFactory.stableDigest("generation-profile|" + promptVersion())
                : resourceRegistry.currentGenerationProfile().contentHash();
    }

    private String generationProfileStrategyVersion() {
        return resourceRegistry == null
                ? strategyVersion()
                : resourceRegistry.currentGenerationProfile().strategyVersion();
    }

    private String rubricVersion() {
        return resourceRegistry == null
                ? policyVersion()
                : resourceRegistry.qualityRubric().version();
    }

    private String rubricContentHash() {
        return resourceRegistry == null
                ? keyFactory.stableDigest("rubric|" + policyVersion())
                : resourceRegistry.qualityRubric().contentHash();
    }

    private String evidencePolicyVersion() {
        return resourceRegistry == null
                ? strategyVersion()
                : resourceRegistry.minimumEvidencePolicy().version();
    }

    private String evidencePolicyContentHash() {
        return resourceRegistry == null
                ? keyFactory.stableDigest("evidence-policy|" + strategyVersion())
                : resourceRegistry.minimumEvidencePolicy().contentHash();
    }

    private String strategyVersion() {
        return customSceneProperties.strategyVersion();
    }

    private String policyVersion() {
        return policyProperties.policyVersion();
    }

    private String ownerKeyVersion() {
        return ownerProperties.keyVersion();
    }

    private String validateDisplayLength(String displayText) {
        if (displayText == null) {
            throw invalidCustomSceneText();
        }
        var length = sceneTextCanonicalizer.graphemeLength(displayText);
        if (length < MIN_CUSTOM_SCENE_CHARS || length > MAX_CUSTOM_SCENE_CHARS) {
            throw invalidCustomSceneText();
        }
        if (sceneTextCanonicalizer.codePointLength(displayText) > MAX_NORMALIZED_SCENE_TEXT_CODE_POINTS) {
            throw invalidCustomSceneText();
        }
        if (policyTextMatcher.containsAny(displayText, policyProperties.unsupportedIntents())) {
            throw unsupportedCustomSceneText("unsupported_intent");
        }
        return displayText;
    }

    private ContractException invalidCustomSceneText() {
        return new ContractException(
                HttpStatus.BAD_REQUEST,
                ERROR_INVALID_CUSTOM_SCENE_TEXT,
                "customSceneText 长度不合法。",
                Map.of("min", MIN_CUSTOM_SCENE_CHARS, "max", MAX_CUSTOM_SCENE_CHARS)
        );
    }

    private ContractException unsupportedCustomSceneText(String reason) {
        return new ContractException(
                HttpStatus.BAD_REQUEST,
                ERROR_UNSUPPORTED_CUSTOM_SCENE_TEXT,
                "customSceneText 需要是照护场景。",
                Map.of("reason", reason)
        );
    }

    private void rejectDraft(String generatedContentId, String generationErrorCode) {
        rejectDraft(generatedContentId, generationErrorCode, nowUtc());
    }

    private void expireDraft(String generatedContentId, String generationErrorCode) {
        expireDraft(generatedContentId, generationErrorCode, nowUtc());
    }

    private ContractException generationInProgress(String generatedContentId) {
        return new ContractException(
                HttpStatus.CONFLICT,
                ERROR_GENERATION_IN_PROGRESS,
                "该自定义场景正在生成。",
                Map.of("generatedContentId", generatedContentId, "retryable", true)
        );
    }

    private ContractException generationUnavailable(String reason) {
        return generationUnavailable(reason, false, null);
    }

    private ContractException generationUnavailable(String reason, boolean retryable, RuntimeException cause) {
        var contract = new ContractException(
                HttpStatus.SERVICE_UNAVAILABLE,
                ERROR_GENERATION_UNAVAILABLE,
                "自定义场景生成暂不可用。",
                Map.of(
                        "retryable", retryable,
                        "suggestCatalogFallback", true,
                        "reason", reason
                )
        );
        if (cause != null) {
            contract.initCause(cause);
        }
        return contract;
    }

    private ContractException terminalGenerationFailure(PracticeGeneratedContentEntity result) {
        var reason = result.generationErrorCode() == null ? "generation_terminal" : result.generationErrorCode();
        if ("rejected".equals(result.status()) && isInvalidOutputTerminal(reason)) {
            return new ContractException(
                    HttpStatus.BAD_GATEWAY,
                    ERROR_GENERATION_INVALID_OUTPUT,
                    "生成内容结构不合法。",
                    Map.of("retryable", false, "suggestCatalogFallback", true)
            );
        }
        if (ERROR_GENERATION_TIMEOUT.equals(reason)) {
            return generationTimeout(null);
        }
        return generationUnavailable(reason, !Boolean.FALSE.equals(result.generationErrorRetryable()), null);
    }

    private boolean isInvalidOutputTerminal(String reason) {
        return switch (reason) {
            case ERROR_GENERATION_INVALID_OUTPUT,
                    "terminal_output_violation", "generation_attempts_exhausted", "judge_rejected" -> true;
            default -> false;
        };
    }

    private void bestEffortExpireDraft(String generatedContentId, String errorCode, RuntimeException originalFailure) {
        try {
            expireDraft(generatedContentId, errorCode);
        } catch (RuntimeException cleanupFailure) {
            originalFailure.addSuppressed(cleanupFailure);
        }
    }

    private void bestEffortRejectDraft(String generatedContentId, String errorCode, RuntimeException originalFailure) {
        try {
            rejectDraft(generatedContentId, errorCode);
        } catch (RuntimeException cleanupFailure) {
            originalFailure.addSuppressed(cleanupFailure);
        }
    }

    private ContractException generationTimeout(RuntimeException cause) {
        var contract = new ContractException(
                HttpStatus.GATEWAY_TIMEOUT,
                ERROR_GENERATION_TIMEOUT,
                "自定义场景生成超时。",
                Map.of("retryable", true, "suggestCatalogFallback", true)
        );
        if (cause != null) {
            contract.initCause(cause);
        }
        return contract;
    }

    private ContractException rateLimited(String ownerScope, int limit, String windowName, Duration window) {
        var windowSeconds = window.toSeconds();
        return new ContractException(
                HttpStatus.TOO_MANY_REQUESTS,
                ERROR_CUSTOM_SCENE_RATE_LIMITED,
                "自定义场景生成次数过多，请稍后再试。",
                Map.of(
                        "scope", ownerScope,
                        "limit", limit,
                        "window", windowName,
                        "windowSeconds", windowSeconds,
                        "retryAfterSeconds", windowSeconds
                )
        );
    }

    private RateLimitCaps rateLimitCaps(String ownerScope) {
        if (OWNER_INSTALLATION.equals(ownerScope)) {
            return new RateLimitCaps(
                    customSceneProperties.installationBurstLimit(),
                    customSceneProperties.installationDailyLimit());
        }
        return new RateLimitCaps(
                customSceneProperties.accountBurstLimit(),
                customSceneProperties.accountDailyLimit());
    }

    private int boundCleanupLimit(int limit) {
        return Math.max(MIN_CLEANUP_LIMIT, Math.min(MAX_CLEANUP_LIMIT, limit));
    }

    private boolean isActiveOrPromoted(PracticeGeneratedContentEntity row) {
        return STATUS_ACTIVE.equals(row.status());
    }

    private boolean isReusableActiveOrPromoted(PracticeGeneratedContentEntity row) {
        return isActiveOrPromoted(row)
                && (!"installation".equals(row.ownerScope())
                || (row.retentionExpiresAt() != null && row.retentionExpiresAt().isAfter(nowUtc())));
    }

    private boolean isExpiredDraft(PracticeGeneratedContentEntity row) {
        return STATUS_DRAFT.equals(row.status())
                && row.generationExpiresAt() != null
                && !row.generationExpiresAt().isAfter(nowUtc());
    }

    private boolean isDueInstallationActive(PracticeGeneratedContentEntity row) {
        return row != null
                && OWNER_INSTALLATION.equals(row.ownerScope())
                && STATUS_ACTIVE.equals(row.status())
                && row.retentionExpiresAt() != null
                && !row.retentionExpiresAt().isAfter(nowUtc());
    }

    private String trimToNull(String value) {
        return StrUtil.trimToNull(value);
    }

    private OffsetDateTime nowUtc() {
        return OffsetDateTime.now(clock).withOffsetSameInstant(ZoneOffset.UTC);
    }

    public record CustomSceneDiscoveryRequest(
            String surface,
            String mode,
            String installationId,
            String accountId,
            String profileId,
            String ageRange,
            String parentGoal,
            String locale,
            String customSceneText
    ) {
    }

    private record OwnerContext(
            String ownerScope,
            String ownerKey,
            String accountId,
            String installationRefHash,
            String profileId
    ) {
    }

    private record RateLimitCaps(
            int burstLimit,
            int dailyLimit
    ) {
    }

}
