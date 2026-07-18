package com.zhangspaghetti.babytalk.practice.discovery;

import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentService;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryRequest;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryResponse;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryResponse.MomentResponse;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryResponse.SceneResponse;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryResponse.StarterResponse;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryResponse.StarterUtteranceResponse;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryResponse.TraceResponse;
import com.zhangspaghetti.babytalk.practice.catalog.PracticeCatalogService;
import com.zhangspaghetti.babytalk.practice.catalog.model.PracticeActivityRow;
import com.zhangspaghetti.babytalk.practice.catalog.model.PracticePhraseRow;
import com.zhangspaghetti.babytalk.practice.catalog.model.PracticeSpaceRow;
import com.zhangspaghetti.babytalk.practice.catalog.model.StarterPhraseSourcePolicy;
import com.zhangspaghetti.babytalk.profile.BabyProfileMapper;
import com.zhangspaghetti.babytalk.profile.BabyProfileOptions;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import com.zhangspaghetti.babytalk.web.ContractException;
import cn.hutool.core.util.StrUtil;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class PracticeDiscoveryService {

    private static final String SURFACE_ONBOARDING = "onboarding";
    private static final String MODE_CATALOG = "catalog";
    private static final String MODE_CUSTOM_SCENE = "custom_scene";
    private static final String SUPPORTED_LOCALE = "zh-CN";
    private static final String SOURCE_CATALOG = "catalog";
    private static final String SOURCE_GENERATED = "generated";
    private static final String SOURCE_SEED = "seed";
    private static final String DIFFICULTY_STARTER = "starter";
    private static final String PROFILE_MODE_DRAFT = "draft";
    private static final String PROFILE_MODE_AUTHENTICATED_REQUEST = "authenticated_request";
    private static final String PROFILE_MODE_AUTHENTICATED_PROFILE = "authenticated_profile";
    private static final String TRACE_STRATEGY_CATALOG_RANKED = "catalog_ranked";
    private static final String TRACE_STRATEGY_CUSTOM_SCENE_GENERATED = "custom_scene_generated";
    private static final String REASON_STARTER_MATCH = "starter_match";
    private static final String REASON_GOAL_MATCH = "goal_match";
    private static final String REASON_AGE_MATCH = "age_match";
    private static final String REASON_FALLBACK_FIRST_CATALOG = "fallback_first_catalog";
    private static final String REASON_CUSTOM_SCENE_MATCH = "custom_scene_match";
    private static final String ERROR_INVALID_DISCOVERY_SURFACE = "invalid_discovery_surface";
    private static final String ERROR_INVALID_DISCOVERY_MODE = "invalid_discovery_mode";
    private static final String ERROR_UNSUPPORTED_SURFACE_MODE = "unsupported_surface_mode";
    private static final String ERROR_INVALID_INSTALLATION_ID = "invalid_installation_id";
    private static final String ERROR_INVALID_CLIENT_TRACE_ID = "invalid_client_trace_id";
    private static final String ERROR_UNSUPPORTED_LOCALE = "unsupported_locale";
    private static final String ERROR_INVALID_LIMIT = "invalid_limit";
    private static final String ERROR_INVALID_AGE_RANGE = "invalid_age_range";
    private static final String ERROR_INVALID_PARENT_GOAL = "invalid_parent_goal";
    private static final String ERROR_PROFILE_CONTEXT_MISMATCH = "profile_context_mismatch";
    private static final String ERROR_CONSUMER_AUTHENTICATION_REQUIRED = "consumer_authentication_required";
    private static final String ERROR_CATALOG_UNAVAILABLE = "catalog_unavailable";
    private static final String ERROR_ONBOARDING_PROFILE_NOT_FOUND = "onboarding_profile_not_found";
    private static final String DEFAULT_SPACE_ID = "daily_care";
    private static final String DEFAULT_ACTIVITY_ID = "bath_time";
    private static final int DEFAULT_LIMIT = 6;
    private static final int CATALOG_SCAN_LIMIT = 50;
    private static final Pattern SAFE_CLIENT_ID_PATTERN = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,95}$");
    private static final Pattern SAFE_INSTALLATION_ID_PATTERN = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$");
    private static final Pattern PHONE_LIKE_PATTERN = Pattern.compile("\\d{11,}");

    private final PracticeCatalogService catalogService;
    private final AuthConsentSyncService authConsentSyncService;
    private final BabyProfileMapper babyProfileMapper;
    private final PracticeGeneratedContentService generatedContentService;

    @Autowired
    public PracticeDiscoveryService(
            PracticeCatalogService catalogService,
            AuthConsentSyncService authConsentSyncService,
            BabyProfileMapper babyProfileMapper,
            PracticeGeneratedContentService generatedContentService
    ) {
        this.catalogService = catalogService;
        this.authConsentSyncService = authConsentSyncService;
        this.babyProfileMapper = babyProfileMapper;
        this.generatedContentService = generatedContentService;
    }

    public PracticeDiscoveryResponse discover(PracticeDiscoveryRequest request, String sessionId) {
        if (request == null) {
            throw invalidDiscoverySurface();
        }
        var surface = validateSurface(request.surface());
        var mode = validateMode(request.mode());
        if (mode == PracticeDiscoveryMode.CUSTOM_SCENE) {
            generatedContentService.requireCustomSceneGenerationAvailable();
        }
        validateModeSpecificFields(request, mode);
        validateLocale(request.locale());
        var limit = normalizeLimit(request.limit());
        validateClientTraceId(request.clientTraceId());

        var context = resolveContext(request, sessionId);
        if (mode == PracticeDiscoveryMode.CUSTOM_SCENE) {
            var generatedContext = resolveGeneratedContentContext(context, sessionId);
            validateInstallationId(
                    request.installationId(),
                    generatedContext.accountId() == null && generatedContext.profileId() == null);
            var generated = generatedContentService.generateCustomScene(new PracticeGeneratedContentService.CustomSceneDiscoveryRequest(
                    surface.wireValue(),
                    mode.wireValue(),
                    StrUtil.trimToNull(request.installationId()),
                    generatedContext.accountId(),
                    generatedContext.profileId(),
                    generatedContext.ageRange(),
                    generatedContext.parentGoal(),
                    SUPPORTED_LOCALE,
                    request.customSceneText()
            ));
            return toGeneratedResponse(generatedContext, generated, surface, mode);
        }

        validateInstallationId(request.installationId(), context.profileId() == null);

        var candidates = rankedCandidates(context);
        var ranked = candidates.stream()
                .limit(limit)
                .toList();
        if (ranked.isEmpty()) {
            throw new ContractException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    ERROR_CATALOG_UNAVAILABLE,
                    "暂时没有可用的 catalog starter。"
            );
        }

        return toResponse(context, ranked, candidates.size(), surface, mode);
    }

    private PracticeDiscoverySurface validateSurface(String surface) {
        var parsed = PracticeDiscoverySurface.fromWireValue(surface);
        if (parsed == null) {
            throw invalidDiscoverySurface();
        }
        if (parsed != PracticeDiscoverySurface.ONBOARDING) {
            throw unsupportedSurfaceMode();
        }
        return parsed;
    }

    private ContractException invalidDiscoverySurface() {
        return new ContractException(
                HttpStatus.BAD_REQUEST,
                ERROR_INVALID_DISCOVERY_SURFACE,
                "surface 仅支持 onboarding。",
                Map.of("supportedSurfaces", List.of(SURFACE_ONBOARDING))
        );
    }

    private PracticeDiscoveryMode validateMode(String mode) {
        var parsed = PracticeDiscoveryMode.fromWireValue(mode);
        if (parsed == null) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    ERROR_INVALID_DISCOVERY_MODE,
                    "mode 仅支持 catalog 或 custom_scene。",
                    Map.of("supportedModes", List.of(MODE_CATALOG, MODE_CUSTOM_SCENE))
            );
        }
        return parsed;
    }

    private ContractException unsupportedSurfaceMode() {
        return new ContractException(
                HttpStatus.BAD_REQUEST,
                ERROR_UNSUPPORTED_SURFACE_MODE,
                "surface/mode 组合暂不支持。",
                Map.of("supportedPairs", List.of(
                        SupportedPair.onboardingCatalog(),
                        SupportedPair.onboardingCustomScene()))
        );
    }

    private void validateModeSpecificFields(PracticeDiscoveryRequest request, PracticeDiscoveryMode mode) {
        if (mode == PracticeDiscoveryMode.CATALOG && StrUtil.trimToNull(request.customSceneText()) != null) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_request_body",
                    "customSceneText 仅支持 custom_scene mode。"
            );
        }
    }

    private void validateInstallationId(String installationId, boolean required) {
        var normalized = StrUtil.trimToNull(installationId);
        if (normalized == null) {
            if (!required) {
                return;
            }
            throw invalidInstallationId();
        }
        if (!SAFE_INSTALLATION_ID_PATTERN.matcher(normalized).matches()
                || PHONE_LIKE_PATTERN.matcher(normalized).find()) {
            throw invalidInstallationId();
        }
    }

    private ContractException invalidInstallationId() {
        return new ContractException(
                HttpStatus.BAD_REQUEST,
                ERROR_INVALID_INSTALLATION_ID,
                "installationId 不合法。",
                Map.of("field", "installationId")
        );
    }

    private void validateLocale(String locale) {
        if (!SUPPORTED_LOCALE.equals(StrUtil.trimToNull(locale))) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    ERROR_UNSUPPORTED_LOCALE,
                    "B2 discovery 仅支持 zh-CN。",
                    Map.of("supportedLocales", List.of(SUPPORTED_LOCALE))
            );
        }
    }

    private int normalizeLimit(Integer requestedLimit) {
        if (requestedLimit == null) {
            return DEFAULT_LIMIT;
        }
        if (requestedLimit < 1 || requestedLimit > 20) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    ERROR_INVALID_LIMIT,
                    "limit 必须在 1 到 20 之间。",
                    Map.of("min", 1, "max", 20)
            );
        }
        return requestedLimit;
    }

    private void validateClientTraceId(String clientTraceId) {
        var normalized = StrUtil.trimToNull(clientTraceId);
        if (normalized == null) {
            return;
        }
        if (!SAFE_CLIENT_ID_PATTERN.matcher(normalized).matches()
                || PHONE_LIKE_PATTERN.matcher(normalized).find()) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    ERROR_INVALID_CLIENT_TRACE_ID,
                    "clientTraceId 不合法。",
                    Map.of("field", "clientTraceId")
            );
        }
    }

    private DiscoveryContext resolveContext(PracticeDiscoveryRequest request, String sessionId) {
        var babyProfileId = StrUtil.trimToNull(request.babyProfileId());
        if (babyProfileId == null) {
            var ageRange = requireAllowed(
                    request.ageRange(),
                    BabyProfileOptions.AGE_RANGES,
                    ERROR_INVALID_AGE_RANGE,
                    "ageRange 不支持。"
            );
            var parentGoal = requireAllowed(
                    request.parentGoal(),
                    BabyProfileOptions.PARENT_GOALS,
                    ERROR_INVALID_PARENT_GOAL,
                    "parentGoal 不支持。"
            );
            return new DiscoveryContext(
                    sessionId == null ? PROFILE_MODE_DRAFT : PROFILE_MODE_AUTHENTICATED_REQUEST,
                    ageRange,
                    parentGoal,
                    null,
                    null
            );
        }

        if (sessionId == null) {
            throw new ContractException(
                    HttpStatus.UNAUTHORIZED,
                    ERROR_CONSUMER_AUTHENTICATION_REQUIRED,
                    "请先登录。",
                    Map.of("reason", "missing")
            );
        }

        var session = authConsentSyncService.requireAcceptedConsumerSession(sessionId, "读取宝宝档案场景发现");
        var profile = java.util.Optional.ofNullable(babyProfileMapper.findByAccountId(session.accountId()))
                .filter(candidate -> babyProfileId.equals(candidate.profileId()))
                .orElseThrow(this::profileNotFound);

        var requestedAgeRange = optionalAllowed(
                request.ageRange(),
                BabyProfileOptions.AGE_RANGES,
                ERROR_INVALID_AGE_RANGE,
                "ageRange 不支持。"
        );
        var requestedParentGoal = optionalAllowed(
                request.parentGoal(),
                BabyProfileOptions.PARENT_GOALS,
                ERROR_INVALID_PARENT_GOAL,
                "parentGoal 不支持。"
        );
        var ageRange = resolveRequiredSavedProfileValue(
                profile.ageRange(),
                requestedAgeRange,
                BabyProfileOptions.AGE_RANGES,
                ERROR_INVALID_AGE_RANGE,
                "ageRange 不支持。"
        );
        var parentGoal = resolveSavedOrRequestProfileValue(
                profile.parentGoal(),
                requestedParentGoal,
                BabyProfileOptions.PARENT_GOALS,
                ERROR_INVALID_PARENT_GOAL,
                "parentGoal 不支持。"
        );
        return new DiscoveryContext(
                PROFILE_MODE_AUTHENTICATED_PROFILE,
                ageRange,
                parentGoal,
                session.accountId(),
                profile.profileId()
        );
    }

    private DiscoveryContext resolveGeneratedContentContext(DiscoveryContext context, String sessionId) {
        if (context.profileId() != null || sessionId == null) {
            return context;
        }
        var session = authConsentSyncService.requireAcceptedConsumerSession(sessionId, "生成自定义练习场景");
        return new DiscoveryContext(
                context.profileMode(),
                context.ageRange(),
                context.parentGoal(),
                session.accountId(),
                null
        );
    }

    private String resolveRequiredSavedProfileValue(
            String savedValue,
            String requestedValue,
            Set<String> allowed,
            String code,
            String message
    ) {
        var saved = StrUtil.trimToNull(savedValue);
        if (saved == null || !allowed.contains(saved)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, code, message, Map.of("allowed", allowed));
        }
        if (requestedValue != null && !saved.equals(requestedValue)) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    ERROR_PROFILE_CONTEXT_MISMATCH,
                    "请求上下文与已保存宝宝档案不一致。"
            );
        }
        return saved;
    }

    private String resolveSavedOrRequestProfileValue(
            String savedValue,
            String requestedValue,
            Set<String> allowed,
            String code,
            String message
    ) {
        var saved = StrUtil.trimToNull(savedValue);
        if (saved == null) {
            if (requestedValue == null) {
                throw new ContractException(HttpStatus.BAD_REQUEST, code, message, Map.of("allowed", allowed));
            }
            return requestedValue;
        }
        if (!allowed.contains(saved)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, code, message, Map.of("allowed", allowed));
        }
        if (requestedValue != null && !saved.equals(requestedValue)) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    ERROR_PROFILE_CONTEXT_MISMATCH,
                    "请求上下文与已保存宝宝档案不一致。"
            );
        }
        return saved;
    }

    private List<RankedCandidate> rankedCandidates(DiscoveryContext context) {
        var candidatesByActivity = new LinkedHashMap<String, CatalogCandidate>();
        var spaces = catalogService.findSpaces(SUPPORTED_LOCALE, CATALOG_SCAN_LIMIT);
        for (var space : spaces) {
            for (var activity : catalogService.findActivitiesBySpace(space.spaceId(), SUPPORTED_LOCALE, CATALOG_SCAN_LIMIT)) {
                if (!SOURCE_SEED.equals(activity.source()) || candidatesByActivity.containsKey(activity.activityId())) {
                    continue;
                }
                var phrase = catalogService.findStarterPhrase(
                                activity.activityId(),
                                SUPPORTED_LOCALE,
                                StarterPhraseSourcePolicy.SEED_ONLY
                        )
                        .filter(this::isCuratedDisplayComplete)
                        .orElse(null);
                if (phrase == null) {
                    continue;
                }
                candidatesByActivity.put(activity.activityId(), new CatalogCandidate(space, activity, phrase));
            }
        }

        var candidates = candidatesByActivity.values().stream()
                .map(candidate -> rank(candidate, context))
                .sorted(candidateComparator())
                .toList();
        if (candidates.isEmpty()) {
            return List.of();
        }

        var preferredFallback = candidates.stream()
                .filter(candidate -> DEFAULT_SPACE_ID.equals(candidate.candidate().space().spaceId())
                        && DEFAULT_ACTIVITY_ID.equals(candidate.candidate().activity().activityId()))
                .findFirst();
        if (preferredFallback.isPresent()) {
            return candidates;
        }

        return markFallback(candidates, REASON_FALLBACK_FIRST_CATALOG);
    }

    private boolean isCuratedDisplayComplete(PracticePhraseRow phrase) {
        return SOURCE_SEED.equals(phrase.source())
                && StrUtil.trimToNull(phrase.phraseId()) != null
                && StrUtil.trimToNull(phrase.english()) != null
                && StrUtil.trimToNull(phrase.chinese()) != null;
    }

    private RankedCandidate rank(CatalogCandidate candidate, DiscoveryContext context) {
        var goalScore = goalScore(candidate, context.parentGoal());
        var ageScore = ageScore(candidate, context.ageRange());
        var completenessScore = completenessScore(candidate);
        var reasonCode = goalScore > 0
                ? REASON_GOAL_MATCH
                : ageScore > 0 ? REASON_AGE_MATCH : REASON_STARTER_MATCH;
        return new RankedCandidate(
                candidate,
                goalScore + ageScore + completenessScore,
                reasonCode,
                null
        );
    }

    private int goalScore(CatalogCandidate candidate, String parentGoal) {
        var text = searchable(candidate);
        return switch (parentGoal) {
            case BabyProfileOptions.PARENT_GOAL_CALMER_CARE ->
                    containsAny(text, DEFAULT_SPACE_ID, "bath", "diaper", "bedtime", "routine", "sooth") ? 30 : 0;
            case BabyProfileOptions.PARENT_GOAL_NATURAL_OPENING ->
                    containsAny(text, DEFAULT_SPACE_ID, "bath", "diaper", "feeding", "care") ? 24 : 0;
            case BabyProfileOptions.PARENT_GOAL_CONFIDENT_PRONUNCIATION ->
                    starterDifficulty(candidate) || englishWordCount(candidate) <= 3 ? 22 : 0;
            case BabyProfileOptions.PARENT_GOAL_KEEP_TALKING ->
                    containsAny(text, "routine", "family", "bedtime") ? 18 : 0;
            default -> 0;
        };
    }

    private int ageScore(CatalogCandidate candidate, String ageRange) {
        var words = englishWordCount(candidate);
        var text = searchable(candidate);
        return switch (ageRange) {
            case BabyProfileOptions.AGE_RANGE_M0_3,
                    BabyProfileOptions.AGE_RANGE_M4_6,
                    BabyProfileOptions.AGE_RANGE_M7_11 ->
                    words <= 3 && containsAny(text, DEFAULT_SPACE_ID, "bath", "diaper", "care") ? 14 : 0;
            case BabyProfileOptions.AGE_RANGE_M12_17,
                    BabyProfileOptions.AGE_RANGE_M18_23 -> words <= 5 ? 10 : 0;
            case BabyProfileOptions.AGE_RANGE_M24_30,
                    BabyProfileOptions.AGE_RANGE_M31_36 ->
                    containsAny(text, "routine", "family", "bedtime") ? 8 : 4;
            default -> 0;
        };
    }

    private int completenessScore(CatalogCandidate candidate) {
        var score = 0;
        if (StrUtil.trimToNull(candidate.space().titleZh()) != null) {
            score += 2;
        }
        if (StrUtil.trimToNull(candidate.activity().titleZh()) != null) {
            score += 2;
        }
        if (StrUtil.trimToNull(candidate.activity().coachTip()) != null) {
            score += 1;
        }
        if (StrUtil.trimToNull(candidate.phrase().pronunciation()) != null) {
            score += 1;
        }
        return score;
    }

    private Comparator<RankedCandidate> candidateComparator() {
        return Comparator.<RankedCandidate>comparingInt(RankedCandidate::score).reversed()
                .thenComparingInt(candidate -> candidate.candidate().space().sortOrder())
                .thenComparingInt(candidate -> candidate.candidate().activity().sortOrder())
                .thenComparing(candidate -> candidate.candidate().space().spaceId())
                .thenComparing(candidate -> candidate.candidate().activity().activityId())
                .thenComparingInt(candidate -> candidate.candidate().phrase().step());
    }

    private List<RankedCandidate> markFallback(List<RankedCandidate> candidates, String fallbackReason) {
        var fallback = new ArrayList<RankedCandidate>();
        for (var candidate : candidates) {
            fallback.add(new RankedCandidate(
                    candidate.candidate(),
                    candidate.score(),
                    REASON_FALLBACK_FIRST_CATALOG,
                    fallbackReason
            ));
        }
        return fallback;
    }

    private PracticeDiscoveryResponse toResponse(
            DiscoveryContext context,
            List<RankedCandidate> ranked,
            int candidateCount,
            PracticeDiscoverySurface surface,
            PracticeDiscoveryMode mode
    ) {
        var sceneIds = new LinkedHashSet<String>();
        var scenes = new ArrayList<SceneResponse>();
        var momentIds = new LinkedHashSet<String>();
        var moments = new ArrayList<MomentResponse>();

        for (int i = 0; i < ranked.size(); i++) {
            var rankedCandidate = ranked.get(i);
            var candidate = rankedCandidate.candidate();
            var space = candidate.space();
            var activity = candidate.activity();
            var phrase = candidate.phrase();
            if (sceneIds.add(space.spaceId())) {
                scenes.add(new SceneResponse(
                        space.spaceId(),
                        space.spaceId(),
                        space.titleZh(),
                        scenes.size() + 1,
                        rankedCandidate.reasonCode()
                ));
            }
            if (momentIds.add(activity.activityId())) {
                moments.add(new MomentResponse(
                        activity.activityId(),
                        space.spaceId(),
                        space.spaceId(),
                        activity.activityId(),
                        activity.titleZh(),
                        activity.sceneTagEn(),
                        activity.coachTip(),
                        moments.size() + 1,
                        List.of(toUtterance(phrase))
                ));
            }
        }

        var first = ranked.get(0).candidate();
        return new PracticeDiscoveryResponse(
                "disc_" + UUID.randomUUID().toString().replace("-", ""),
                surface.wireValue(),
                mode.wireValue(),
                context.profileMode(),
                SOURCE_CATALOG,
                null,
                scenes,
                moments,
                new StarterResponse(
                        first.space().spaceId(),
                        first.space().spaceId(),
                        first.activity().activityId(),
                        first.activity().activityId(),
                        first.phrase().phraseId(),
                        first.phrase().phraseId(),
                        SOURCE_CATALOG
                ),
                new TraceResponse(
                        TRACE_STRATEGY_CATALOG_RANKED,
                        ranked.get(0).fallbackReason(),
                        candidateCount,
                        ranked.size()
                )
        );
    }

    private PracticeDiscoveryResponse toGeneratedResponse(
            DiscoveryContext context,
            PracticeGeneratedContentEntity row,
            PracticeDiscoverySurface surface,
            PracticeDiscoveryMode mode
    ) {
        var utterance = new StarterUtteranceResponse(
                row.phraseSlug(),
                row.phraseSlug(),
                row.englishText(),
                row.chineseText(),
                row.pronunciationHint(),
                row.difficulty(),
                SOURCE_GENERATED
        );
        return new PracticeDiscoveryResponse(
                "disc_" + UUID.randomUUID().toString().replace("-", ""),
                surface.wireValue(),
                mode.wireValue(),
                context.profileMode(),
                SOURCE_GENERATED,
                row.generatedContentId(),
                List.of(new SceneResponse(
                        row.spaceSlug(),
                        row.spaceSlug(),
                        row.spaceTitleZh(),
                        1,
                        REASON_CUSTOM_SCENE_MATCH
                )),
                List.of(new MomentResponse(
                        row.activitySlug(),
                        row.spaceSlug(),
                        row.spaceSlug(),
                        row.activitySlug(),
                        row.activityTitleZh(),
                        row.sceneTagEn(),
                        row.deliveryGuidanceZh(),
                        1,
                        List.of(utterance)
                )),
                new StarterResponse(
                        row.spaceSlug(),
                        row.spaceSlug(),
                        row.activitySlug(),
                        row.activitySlug(),
                        row.phraseSlug(),
                        row.phraseSlug(),
                        SOURCE_GENERATED
                ),
                new TraceResponse(
                        TRACE_STRATEGY_CUSTOM_SCENE_GENERATED,
                        null,
                        1,
                        1
                )
        );
    }

    private StarterUtteranceResponse toUtterance(PracticePhraseRow phrase) {
        return new StarterUtteranceResponse(
                phrase.phraseId(),
                phrase.phraseId(),
                phrase.english(),
                phrase.chinese(),
                phrase.pronunciation(),
                StrUtil.trimToNull(phrase.difficulty()) == null ? DIFFICULTY_STARTER : phrase.difficulty(),
                SOURCE_CATALOG
        );
    }

    private String searchable(CatalogCandidate candidate) {
        return (candidate.space().spaceId()
                + " "
                + candidate.activity().activityId()
                + " "
                + nullToEmpty(candidate.activity().sceneTagEn())
                + " "
                + nullToEmpty(candidate.activity().titleZh())
                + " "
                + nullToEmpty(candidate.activity().coachTip()))
                .toLowerCase(Locale.ROOT);
    }

    private boolean containsAny(String text, String... needles) {
        for (var needle : needles) {
            if (text.contains(needle)) {
                return true;
            }
        }
        return false;
    }

    private boolean starterDifficulty(CatalogCandidate candidate) {
        return DIFFICULTY_STARTER.equals(StrUtil.trimToNull(candidate.phrase().difficulty()));
    }

    private int englishWordCount(CatalogCandidate candidate) {
        var english = StrUtil.trimToNull(candidate.phrase().english());
        if (english == null) {
            return Integer.MAX_VALUE;
        }
        return english.replaceAll("[^A-Za-z ]", " ").trim().split("\\s+").length;
    }

    private String requireAllowed(String value, Set<String> allowed, String code, String message) {
        var normalized = StrUtil.trimToNull(value);
        if (normalized == null || !allowed.contains(normalized)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, code, message, Map.of("allowed", allowed));
        }
        return normalized;
    }

    private String optionalAllowed(String value, Set<String> allowed, String code, String message) {
        var normalized = StrUtil.trimToNull(value);
        if (normalized == null) {
            return null;
        }
        if (!allowed.contains(normalized)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, code, message, Map.of("allowed", allowed));
        }
        return normalized;
    }

    private ContractException profileNotFound() {
        return new ContractException(
                HttpStatus.NOT_FOUND,
                ERROR_ONBOARDING_PROFILE_NOT_FOUND,
                "当前账号还没有宝宝档案。"
        );
    }

    private String nullToEmpty(String value) {
        return value == null ? "" : value;
    }

    public record SupportedPair(String surface, String mode) {

        public static SupportedPair onboardingCatalog() {
            return new SupportedPair(SURFACE_ONBOARDING, MODE_CATALOG);
        }

        public static SupportedPair onboardingCustomScene() {
            return new SupportedPair(SURFACE_ONBOARDING, MODE_CUSTOM_SCENE);
        }
    }

    private record DiscoveryContext(
            String profileMode,
            String ageRange,
            String parentGoal,
            String accountId,
            String profileId
    ) {
    }

    private record CatalogCandidate(
            PracticeSpaceRow space,
            PracticeActivityRow activity,
            PracticePhraseRow phrase
    ) {
    }

    private record RankedCandidate(
            CatalogCandidate candidate,
            int score,
            String reasonCode,
            String fallbackReason
    ) {
    }
}
