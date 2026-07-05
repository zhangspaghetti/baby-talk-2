package com.zhangspaghetti.babytalk.service;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.zhangspaghetti.babytalk.web.ContractException;
import com.zhangspaghetti.babytalk.service.PracticeCatalogRepository.StarterPhraseSourcePolicy;
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
import org.springframework.transaction.annotation.Transactional;

@Service
public class OnboardingDiscoveryService {

    private static final String MODE_CATALOG = "catalog";
    private static final String MODE_CUSTOM_SCENE = "custom_scene";
    private static final String SUPPORTED_LOCALE = "zh-CN";
    private static final String SOURCE_CATALOG = "catalog";
    private static final String SOURCE_SEED = "seed";
    private static final String DIFFICULTY_STARTER = "starter";
    private static final String PROFILE_MODE_DRAFT = "draft";
    private static final String PROFILE_MODE_AUTHENTICATED_REQUEST = "authenticated_request";
    private static final String PROFILE_MODE_AUTHENTICATED_PROFILE = "authenticated_profile";
    private static final String TRACE_STRATEGY_CATALOG_RANKED = "catalog_ranked";
    private static final String REASON_STARTER_MATCH = "starter_match";
    private static final String REASON_GOAL_MATCH = "goal_match";
    private static final String REASON_AGE_MATCH = "age_match";
    private static final String REASON_FALLBACK_FIRST_CATALOG = "fallback_first_catalog";
    private static final String ERROR_CUSTOM_SCENE_NOT_IMPLEMENTED = "custom_scene_not_implemented";
    private static final String ERROR_INVALID_DISCOVERY_MODE = "invalid_discovery_mode";
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

    private final PracticeCatalogRepository catalogRepository;
    private final AuthConsentSyncService authConsentSyncService;
    private final OnboardingProfileRepository onboardingProfileRepository;

    @Autowired
    public OnboardingDiscoveryService(
            PracticeCatalogRepository catalogRepository,
            AuthConsentSyncService authConsentSyncService,
            OnboardingProfileRepository onboardingProfileRepository
    ) {
        this.catalogRepository = catalogRepository;
        this.authConsentSyncService = authConsentSyncService;
        this.onboardingProfileRepository = onboardingProfileRepository;
    }

    @Transactional(readOnly = true)
    public OnboardingDiscoveryResponse discover(OnboardingDiscoveryRequest request, String sessionId) {
        if (request == null) {
            throw new ContractException(HttpStatus.BAD_REQUEST, ERROR_INVALID_DISCOVERY_MODE, "mode 不能为空。");
        }
        validateMode(request.mode());
        validateInstallationId(request.installationId(), trimToNull(request.babyProfileId()) == null);
        validateLocale(request.locale());
        var limit = normalizeLimit(request.limit());
        validateClientTraceId(request.clientTraceId());

        var context = resolveContext(request, sessionId);
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

        return toResponse(context, ranked, candidates.size());
    }

