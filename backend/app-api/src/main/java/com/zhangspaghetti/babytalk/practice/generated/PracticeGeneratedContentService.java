package com.zhangspaghetti.babytalk.practice.generated;

import cn.hutool.core.util.StrUtil;
import com.zhangspaghetti.babytalk.practice.discovery.SceneGeneratedContentValidator;
import com.zhangspaghetti.babytalk.practice.discovery.SceneGeneratedContentValidator.InvalidGeneratedContentException;
import com.zhangspaghetti.babytalk.practice.discovery.SceneGeneratedContentValidator.RejectedGeneratedContentException;
import com.zhangspaghetti.babytalk.practice.discovery.PolicyTextMatcher;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryCustomSceneProperties;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyProperties;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextCanonicalizer;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextSecurityConfiguration;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextSecurityPolicy;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiProviderManager;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.practice.scene.GenerationSubject;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
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
    private static final String OWNER_PROFILE = "profile";
    private static final String SOURCE_CUSTOM = "custom";
    private static final String SOURCE_PRESET = "preset";
    private static final String SCENE_GENERATION_SURFACE = "care_path";
    private static final String SCENE_GENERATION_MODE = "scene_generation";
    private static final String ERROR_GENERATION_IN_PROGRESS = "generation_in_progress";
    private static final String ERROR_GENERATION_UNAVAILABLE = "generation_unavailable";
    private static final String ERROR_GENERATION_TIMEOUT = "generation_timeout";
    private static final String ERROR_GENERATED_CONTENT_REJECTED = "generated_content_rejected";
    private static final String ERROR_GENERATION_INVALID_OUTPUT = "generation_invalid_output";
    private static final String ERROR_LEGACY_ACTIVE_BUNDLE_UNSUPPORTED = "legacy_active_bundle_unsupported";
    private static final String ERROR_INVALID_CUSTOM_SCENE_TEXT = "invalid_custom_scene_text";
    private static final String ERROR_UNSAFE_CUSTOM_SCENE_TEXT = "unsafe_custom_scene_text";
    private static final String ERROR_UNSUPPORTED_CUSTOM_SCENE_TEXT = "unsupported_custom_scene_text";
    private static final String ERROR_CUSTOM_SCENE_RATE_LIMITED = "custom_scene_rate_limited";
    private static final String ERROR_INVALID_CLIENT_REQUEST_ID = "invalid_client_request_id";
    private static final String ERROR_CLIENT_REQUEST_ID_CONFLICT = "client_request_id_conflict";
    private static final String ERROR_CLIENT_REQUEST_TERMINAL = "client_request_terminal";
    private static final int MIN_CUSTOM_SCENE_CHARS = 4;
    private static final int MAX_CUSTOM_SCENE_CHARS = 80;
    private static final int MAX_NORMALIZED_SCENE_TEXT_CODE_POINTS = 160;
    private static final int MAX_PRESET_SCENE_TEXT_CODE_POINTS = 1200;
    private static final int MAX_CLIENT_REQUEST_ID_CHARS = 96;
    private static final int MAX_DRAFT_RESERVATION_ATTEMPTS = 5;
    private static final int CONTENT_REFRESH_EPOCH = 1;
    private static final Duration INSTALLATION_ACTIVE_RETENTION = Duration.ofDays(30);
    private static final Duration INSTALLATION_TERMINAL_RETENTION = Duration.ofDays(7);
    private static final int MIN_CLEANUP_LIMIT = 1;
    private static final int MAX_CLEANUP_LIMIT = 100;
    private static final Pattern SAFE_CLIENT_REQUEST_ID_PATTERN = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,95}$");
    private static final Pattern PHONE_LIKE_PATTERN = Pattern.compile("\\d{11,}");
    private static final Pattern SAFE_STABLE_ID_PATTERN = Pattern.compile("^[a-z0-9][a-z0-9_-]{0,95}$");
    private static final Pattern INSTALLATION_REF_HASH_PATTERN = Pattern.compile("^installation_[0-9a-f]{64}$");
    private final PracticeGeneratedContentQueryMapper queryMapper;
    private final SceneContentGenerator generationService;
    private final SceneGeneratedContentValidator generatedContentValidator;
    private final PracticeDiscoveryCustomSceneProperties customSceneProperties;
    private final PracticeDiscoveryPolicyProperties policyProperties;
    private final PracticeGeneratedContentOwnerProperties ownerProperties;
    private final PracticeGeneratedContentKeyFactory keyFactory;
    private final SceneTextCanonicalizer sceneTextCanonicalizer;
    private final SceneTextSecurityPolicy sceneTextSecurityPolicy;
    private final PolicyTextMatcher policyTextMatcher;
    private final Clock clock;
    private final PracticeGeneratedContentCommands commands;
    private final SceneGenerationOrchestrator orchestrator;
    private final VersionedResourceRegistry resourceRegistry;
    private final PracticeAiProviderManager providerManager;

    @Autowired
    public PracticeGeneratedContentService(
            PracticeGeneratedContentQueryMapper queryMapper,
            PracticeGeneratedContentCommands commands,
            SceneContentGenerator generationService,
            SceneGeneratedContentValidator generatedContentValidator,
            SceneGenerationOrchestrator orchestrator,
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
            SceneContentGenerator generationService,
            SceneGeneratedContentValidator generatedContentValidator,
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
            SceneContentGenerator generationService,
            SceneGeneratedContentValidator generatedContentValidator,
            SceneGenerationOrchestrator orchestrator,
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
        return Optional.ofNullable(requireSupportedActive(queryMapper.findActiveByGeneratedContentId(
                generatedContentId, ownerKeyVersion(), nowUtc())));
    }

    public List<com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity>
    findApprovedUtterances(String generatedContentId) {
        var utterances = queryMapper.findApprovedUtterances(generatedContentId);
        return utterances == null ? List.of() : List.copyOf(utterances);
    }

    private PracticeGeneratedContentEntity findByClientRequestId(OwnerContext owner, String clientRequestId) {
        if (clientRequestId == null) {
            return null;
        }
        return queryMapper.findByClientRequestId(
                owner.ownerScope(), owner.ownerKey(), ownerKeyVersion(), clientRequestId);
    }

    private PracticeGeneratedContentEntity reconcileClientRequest(
            PracticeGeneratedContentEntity existing,
            String clientRequestFingerprint
    ) {
        if (!clientRequestFingerprint.equals(existing.clientRequestFingerprint())) {
            throw clientRequestConflict(existing.generatedContentId());
        }
        if (isActiveOrPromoted(existing)) {
            requireSupportedActive(existing);
            if (isReusableActiveOrPromoted(existing)) {
                return existing;
            }
            throw terminalClientRequest(existing);
        }
        if (isTerminal(existing)) {
            throw terminalClientRequest(existing);
        }
        throw generationInProgress(existing.generatedContentId());
    }

    public Optional<PracticeGeneratedContentEntity> findActiveOrPromotedByFingerprint(
            String ownerKey,
            String surface,
            String mode,
            String requestFingerprint,
            String promptVersion,
            String strategyVersion
    ) {
        return Optional.ofNullable(requireSupportedActive(queryMapper.findActiveByFingerprint(
                ownerKey,
                ownerKeyVersion(),
                surface,
                mode,
                requestFingerprint,
                promptVersion,
                CONTENT_REFRESH_EPOCH,
                nowUtc())));
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

    /**
     * Source-neutral generation seam. Custom and published-preset inputs share
     * reservation, cache, quota, orchestration, validation, repair, and
     * persistence behavior through this method.
     */
    public PracticeGeneratedContentEntity generateScene(SceneGenerationInput input) {
        requireCustomSceneGenerationAvailable();
        Objects.requireNonNull(input, "scene generation input");
        validateUnifiedInput(input);
        var owner = resolveProfileOwner(input.subject());
        return generateScene(input, owner, SCENE_GENERATION_SURFACE, SCENE_GENERATION_MODE);
    }

    private void validateUnifiedInput(SceneGenerationInput input) {
        var source = input.inputSource();
        if (!SOURCE_CUSTOM.equals(source) && !SOURCE_PRESET.equals(source)) {
            throw invalidSceneInput("unsupported_source");
        }
        var subject = input.subject();
        var personalization = input.personalization();
        if (subject == null || personalization == null) {
            throw invalidSceneInput("missing_subject_context");
        }
        if (trimToNull(subject.ownerAccountId()) == null
                || trimToNull(subject.profileId()) == null
                || subject.profileVersion() < 0
                || trimToNull(subject.ageRange()) == null
                || trimToNull(subject.parentGoal()) == null
                || trimToNull(subject.actorRole()) == null
                || trimToNull(personalization.ageRange()) == null
                || trimToNull(personalization.parentGoal()) == null
                || trimToNull(personalization.locale()) == null
                || trimToNull(personalization.actorRole()) == null
                || trimToNull(personalization.householdContextVersion()) == null) {
            throw invalidSceneInput("invalid_subject");
        }
        if (!Objects.equals(subject.babyName(), personalization.babyName())
                || !Objects.equals(subject.ageRange(), personalization.ageRange())
                || !Objects.equals(subject.parentGoal(), personalization.parentGoal())
                || !Objects.equals(subject.actorRole(), personalization.actorRole())
                || trimToNull(input.locale()) == null
                || !Objects.equals(input.locale(), personalization.locale())) {
            throw invalidSceneInput("subject_context_mismatch");
        }
        if (trimToNull(input.installationId()) == null) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_installation_id",
                    "installationId 不合法。",
                    Map.of("field", "installationId"));
        }
        if (SOURCE_PRESET.equals(source)) {
            if (input.presetActivityId() == null
                    || input.presetSceneVersionId() == null
                    || input.presetActivityId() < 1
                    || input.presetSceneVersionId() < 1
                    || !isSafeStableId(input.stableSpaceId())
                    || !isSafeStableId(input.stableActivityId())) {
                throw invalidSceneInput("invalid_preset_identity");
            }
        } else if (input.presetActivityId() != null
                || input.presetSceneVersionId() != null
                || trimToNull(input.stableSpaceId()) != null
                || trimToNull(input.stableActivityId()) != null) {
            throw invalidSceneInput("mixed_source_identity");
        }
        if (trimToNull(input.resolvedSceneText()) == null) {
            throw invalidSceneInput("resolved_source_missing");
        }
    }

    private PracticeGeneratedContentEntity generateScene(
            SceneGenerationInput input,
            OwnerContext owner,
            String surface,
            String mode
    ) {
        var prepared = prepareSceneInput(input, owner, surface, mode);
        return generateScene(input, owner, prepared);
    }

    private PracticeGeneratedContentEntity generateScene(
            SceneGenerationInput input,
            OwnerContext owner,
            PreparedScene prepared
    ) {
        var requestFingerprint = prepared.requestFingerprint();
        var clientRequestId = prepared.clientRequestId();
        var clientRequestFingerprint = prepared.clientRequestFingerprint();
        var requestReservation = findByClientRequestId(owner, clientRequestId);
        if (requestReservation != null) {
            return reconcileClientRequest(requestReservation, clientRequestFingerprint);
        }
        var existing = queryMapper.findLiveByFingerprint(
                owner.ownerKey(),
                ownerKeyVersion(),
                prepared.surface(),
                prepared.mode(),
                requestFingerprint,
                generationProfileVersion(),
                CONTENT_REFRESH_EPOCH);
        requireSupportedActive(existing);
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
                    input, owner, prepared,
                    reservationAttempt, clientRequestId, clientRequestFingerprint);
            DraftReservation reservation;
            try {
                reservation = reserveDraft(draft);
            } catch (GeneratedContentIdConflictException exception) {
                continue;
            } catch (PracticeGenerationRateLimitExceededException exception) {
                var window = customSceneProperties.burstWindow();
                throw rateLimited(owner.ownerScope(), exception.limit(), exception.windowName(), window);
            }

            var reserved = reservation.content();
            if (clientRequestId != null && !clientRequestFingerprint.equals(reserved.clientRequestFingerprint())) {
                throw clientRequestConflict(reserved.generatedContentId());
            }
            if (isActiveOrPromoted(reserved)) {
                requireSupportedActive(reserved);
                if (clientRequestId != null && !isReusableActiveOrPromoted(reserved)) {
                    throw terminalClientRequest(reserved);
                }
                return reserved;
            }
            if (isTerminal(reserved)) {
                throw terminalClientRequest(reserved);
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
            return generateAndActivate(input, owner, prepared, reserved);
        }
        throw generationInProgress(generatedContentId(owner, requestFingerprint, firstReservationAttempt));
    }

    private PreparedScene prepareSceneInput(
            SceneGenerationInput input,
            OwnerContext owner,
            String surface,
            String mode
    ) {
        Objects.requireNonNull(input, "scene generation input");
        var forms = sceneTextCanonicalizer.derive(input.resolvedSceneText());
        sceneTextSecurityPolicy.requireSafe(forms);
        var normalizedSceneText = SOURCE_CUSTOM.equals(input.inputSource())
                ? validateDisplayLength(forms.displayText())
                : validatePresetSceneText(forms.displayText());
        var context = GenerationRequestContext.from(input.personalization());
        var unified = SCENE_GENERATION_MODE.equals(mode);
        var profile = input.subject();
        var contentIdentity = SOURCE_CUSTOM.equals(input.inputSource())
                ? "custom:" + keyFactory.stableDigest(forms.securityText())
                : "preset:" + input.presetActivityId() + ":" + input.presetSceneVersionId();
        var requestFingerprint = unified
                ? keyFactory.requestFingerprint(
                        owner.ownerKey(),
                        new PracticeGeneratedContentKeyFactory.SceneFingerprintMaterial(
                                input.inputSource(),
                                contentIdentity,
                                profile.profileId(),
                                profile.profileVersion(),
                                input.personalization().householdContextVersion(),
                                generationProfileVersion(),
                                generationPromptVersion(),
                                generationProfileStrategyVersion(),
                                rubricVersion(),
                                evidencePolicyVersion(),
                                CONTENT_REFRESH_EPOCH))
                : keyFactory.requestFingerprint(
                        owner.ownerKey(),
                        new PracticeGeneratedContentKeyFactory.RequestFingerprintMaterial(
                                surface,
                                mode,
                                forms.securityText(),
                                context.ageRange(),
                                context.parentGoal(),
                                context.locale(),
                                generationProfileVersion(),
                                rubricVersion(),
                                evidencePolicyVersion(),
                                CONTENT_REFRESH_EPOCH));
        var clientRequestId = validateClientRequestId(input.clientRequestId(), SCENE_GENERATION_SURFACE.equals(surface));
        var clientRequestFingerprint = clientRequestId == null
                ? null
                : unified
                ? keyFactory.sceneGenerationClientRequestFingerprint(
                        owner.ownerKey(),
                        new PracticeGeneratedContentKeyFactory.SceneClientRequestFingerprintMaterial(
                                input.inputSource(),
                                contentIdentity,
                                profile.profileId(),
                                profile.profileVersion(),
                                input.personalization().householdContextVersion(),
                                context.locale()))
                : keyFactory.clientRequestFingerprint(
                        owner.ownerKey(),
                        new PracticeGeneratedContentKeyFactory.ClientRequestFingerprintMaterial(
                                surface,
                                mode,
                                forms.securityText(),
                                context.ageRange(),
                                context.parentGoal(),
                                context.locale()));
        var installationId = trimToNull(input.installationId());
        var installationRefHash = installationId == null ? null : keyFactory.installationRefHash(installationId);
        if (unified && !INSTALLATION_REF_HASH_PATTERN.matcher(
                Objects.requireNonNull(installationRefHash, "installationRefHash")).matches()) {
            throw invalidSceneInput("invalid_installation_ref");
        }
        var persistenceSceneText = SOURCE_CUSTOM.equals(input.inputSource())
                ? normalizedSceneText
                : "preset:" + input.presetActivityId() + ":" + input.presetSceneVersionId();
        return new PreparedScene(
                normalizedSceneText,
                persistenceSceneText,
                contentIdentity,
                requestFingerprint,
                clientRequestId,
                clientRequestFingerprint,
                context,
                installationRefHash,
                surface,
                mode);
    }

    private String validatePresetSceneText(String displayText) {
        if (displayText == null || displayText.isBlank()
                || sceneTextCanonicalizer.codePointLength(displayText) > MAX_PRESET_SCENE_TEXT_CODE_POINTS) {
            throw invalidSceneInput("invalid_preset_text");
        }
        if (policyTextMatcher.containsAny(displayText, policyProperties.unsupportedIntents())) {
            throw invalidSceneInput("unsupported_preset_text");
        }
        return displayText;
    }

    private boolean isSafeStableId(String value) {
        return value != null && SAFE_STABLE_ID_PATTERN.matcher(value).matches();
    }

    private ContractException invalidSceneInput(String reason) {
        return new ContractException(
                HttpStatus.BAD_REQUEST,
                "invalid_scene_input",
                "场景生成输入不合法。",
                Map.of("reason", reason));
    }

    private OwnerContext resolveProfileOwner(GenerationSubject subject) {
        var accountId = trimToNull(subject.ownerAccountId());
        var profileId = trimToNull(subject.profileId());
        if (accountId == null || profileId == null || subject.profileVersion() < 0) {
            throw invalidSceneInput("invalid_subject");
        }
        return new OwnerContext(
                OWNER_PROFILE,
                keyFactory.ownerKey(OWNER_PROFILE, accountId + ":" + profileId),
                accountId,
                null,
                profileId);
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
            OwnerContext owner,
            PreparedScene prepared,
            SceneGenerationInput input
    ) {
        var registry = java.util.Objects.requireNonNull(resourceRegistry, "versioned resource registry is required");
        var profile = registry.currentGenerationProfile();
        var caps = rateLimitCaps(owner.ownerScope());
        try {
            var result = orchestrator.execute(new SceneGenerationOrchestrator.GenerationExecution(
                    reserved,
                    nowUtc().minus(customSceneProperties.dailyWindow()),
                    caps.dailyLimit(),
                    profile,
                    registry.qualityRubric(),
                    java.util.Set.copyOf(registry.minimumEvidencePolicy().requiredClaimCoverage()),
                    contentConstraints(),
                    prepared.normalizedSceneText(),
                    input.stableSpaceId(),
                    input.stableActivityId(),
                    prepared.context()));
            if (STATUS_ACTIVE.equals(result.status())) {
                return result;
            }
            throw terminalGenerationFailure(result);
        } catch (PracticeGenerationRateLimitExceededException exception) {
            throw rateLimited(owner.ownerScope(), caps.dailyLimit(), "daily", customSceneProperties.dailyWindow());
        } catch (SceneGenerationOrchestrator.GenerationExecutionException exception) {
            throw generationUnavailable(exception.code(), exception.retryable(), exception);
        }
    }

    private PracticeGeneratedContentEntity generateAndActivate(
            SceneGenerationInput input,
            OwnerContext owner,
            PreparedScene prepared,
            PracticeGeneratedContentEntity reserved
    ) {

        if (orchestrator != null) {
            return executeOrchestratedGeneration(reserved, owner, prepared, input);
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

        GeneratedCareMomentBundle careMoment;
        try {
            careMoment = generationService.generateCareMoment(new SceneContentGenerator.GeneratorRequest(
                    reserved.generatedContentId(),
                    1,
                    prepared.normalizedSceneText(),
                    input.stableActivityId(),
                    prepared.context().ageRange(),
                    prepared.context().parentGoal(),
                    prepared.context().locale(),
                    null,
                    null,
                    contentConstraints(),
                    prepared.context()
            ));
        } catch (SceneContentGenerator.GenerationUnavailableException exception) {
            if (exception.retryable()) {
                bestEffortExpireDraft(reserved.generatedContentId(), exception.reason(), exception);
            } else {
                bestEffortRejectDraft(reserved.generatedContentId(), exception.reason(), exception);
            }
            throw generationUnavailable(exception.reason(), exception.retryable(), exception);
        } catch (SceneContentGenerator.GenerationTimeoutException exception) {
            bestEffortExpireDraft(reserved.generatedContentId(), ERROR_GENERATION_TIMEOUT, exception);
            throw generationTimeout(exception);
        } catch (RuntimeException exception) {
            bestEffortExpireDraft(reserved.generatedContentId(), "provider_failure", exception);
            throw generationUnavailable("provider_failure", true, exception);
        }

        if (careMoment == null) {
            bestEffortRejectDraft(reserved.generatedContentId(), ERROR_GENERATION_INVALID_OUTPUT,
                    new IllegalStateException("complete bundle is required"));
            throw generationUnavailable(ERROR_GENERATION_INVALID_OUTPUT, false,
                    new IllegalStateException("complete bundle is required"));
        }
        var validated = validateGeneratedBundle(
                reserved.generatedContentId(), careMoment, prepared.normalizedSceneText());
        try {
            var activated = activateDraft(activeRow(reserved, validated, prepared, input))
                    .or(() -> findActiveOrPromotedByFingerprint(
                            owner.ownerKey(),
                            prepared.surface(),
                            prepared.mode(),
                            prepared.requestFingerprint(),
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

    private GeneratedCareMomentBundle validateGeneratedBundle(
            String generatedContentId,
            GeneratedCareMomentBundle bundle,
            String normalizedSceneText
    ) {
        try {
            return bundle.mapCandidates(candidate -> generatedContentValidator.normalizeAndValidate(
                    candidate, contentConstraints(),
                    new SceneGeneratedContentValidator.GeneratedOutputValidationContext(normalizedSceneText)));
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

    private SceneContentGenerator.ContentConstraints contentConstraints() {
        return customSceneProperties.fakeProvider()
                ? SceneContentGenerator.ContentConstraints.fakeProviderDefaults()
                : SceneContentGenerator.ContentConstraints.defaults();
    }

    private PracticeGeneratedContentEntity draftRow(
            SceneGenerationInput input,
            OwnerContext owner,
            PreparedScene prepared,
            int reservationAttempt,
            String clientRequestId,
            String clientRequestFingerprint
    ) {
        var now = nowUtc();
        var row = new PracticeGeneratedContentEntity();
        row.setGeneratedContentId(generatedContentId(owner, prepared.requestFingerprint(), reservationAttempt));
        row.setOwnerScope(owner.ownerScope());
        row.setOwnerKey(owner.ownerKey());
        row.setOwnerKeyVersion(ownerKeyVersion());
        row.setAccountId(owner.accountId());
        row.setInstallationRefHash(owner.installationRefHash());
        row.setProfileId(owner.profileId());
        row.setSurface(prepared.surface());
        row.setMode(prepared.mode());
        row.setInputSource(input.inputSource());
        row.setPresetActivityId(input.presetActivityId());
        row.setPresetSceneVersionId(input.presetSceneVersionId());
        row.setProfileVersion(OWNER_PROFILE.equals(owner.ownerScope())
                ? input.subject().profileVersion()
                : null);
        row.setHouseholdContextVersion(input.personalization().householdContextVersion());
        row.setRequestFingerprint(prepared.requestFingerprint());
        row.setClientRequestId(clientRequestId);
        row.setClientRequestFingerprint(clientRequestFingerprint);
        row.setNormalizedSceneText(prepared.persistenceSceneText());
        row.setAgeRange(prepared.context().ageRange());
        row.setParentGoal(prepared.context().parentGoal());
        row.setLocale(prepared.context().locale());
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
        row.setGenerationExpiresAt(now.plus(customSceneProperties.generationLease()));
        row.setRetentionExpiresAt(OWNER_INSTALLATION.equals(owner.ownerScope())
                ? now.plus(INSTALLATION_ACTIVE_RETENTION)
                : null);
        row.setCreatedAt(now);
        row.setUpdatedAt(now);
        return row;
    }

    private PracticeGeneratedContentEntity activeRow(
            PracticeGeneratedContentEntity draft,
            GeneratedCareMomentBundle careMoment,
            PreparedScene prepared,
            SceneGenerationInput input
    ) {
        var candidate = careMoment.starter();
        var slugHash = keyFactory.stableDigest(
                draft.ownerKey() + "|" + prepared.requestFingerprint() + "|" + generationPromptVersion() + "|"
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
        row.setInputSource(draft.inputSource());
        row.setPresetActivityId(draft.presetActivityId());
        row.setPresetSceneVersionId(draft.presetSceneVersionId());
        row.setProfileVersion(draft.profileVersion());
        row.setHouseholdContextVersion(draft.householdContextVersion());
        row.setRequestFingerprint(draft.requestFingerprint());
        row.setClientRequestId(draft.clientRequestId());
        row.setClientRequestFingerprint(draft.clientRequestFingerprint());
        row.setNormalizedSceneText(SOURCE_CUSTOM.equals(input.inputSource())
                ? prepared.normalizedSceneText()
                : null);
        row.setAgeRange(draft.ageRange());
        row.setParentGoal(draft.parentGoal());
        row.setLocale(draft.locale());
        row.setSpaceSlug(SOURCE_PRESET.equals(input.inputSource())
                ? input.stableSpaceId()
                : "gen_scene_" + slugHash.substring(0, 20));
        row.setActivitySlug(SOURCE_PRESET.equals(input.inputSource())
                ? input.stableActivityId()
                : "gen_activity_" + slugHash.substring(20, 40));
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
        row.setApprovedUtterances(toApprovedUtterances(row, careMoment));
        return row;
    }

    private List<com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity>
    toApprovedUtterances(PracticeGeneratedContentEntity active, GeneratedCareMomentBundle careMoment) {
        var rows = new ArrayList<com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity>();
        rows.add(utterance(active, "starter", null, 1, careMoment.starterUtterance()));
        for (var reaction : GeneratedCareMomentBundle.ReactionType.values()) {
            rows.add(utterance(active, "reaction_support", reaction.wireValue(), reaction.ordinal() + 2,
                    careMoment.reactionSupports().get(reaction)));
        }
        return List.copyOf(rows);
    }

    private com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity utterance(
            PracticeGeneratedContentEntity active,
            String role,
            String reactionType,
            int displayOrder,
            GeneratedCareUtterance content
    ) {
        var row = new com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity();
        var identity = active.generatedContentId() + "|" + role + "|" + (reactionType == null ? "starter" : reactionType);
        row.setUtteranceId("starter".equals(role)
                ? active.phraseSlug()
                : "gen_utt_" + keyFactory.stableDigest(identity).substring(0, 48));
        row.setGeneratedContentId(active.generatedContentId());
        row.setRole(role);
        row.setReactionType(reactionType);
        row.setEnglishText(content.englishText());
        row.setChineseText(content.chineseText());
        row.setPronunciationHint(content.pronunciationHint());
        row.setTprActionZh(content.tprActionZh());
        row.setDeliveryGuidanceZh(content.deliveryGuidanceZh());
        row.setDifficulty(content.difficulty());
        row.setDisplayOrder(displayOrder);
        row.setApprovalStatus("approved");
        row.setApprovedContentVersion(active.contentVersion());
        row.setBundleSchemaVersion(
                com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION);
        row.setProviderOrigin(content.providerProvenance().origin().wireValue());
        row.setProviderName(content.providerProvenance().providerName());
        row.setProviderModelName(content.providerProvenance().modelName());
        row.setProviderAttemptNumber(content.providerProvenance().attemptNumber());
        row.setCreatedAt(active.updatedAt());
        return row;
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

    private String generationPromptVersion() {
        return resourceRegistry == null
                ? promptVersion()
                : resourceRegistry.currentGenerationProfile().generatorPrompt().version();
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

    private String validateClientRequestId(String raw, boolean required) {
        var normalized = trimToNull(raw);
        if (normalized == null) {
            if (required) {
                throw invalidClientRequestId();
            }
            return null;
        }
        if (!normalized.equals(raw)
                || normalized.length() > MAX_CLIENT_REQUEST_ID_CHARS
                || !SAFE_CLIENT_REQUEST_ID_PATTERN.matcher(normalized).matches()
                || PHONE_LIKE_PATTERN.matcher(normalized).find()) {
            throw invalidClientRequestId();
        }
        return normalized;
    }

    private ContractException invalidClientRequestId() {
        return new ContractException(
                HttpStatus.BAD_REQUEST,
                ERROR_INVALID_CLIENT_REQUEST_ID,
                "clientRequestId 不合法。",
                Map.of("field", "clientRequestId")
        );
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

    private ContractException clientRequestConflict(String generatedContentId) {
        return new ContractException(
                HttpStatus.CONFLICT,
                ERROR_CLIENT_REQUEST_ID_CONFLICT,
                "clientRequestId 已绑定到不同请求。",
                Map.of("generatedContentId", generatedContentId)
        );
    }

    private ContractException terminalClientRequest(PracticeGeneratedContentEntity row) {
        return new ContractException(
                HttpStatus.CONFLICT,
                ERROR_CLIENT_REQUEST_TERMINAL,
                "该请求已结束；重试请使用新的 clientRequestId。",
                Map.of(
                        "generatedContentId", row.generatedContentId(),
                        "requiresNewClientRequestId", true,
                        "retryable", Boolean.TRUE.equals(row.generationErrorRetryable()))
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
        if ("rejected".equals(result.status()) && ERROR_GENERATED_CONTENT_REJECTED.equals(reason)) {
            return new ContractException(
                    HttpStatus.UNPROCESSABLE_ENTITY,
                    ERROR_GENERATED_CONTENT_REJECTED,
                    "生成内容不适合展示。",
                    Map.of("retryable", false, "suggestCatalogFallback", true)
            );
        }
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

    /**
     * V29/V30 rows can be active but have no V31 provenance-bearing bundle. Quarantine them before
     * any reuse or discovery response; never infer missing branches or provenance.
     */
    private PracticeGeneratedContentEntity requireSupportedActive(PracticeGeneratedContentEntity row) {
        if (row == null || !STATUS_ACTIVE.equals(row.status())) {
            return row;
        }
        if (hasCompleteSupportedBundle(queryMapper.findApprovedUtterances(row.generatedContentId()))) {
            return row;
        }
        var now = nowUtc();
        commands.quarantineUnsupportedActive(
                row.generatedContentId(), now, now.plus(INSTALLATION_TERMINAL_RETENTION));
        throw generationUnavailable(ERROR_LEGACY_ACTIVE_BUNDLE_UNSUPPORTED, true, null);
    }

    private boolean hasCompleteSupportedBundle(
            List<com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity> rows
    ) {
        if (rows == null || rows.size() != GeneratedCareMomentBundle.UTTERANCE_COUNT) {
            return false;
        }
        try {
            var utterances = rows.stream().map(row -> new com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle.Utterance(
                    com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle.UtteranceRole
                            .fromWireValue(row.role()),
                    row.reactionType() == null ? null
                            : com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle.Reaction
                                    .fromWireValue(row.reactionType()),
                    row.englishText(), row.chineseText(), row.pronunciationHint(), row.tprActionZh(),
                    row.deliveryGuidanceZh(), row.difficulty(), row.displayOrder(),
                    new com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle.ProviderProvenance(
                            com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle.ProviderOrigin
                                    .fromWireValue(row.providerOrigin()),
                            row.providerName(), row.providerModelName(), row.providerAttemptNumber())))
                    .toList();
            new com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle(
                    com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION,
                    new com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle.SceneMetadata(
                            "verified", "verified", "verified"),
                    utterances);
            return true;
        } catch (RuntimeException exception) {
            return false;
        }
    }

    private boolean isExpiredDraft(PracticeGeneratedContentEntity row) {
        return STATUS_DRAFT.equals(row.status())
                && row.generationExpiresAt() != null
                && !row.generationExpiresAt().isAfter(nowUtc());
    }

    private boolean isTerminal(PracticeGeneratedContentEntity row) {
        return "rejected".equals(row.status()) || "expired".equals(row.status());
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

    private record PreparedScene(
            String normalizedSceneText,
            String persistenceSceneText,
            String contentIdentity,
            String requestFingerprint,
            String clientRequestId,
            String clientRequestFingerprint,
            GenerationRequestContext context,
            String installationRefHash,
            String surface,
            String mode
    ) {
        private PreparedScene {
            Objects.requireNonNull(normalizedSceneText, "normalizedSceneText");
            Objects.requireNonNull(persistenceSceneText, "persistenceSceneText");
            Objects.requireNonNull(contentIdentity, "contentIdentity");
            Objects.requireNonNull(requestFingerprint, "requestFingerprint");
            Objects.requireNonNull(context, "context");
            Objects.requireNonNull(surface, "surface");
            Objects.requireNonNull(mode, "mode");
        }
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
