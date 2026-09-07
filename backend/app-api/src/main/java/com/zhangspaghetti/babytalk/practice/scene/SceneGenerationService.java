package com.zhangspaghetti.babytalk.practice.scene;

import cn.hutool.core.util.StrUtil;
import com.zhangspaghetti.babytalk.practice.discovery.PolicyTextMatcher;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyProperties;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextCanonicalizer;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextForms;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextSecurityPolicy;
import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentService;
import com.zhangspaghetti.babytalk.practice.generated.SceneGenerationInput;
import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity;
import com.zhangspaghetti.babytalk.practice.preset.PresetSceneCatalogService;
import com.zhangspaghetti.babytalk.profile.HouseholdBabyProfileAccessService;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/** Orchestrates one server-owned, source-neutral scene generation request. */
@Service
public class SceneGenerationService {

    private static final String SOURCE_CUSTOM = "custom";
    private static final String SOURCE_PRESET = "preset";
    private static final String LOCALE_ZH_CN = "zh-CN";
    private static final String BUNDLE_SCHEMA = CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION;
    private static final int MIN_CUSTOM_TEXT_GRAPHEMES = 4;
    private static final int MAX_CUSTOM_TEXT_GRAPHEMES = 80;
    private static final int MAX_SCENE_TEXT_CODE_POINTS = 160;
    private static final int MAX_PRESET_BRIEF_CODE_POINTS = 1200;
    private static final Pattern SAFE_INSTALLATION_ID = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$");
    private static final Pattern SAFE_CLIENT_REQUEST_ID = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,95}$");
    private static final Pattern PHONE_LIKE = Pattern.compile("\\d{11,}");
    private static final Pattern SAFE_STABLE_ID = Pattern.compile("^[a-z0-9][a-z0-9_-]{0,95}$");
    private static final Set<String> REACTIONS = Set.of(
            "cooperating", "hesitant", "resisting", "no_response", "other");

    private final HouseholdBabyProfileAccessService profileAccess;
    private final ScenePersonalizationContextService personalization;
    private final PresetSceneCatalogService catalog;
    private final PracticeGeneratedContentService generatedContent;
    private final SceneTextCanonicalizer canonicalizer;
    private final SceneTextSecurityPolicy securityPolicy;
    private final PracticeDiscoveryPolicyProperties policyProperties;
    private final PolicyTextMatcher policyTextMatcher;
    private final Clock clock;

    @Autowired
    public SceneGenerationService(
            HouseholdBabyProfileAccessService profileAccess,
            ScenePersonalizationContextService personalization,
            PresetSceneCatalogService catalog,
            PracticeGeneratedContentService generatedContent,
            SceneTextCanonicalizer canonicalizer,
            SceneTextSecurityPolicy securityPolicy,
            PracticeDiscoveryPolicyProperties policyProperties,
            PolicyTextMatcher policyTextMatcher
    ) {
        this(profileAccess, personalization, catalog, generatedContent, canonicalizer, securityPolicy,
                policyProperties, policyTextMatcher, Clock.systemUTC());
    }

    /** Small constructor keeps the source-resolution seam easy to exercise in unit tests. */
    public SceneGenerationService(
            HouseholdBabyProfileAccessService profileAccess,
            ScenePersonalizationContextService personalization,
            PresetSceneCatalogService catalog,
            PracticeGeneratedContentService generatedContent,
            SceneTextCanonicalizer canonicalizer,
            SceneTextSecurityPolicy securityPolicy
    ) {
        this(profileAccess, personalization, catalog, generatedContent, canonicalizer, securityPolicy,
                null, null, Clock.systemUTC());
    }

    SceneGenerationService(
            HouseholdBabyProfileAccessService profileAccess,
            ScenePersonalizationContextService personalization,
            PresetSceneCatalogService catalog,
            PracticeGeneratedContentService generatedContent,
            SceneTextCanonicalizer canonicalizer,
            SceneTextSecurityPolicy securityPolicy,
            PracticeDiscoveryPolicyProperties policyProperties,
            PolicyTextMatcher policyTextMatcher,
            Clock clock
    ) {
        this.profileAccess = Objects.requireNonNull(profileAccess, "profileAccess");
        this.personalization = Objects.requireNonNull(personalization, "personalization");
        this.catalog = Objects.requireNonNull(catalog, "catalog");
        this.generatedContent = Objects.requireNonNull(generatedContent, "generatedContent");
        this.canonicalizer = Objects.requireNonNull(canonicalizer, "canonicalizer");
        this.securityPolicy = Objects.requireNonNull(securityPolicy, "securityPolicy");
        this.policyProperties = policyProperties;
        this.policyTextMatcher = policyTextMatcher;
        this.clock = Objects.requireNonNull(clock, "clock");
    }

    public SceneGenerationResponse generate(SceneGenerationRequest request, String sessionId) {
        requireRequestShape(request);

        // HouseholdBabyProfileAccessService performs accepted-session validation before profile lookup.
        var subject = Objects.requireNonNull(profileAccess.resolve(sessionId), "resolved generation subject");
        var source = resolveSource(request.source());
        validateRequestMetadata(request);
        var context = Objects.requireNonNull(
                personalization.build(subject, request.locale(), OffsetDateTime.now(clock)),
                "personalization context");
        var input = new SceneGenerationInput(
                source.inputSource(),
                source.resolvedText(),
                subject,
                context,
                source.preset() == null ? null : source.preset().activityId(),
                source.preset() == null ? null : source.preset().versionId(),
                source.preset() == null ? null : source.preset().spaceId(),
                source.preset() == null ? null : source.preset().presetSceneId(),
                request.locale(),
                request.installationId(),
                request.clientRequestId());
        var row = Objects.requireNonNull(generatedContent.generateScene(input), "generated content");
        return toResponse(row, source);
    }

    private void requireRequestShape(SceneGenerationRequest request) {
        if (request == null || request.source() == null
                || request.locale() == null
                || request.installationId() == null
                || request.clientRequestId() == null) {
            throw invalidSceneSourceContract();
        }
    }

    private ResolvedSource resolveSource(SceneGenerationRequest.SourceRequest source) {
        if (source == null || source.type() == null) {
            throw invalidSceneSourceContract();
        }
        if (SOURCE_CUSTOM.equals(source.type())) {
            if (source.text() == null || source.presetSceneId() != null) {
                throw invalidSceneSourceContract();
            }
            return new ResolvedSource(SOURCE_CUSTOM, safeCustomText(source.text()), null);
        }
        if (SOURCE_PRESET.equals(source.type())) {
            if (source.presetSceneId() == null || source.text() != null) {
                throw invalidSceneSourceContract();
            }
            return resolvePreset(source.presetSceneId());
        }
        throw invalidSceneSourceContract();
    }

    private String safeCustomText(String rawText) {
        try {
            var forms = canonicalizer.derive(rawText);
            requireSafeText(forms);
            var displayText = forms.displayText();
            if (displayText == null
                    || canonicalizer.graphemeLength(displayText) < MIN_CUSTOM_TEXT_GRAPHEMES
                    || canonicalizer.graphemeLength(displayText) > MAX_CUSTOM_TEXT_GRAPHEMES
                    || canonicalizer.codePointLength(displayText) > MAX_SCENE_TEXT_CODE_POINTS
                    || (policyProperties != null
                    && policyTextMatcher.containsAny(displayText, policyProperties.unsupportedIntents()))) {
                throw invalidCustomSceneText();
            }
            return displayText;
        } catch (ContractException exception) {
            throw invalidCustomSceneText();
        } catch (RuntimeException exception) {
            throw invalidCustomSceneText();
        }
    }

    private ResolvedSource resolvePreset(String presetSceneId) {
        final PresetSceneCatalogService.PublishedPresetScene preset;
        try {
            preset = catalog.requirePublished(presetSceneId);
        } catch (ContractException exception) {
            if (HttpStatus.NOT_FOUND.equals(exception.status())) {
                throw presetUnavailable();
            }
            throw exception;
        }
        if (preset == null
                || !presetSceneId.equals(preset.presetSceneId())
                || !isPositive(preset.activityId())
                || !isPositive(preset.versionId())
                || preset.publishedVersion() < 1
                || !isSafeStableId(preset.spaceId())
                || !isSafeStableId(preset.presetSceneId())) {
            throw presetUnavailable();
        }
        var forms = canonicalizer.derive(preset.generationBrief());
        if (forms == null || forms.displayText() == null) {
            throw presetUnavailable();
        }
        try {
            securityPolicy.requireSafe(forms);
        } catch (ContractException exception) {
            throw presetUnavailable();
        }
        var brief = forms.displayText();
        if (canonicalizer.codePointLength(brief) > MAX_PRESET_BRIEF_CODE_POINTS
                || (policyProperties != null
                && policyTextMatcher.containsAny(brief, policyProperties.unsupportedIntents()))) {
            throw presetUnavailable();
        }
        return new ResolvedSource(SOURCE_PRESET, brief, preset);
    }

    private void requireSafeText(SceneTextForms forms) {
        if (forms == null || forms.displayText() == null) {
            throw invalidCustomSceneText();
        }
        securityPolicy.requireSafe(forms);
    }

    private void validateRequestMetadata(SceneGenerationRequest request) {
        if (!LOCALE_ZH_CN.equals(request.locale())) {
            throw invalidSceneSourceContract();
        }
        if (!request.installationId().equals(StrUtil.trimToNull(request.installationId()))
                || !SAFE_INSTALLATION_ID.matcher(request.installationId()).matches()
                || PHONE_LIKE.matcher(request.installationId()).find()) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_installation_id",
                    "installationId 不合法。",
                    Map.of("field", "installationId"));
        }
        if (!request.clientRequestId().equals(StrUtil.trimToNull(request.clientRequestId()))
                || !SAFE_CLIENT_REQUEST_ID.matcher(request.clientRequestId()).matches()
                || PHONE_LIKE.matcher(request.clientRequestId()).find()) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_client_request_id",
                    "clientRequestId 不合法。",
                    Map.of("field", "clientRequestId"));
        }
    }

    private SceneGenerationResponse toResponse(
            PracticeGeneratedContentEntity row,
            ResolvedSource source
    ) {
        if (row == null) {
            throw invalidGeneratedOutput();
        }
        var utterances = row.approvedUtterances();
        if (utterances == null || utterances.isEmpty()) {
            utterances = generatedContent.findApprovedUtterances(row.generatedContentId());
        }
        requireCompleteBundle(row, utterances);
        var starterRow = utterances.stream()
                .filter(value -> "starter".equals(value.role()) && value.reactionType() == null)
                .findFirst()
                .orElseThrow(this::invalidGeneratedOutput);
        var supportRows = utterances.stream()
                .filter(value -> "reaction_support".equals(value.role()))
                .sorted(Comparator.comparingInt(PracticeGeneratedContentUtteranceEntity::displayOrder))
                .toList();

        var expectedSpace = source.preset() == null ? row.spaceSlug() : source.preset().spaceId();
        var expectedActivity = source.preset() == null ? row.activitySlug() : source.preset().presetSceneId();
        var expectedScene = requireStableRouteId(expectedSpace);
        var expectedMoment = requireStableRouteId(expectedActivity);
        var phraseId = requireStableRouteId(row.phraseSlug());
        var route = new SceneGenerationResponse.RouteView(
                expectedScene, expectedScene, expectedMoment, expectedMoment, phraseId);
        var scene = new SceneGenerationResponse.SceneView(
                requireText(row.spaceTitleZh()), requireText(row.activityTitleZh()), requireText(row.sceneTagEn()));
        var starter = toUtteranceView(starterRow, phraseId);
        var supports = supportRows.stream().map(value -> toUtteranceView(value, value.utteranceId())).toList();
        var preset = source.preset();
        var sourceView = new SceneGenerationResponse.SourceView(
                source.inputSource(),
                preset == null ? null : preset.presetSceneId(),
                preset == null ? null : preset.publishedVersion());
        try {
            return new SceneGenerationResponse(
                    requireText(row.generatedContentId()), BUNDLE_SCHEMA, route, scene, starter, supports, sourceView);
        } catch (RuntimeException exception) {
            throw invalidGeneratedOutput();
        }
    }

    private void requireCompleteBundle(
            PracticeGeneratedContentEntity row,
            List<PracticeGeneratedContentUtteranceEntity> utterances
    ) {
        if (row == null || utterances == null || utterances.size() != 6) {
            throw invalidGeneratedOutput();
        }
        var reactions = new HashSet<String>();
        var utteranceIds = new HashSet<String>();
        var starterCount = 0;
        for (var value : utterances) {
            if (value == null || !utteranceIds.add(value.utteranceId())
                    || !Objects.equals(row.generatedContentId(), value.generatedContentId())
                    || !"approved".equals(value.approvalStatus())
                    || value.approvedContentVersion() != row.contentVersion()
                    || !BUNDLE_SCHEMA.equals(value.bundleSchemaVersion())
                    || !("provider_generated".equals(value.providerOrigin())
                    || "provider_repaired".equals(value.providerOrigin()))
                    || StrUtil.isBlank(value.providerName())
                    || StrUtil.isBlank(value.providerModelName())
                    || value.providerAttemptNumber() < 1
                    || value.providerAttemptNumber() > 5) {
                throw invalidGeneratedOutput();
            }
            if ("starter".equals(value.role())) {
                if (++starterCount != 1 || value.reactionType() != null || value.displayOrder() != 1) {
                    throw invalidGeneratedOutput();
                }
            } else if ("reaction_support".equals(value.role())
                    && REACTIONS.contains(value.reactionType())
                    && value.displayOrder() == reactionOrder(value.reactionType())
                    && reactions.add(value.reactionType())) {
                // Canonical support accepted.
            } else {
                throw invalidGeneratedOutput();
            }
        }
        if (starterCount != 1 || !REACTIONS.equals(reactions)) {
            throw invalidGeneratedOutput();
        }
    }

    private int reactionOrder(String reaction) {
        return switch (reaction) {
            case "cooperating" -> 2;
            case "hesitant" -> 3;
            case "resisting" -> 4;
            case "no_response" -> 5;
            case "other" -> 6;
            default -> -1;
        };
    }

    private SceneGenerationResponse.UtteranceView toUtteranceView(
            PracticeGeneratedContentUtteranceEntity utterance,
            String phraseId
    ) {
        return new SceneGenerationResponse.UtteranceView(
                requireStableRouteId(utterance.utteranceId()),
                requireStableRouteId(phraseId),
                requireText(utterance.englishText()),
                requireText(utterance.chineseText()),
                requireText(utterance.pronunciationHint()),
                requireText(utterance.tprActionZh()),
                requireText(utterance.deliveryGuidanceZh()),
                requireText(utterance.difficulty()),
                requireText(utterance.role()),
                utterance.reactionType(),
                utterance.displayOrder(),
                new SceneGenerationResponse.ProviderProvenance(
                        requireText(utterance.providerOrigin()),
                        requireText(utterance.providerName()),
                        requireText(utterance.providerModelName()),
                        utterance.providerAttemptNumber()));
    }

    private boolean isPositive(long value) {
        return value > 0;
    }

    private boolean isSafeStableId(String value) {
        return value != null && SAFE_STABLE_ID.matcher(value).matches();
    }

    private String requireText(String value) {
        if (value == null || value.isBlank()) {
            throw invalidGeneratedOutput();
        }
        return value;
    }

    private String requireStableRouteId(String value) {
        if (!isSafeStableId(value)) {
            throw invalidGeneratedOutput();
        }
        return value;
    }

    private ContractException invalidSceneSourceContract() {
        return new ContractException(HttpStatus.BAD_REQUEST, "invalid_scene_source", "场景来源不合法。", Map.of());
    }

    private ContractException invalidCustomSceneText() {
        return new ContractException(HttpStatus.BAD_REQUEST, "invalid_custom_scene_text", "自定义场景文案不合法。", Map.of());
    }

    private ContractException presetUnavailable() {
        return new ContractException(HttpStatus.NOT_FOUND, "preset_scene_unavailable", "预置场景暂不可用。", Map.of());
    }

    private ContractException invalidGeneratedOutput() {
        return new ContractException(
                HttpStatus.BAD_GATEWAY,
                "generation_invalid_output",
                "生成内容结构不合法。",
                Map.of("retryable", false));
    }

    private record ResolvedSource(
            String inputSource,
            String resolvedText,
            PresetSceneCatalogService.PublishedPresetScene preset
    ) {
    }
}