    private void validateMode(String mode) {
        var normalizedMode = trimToNull(mode);
        if (MODE_CUSTOM_SCENE.equals(normalizedMode)) {
            throw new ContractException(
                    HttpStatus.NOT_IMPLEMENTED,
                    ERROR_CUSTOM_SCENE_NOT_IMPLEMENTED,
                    "custom_scene discovery is reserved for B2.1.",
                    Map.of("supportedModes", List.of(MODE_CATALOG))
            );
        }
        if (!MODE_CATALOG.equals(normalizedMode)) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    ERROR_INVALID_DISCOVERY_MODE,
                    "mode 仅支持 catalog。",
                    Map.of("supportedModes", List.of(MODE_CATALOG))
            );
        }
    }

    private void validateInstallationId(String installationId, boolean required) {
        var normalized = trimToNull(installationId);
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
        if (!SUPPORTED_LOCALE.equals(trimToNull(locale))) {
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
        var normalized = trimToNull(clientTraceId);
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

    private DiscoveryContext resolveContext(OnboardingDiscoveryRequest request, String sessionId) {
        var babyProfileId = trimToNull(request.babyProfileId());
        if (babyProfileId == null) {
            var ageRange = requireAllowed(
                    request.ageRange(),
                    OnboardingProfileOptions.AGE_RANGES,
                    ERROR_INVALID_AGE_RANGE,
                    "ageRange 不支持。"
            );
            var parentGoal = requireAllowed(
                    request.parentGoal(),
                    OnboardingProfileOptions.PARENT_GOALS,
                    ERROR_INVALID_PARENT_GOAL,
                    "parentGoal 不支持。"
            );
            return new DiscoveryContext(
                    sessionId == null ? PROFILE_MODE_DRAFT : PROFILE_MODE_AUTHENTICATED_REQUEST,
                    ageRange,
                    parentGoal,
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
        var profile = onboardingProfileRepository.findByAccountId(session.accountId())
                .filter(candidate -> babyProfileId.equals(candidate.profileId()))
                .orElseThrow(this::profileNotFound);

        var requestedAgeRange = optionalAllowed(
                request.ageRange(),
                OnboardingProfileOptions.AGE_RANGES,
                ERROR_INVALID_AGE_RANGE,
                "ageRange 不支持。"
        );
        var requestedParentGoal = optionalAllowed(
                request.parentGoal(),
                OnboardingProfileOptions.PARENT_GOALS,
                ERROR_INVALID_PARENT_GOAL,
                "parentGoal 不支持。"
        );
        var ageRange = resolveRequiredSavedProfileValue(
                profile.ageRange(),
                requestedAgeRange,
                OnboardingProfileOptions.AGE_RANGES,
                ERROR_INVALID_AGE_RANGE,
                "ageRange 不支持。"
        );
        var parentGoal = resolveSavedOrRequestProfileValue(
                profile.parentGoal(),
                requestedParentGoal,
                OnboardingProfileOptions.PARENT_GOALS,
                ERROR_INVALID_PARENT_GOAL,
                "parentGoal 不支持。"
        );
        return new DiscoveryContext(PROFILE_MODE_AUTHENTICATED_PROFILE, ageRange, parentGoal, profile.profileId());
    }

    private String resolveRequiredSavedProfileValue(
            String savedValue,
            String requestedValue,
            Set<String> allowed,
            String code,
            String message
    ) {
        var saved = trimToNull(savedValue);
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
        var saved = trimToNull(savedValue);
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
        var spaces = catalogRepository.findSpaces(SUPPORTED_LOCALE, CATALOG_SCAN_LIMIT);
        for (var space : spaces) {
            for (var activity : catalogRepository.findActivitiesBySpace(space.spaceId(), SUPPORTED_LOCALE, CATALOG_SCAN_LIMIT)) {
                if (!SOURCE_SEED.equals(activity.source()) || candidatesByActivity.containsKey(activity.activityId())) {
                    continue;
                }
                var phrase = catalogRepository.findStarterPhrase(
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

    private boolean isCuratedDisplayComplete(PracticeCatalogRepository.PracticePhraseRow phrase) {
        return SOURCE_SEED.equals(phrase.source())
                && trimToNull(phrase.phraseId()) != null
                && trimToNull(phrase.english()) != null
                && trimToNull(phrase.chinese()) != null;
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
            case OnboardingProfileOptions.PARENT_GOAL_CALMER_CARE ->
                    containsAny(text, DEFAULT_SPACE_ID, "bath", "diaper", "bedtime", "routine", "sooth") ? 30 : 0;
            case OnboardingProfileOptions.PARENT_GOAL_NATURAL_OPENING ->
                    containsAny(text, DEFAULT_SPACE_ID, "bath", "diaper", "feeding", "care") ? 24 : 0;
            case OnboardingProfileOptions.PARENT_GOAL_CONFIDENT_PRONUNCIATION ->
                    starterDifficulty(candidate) || englishWordCount(candidate) <= 3 ? 22 : 0;
            case OnboardingProfileOptions.PARENT_GOAL_KEEP_TALKING ->
                    containsAny(text, "routine", "family", "bedtime") ? 18 : 0;
            default -> 0;
        };
    }

    private int ageScore(CatalogCandidate candidate, String ageRange) {
        var words = englishWordCount(candidate);
        var text = searchable(candidate);
        return switch (ageRange) {
            case OnboardingProfileOptions.AGE_RANGE_M0_3,
                    OnboardingProfileOptions.AGE_RANGE_M4_6,
                    OnboardingProfileOptions.AGE_RANGE_M7_11 ->
                    words <= 3 && containsAny(text, DEFAULT_SPACE_ID, "bath", "diaper", "care") ? 14 : 0;
            case OnboardingProfileOptions.AGE_RANGE_M12_17,
                    OnboardingProfileOptions.AGE_RANGE_M18_23 -> words <= 5 ? 10 : 0;
            case OnboardingProfileOptions.AGE_RANGE_M24_30,
                    OnboardingProfileOptions.AGE_RANGE_M31_36 ->
                    containsAny(text, "routine", "family", "bedtime") ? 8 : 4;
            default -> 0;
        };
    }

    private int completenessScore(CatalogCandidate candidate) {
        var score = 0;
        if (trimToNull(candidate.space().titleZh()) != null) {
            score += 2;
        }
        if (trimToNull(candidate.activity().titleZh()) != null) {
            score += 2;
        }
        if (trimToNull(candidate.activity().coachTip()) != null) {
            score += 1;
        }
        if (trimToNull(candidate.phrase().pronunciation()) != null) {
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

    private OnboardingDiscoveryResponse toResponse(
            DiscoveryContext context,
            List<RankedCandidate> ranked,
            int candidateCount
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
        return new OnboardingDiscoveryResponse(
                "disc_" + UUID.randomUUID().toString().replace("-", ""),
                MODE_CATALOG,
                context.profileMode(),
                SOURCE_CATALOG,
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

    private StarterUtteranceResponse toUtterance(PracticeCatalogRepository.PracticePhraseRow phrase) {
        return new StarterUtteranceResponse(
                phrase.phraseId(),
                phrase.phraseId(),
                phrase.english(),
                phrase.chinese(),
                phrase.pronunciation(),
                trimToNull(phrase.difficulty()) == null ? DIFFICULTY_STARTER : phrase.difficulty(),
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
        return DIFFICULTY_STARTER.equals(trimToNull(candidate.phrase().difficulty()));
    }

    private int englishWordCount(CatalogCandidate candidate) {
        var english = trimToNull(candidate.phrase().english());
        if (english == null) {
            return Integer.MAX_VALUE;
        }
        return english.replaceAll("[^A-Za-z ]", " ").trim().split("\\s+").length;
    }

    private String requireAllowed(String value, Set<String> allowed, String code, String message) {
        var normalized = trimToNull(value);
        if (normalized == null || !allowed.contains(normalized)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, code, message, Map.of("allowed", allowed));
        }
        return normalized;
    }

    private String optionalAllowed(String value, Set<String> allowed, String code, String message) {
        var normalized = trimToNull(value);
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

    private String trimToNull(String value) {
        if (value == null) {
            return null;
        }
        var trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private String nullToEmpty(String value) {
        return value == null ? "" : value;
    }

    @JsonIgnoreProperties(ignoreUnknown = false)
    public record OnboardingDiscoveryRequest(
            String mode,
            String installationId,
            String babyProfileId,
            String ageRange,
            String parentGoal,
            String locale,
            Integer limit,
            String clientTraceId
    ) {
        @JsonAnySetter
        public void rejectUnknownField(String fieldName, Object ignored) {
            throw new IllegalArgumentException("Unsupported onboarding discovery field: " + fieldName);
        }
    }

    public record OnboardingDiscoveryResponse(
            String discoveryTraceId,
            String mode,
            String profileMode,
            String source,
            List<SceneResponse> scenes,
            List<MomentResponse> moments,
            StarterResponse starter,
            TraceResponse trace
    ) {
    }

    public record SceneResponse(
            String sceneId,
            String spaceId,
            String title,
            int rank,
            String reasonCode
    ) {
    }

    public record MomentResponse(
            String momentId,
            String sceneId,
            String spaceId,
            String activityId,
            String title,
            String sceneTag,
            String coachTip,
            int rank,
            List<StarterUtteranceResponse> starterUtterances
    ) {
    }

    public record StarterUtteranceResponse(
            String utteranceId,
            String phraseId,
            String english,
            String chinese,
            String pronunciation,
            String difficulty,
            String source
    ) {
    }

    public record StarterResponse(
            String sceneId,
            String spaceId,
            String momentId,
            String activityId,
            String utteranceId,
            String phraseId,
            String source
    ) {
    }

    public record TraceResponse(
            String strategy,
            String fallbackReason,
            int candidateCount,
            int returnedCount
    ) {
    }

    private record DiscoveryContext(
            String profileMode,
            String ageRange,
            String parentGoal,
            String profileId
    ) {
    }

    private record CatalogCandidate(
            PracticeCatalogRepository.PracticeSpaceRow space,
            PracticeCatalogRepository.PracticeActivityRow activity,
            PracticeCatalogRepository.PracticePhraseRow phrase
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
