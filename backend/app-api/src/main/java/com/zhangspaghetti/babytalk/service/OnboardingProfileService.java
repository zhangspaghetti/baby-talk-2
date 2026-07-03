package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.web.ContractException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OnboardingProfileService {

    private static final Set<String> AGE_RANGES = Set.of(
            "m0_3",
            "m4_6",
            "m7_11",
            "m12_17",
            "m18_23",
            "m24_30",
            "m31_36"
    );
    private static final Set<String> PARENT_GOALS = Set.of(
            "natural_opening",
            "confident_pronunciation",
            "calmer_care",
            "keep_talking"
    );
    private static final Set<String> ONBOARDING_STATES = Set.of("draft", "completed");
    private static final Set<String> STARTER_SOURCES = Set.of("catalog", "generated");
    private static final Pattern CLIENT_TRACE_ID_PATTERN = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,95}$");
    private static final Pattern PHONE_LIKE_PATTERN = Pattern.compile("\\d{11,}");

    private final AuthConsentSyncService authConsentSyncService;
    private final OnboardingProfileRepository repository;
    private final Clock clock;

    @Autowired
    public OnboardingProfileService(
            AuthConsentSyncService authConsentSyncService,
            OnboardingProfileRepository repository
    ) {
        this(authConsentSyncService, repository, Clock.systemUTC());
    }

    OnboardingProfileService(
            AuthConsentSyncService authConsentSyncService,
            OnboardingProfileRepository repository,
            Clock clock
    ) {
        this.authConsentSyncService = authConsentSyncService;
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public OnboardingProfileResponse getProfile(String sessionId) {
        var session = acceptedSession(sessionId);
        return repository.findByAccountId(session.accountId())
                .map(this::toResponse)
                .orElseThrow(this::profileNotFound);
    }

    @Transactional
    public OnboardingProfileResponse putProfile(String sessionId, PutOnboardingProfileRequest request) {
        var session = acceptedSession(sessionId);
        var normalized = normalizeAndValidate(request);
        var existing = repository.findByAccountId(session.accountId());
        if (existing.isEmpty()) {
            if (normalized.expectedVersion() != null) {
                throw profileNotFound();
            }
            return createProfile(session.accountId(), normalized);
        }

        var current = existing.get();
        if (normalized.expectedVersion() == null) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "expected_version_required",
                    "请带上当前宝宝档案版本后再保存。",
                    Map.of("currentVersion", current.version())
            );
        }
        if (normalized.expectedVersion() != current.version()) {
            throw versionConflict(normalized.expectedVersion(), current.version());
        }

        var updatedAt = Instant.now(clock);
        var updated = repository.updateIfVersionMatches(
                session.accountId(),
                normalized.expectedVersion(),
                normalized.toPatch(),
                updatedAt
        );
        if (updated == 0) {
            var currentVersion = repository.findVersionByAccountId(session.accountId()).orElse(null);
            throw versionConflict(normalized.expectedVersion(), currentVersion);
        }
        return repository.findByAccountId(session.accountId())
                .map(this::toResponse)
                .orElseThrow(this::profileNotFound);
    }

    private AuthConsentSyncService.ConsumerSessionView acceptedSession(String sessionId) {
        return authConsentSyncService.requireAcceptedConsumerSession(sessionId, "读取或保存宝宝档案");
    }

    private OnboardingProfileResponse createProfile(String accountId, ValidatedProfile profile) {
        var now = Instant.now(clock);
        var row = new OnboardingProfileRepository.ProfileRow(
                "babyprof_" + UUID.randomUUID(),
                accountId,
                profile.babyName(),
                profile.ageRange(),
                profile.parentGoal(),
                profile.starter() == null ? null : profile.starter().sceneId(),
                profile.starter() == null ? null : profile.starter().momentId(),
                profile.starter() == null ? null : profile.starter().activityId(),
                profile.starter() == null ? null : profile.starter().utteranceId(),
                profile.starter() == null ? null : profile.starter().phraseId(),
                profile.starter() == null ? null : profile.starter().source(),
                profile.onboardingState(),
                profile.onboardingCompletedAt(),
                1,
                now,
                now
        );
        try {
            repository.insert(row);
        } catch (DuplicateKeyException exception) {
            var currentVersion = repository.findVersionByAccountId(accountId).orElse(null);
            throw versionConflict(profile.expectedVersion(), currentVersion);
        }
        return toResponse(row);
    }

    private ValidatedProfile normalizeAndValidate(PutOnboardingProfileRequest request) {
        if (request == null) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "validation_failed", "请求参数不合法。");
        }
        if (request.expectedVersion() != null && request.expectedVersion() < 1) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "validation_failed", "expectedVersion 必须为正整数。");
        }
        var babyName = normalizeBabyName(request.babyName());
        var ageRange = requireAllowed(trimToNull(request.ageRange()), AGE_RANGES, "invalid_age_range", "ageRange 不支持。");
        var onboardingState = requireAllowed(
                trimToNull(request.onboardingState()),
                ONBOARDING_STATES,
                "invalid_onboarding_state",
                "onboardingState 不支持。"
        );
        var parentGoal = optionalAllowed(
                trimToNull(request.parentGoal()),
                PARENT_GOALS,
                "invalid_parent_goal",
                "parentGoal 不支持。"
        );
        var starter = normalizeStarter(request.starter());
        validateClientTraceId(request.clientTraceId(), babyName);

        Instant completedAt = null;
        if ("completed".equals(onboardingState)) {
            if (parentGoal == null) {
                throw new ContractException(
                        HttpStatus.BAD_REQUEST,
                        "completed_profile_missing_parent_goal",
                        "完成宝宝档案需要选择家长目标。"
                );
            }
            if (starter == null || !starter.isComplete()) {
                throw new ContractException(
                        HttpStatus.BAD_REQUEST,
                        "completed_profile_missing_starter",
                        "完成宝宝档案需要完整的 starter。"
                );
            }
            if (request.completedAt() == null) {
                throw new ContractException(
                        HttpStatus.BAD_REQUEST,
                        "completed_at_required",
                        "完成宝宝档案需要 completedAt。"
                );
            }
            var latestAllowed = Instant.now(clock).plus(5, ChronoUnit.MINUTES);
            if (request.completedAt().isAfter(latestAllowed)) {
                throw new ContractException(
                        HttpStatus.BAD_REQUEST,
                        "completed_at_in_future",
                        "completedAt 不能超过当前时间五分钟。"
                );
            }
            completedAt = request.completedAt();
        }

        return new ValidatedProfile(
                request.expectedVersion(),
                babyName,
                ageRange,
                parentGoal,
                starter,
                onboardingState,
                completedAt
        );
    }

    private String normalizeBabyName(String rawBabyName) {
        var babyName = trimToNull(rawBabyName);
        if (babyName == null) {
            return null;
        }
        if (babyName.codePointCount(0, babyName.length()) > 40) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "baby_name_too_long", "babyName 不能超过 40 个字符。");
        }
        return babyName;
    }

    private StarterValue normalizeStarter(StarterRequest starter) {
        if (starter == null) {
            return null;
        }
        var source = optionalAllowed(
                trimToNull(starter.source()),
                STARTER_SOURCES,
                "invalid_starter_source",
                "starter.source 不支持。"
        );
        return new StarterValue(
                requireMaxLength(trimToNull(starter.sceneId()), 96, "starter_scene_id_too_long"),
                requireMaxLength(trimToNull(starter.momentId()), 96, "starter_moment_id_too_long"),
                requireMaxLength(trimToNull(starter.activityId()), 96, "starter_activity_id_too_long"),
                requireMaxLength(trimToNull(starter.utteranceId()), 120, "starter_utterance_id_too_long"),
                requireMaxLength(trimToNull(starter.phraseId()), 120, "starter_phrase_id_too_long"),
                source
        );
    }

    private void validateClientTraceId(String rawClientTraceId, String babyName) {
        var clientTraceId = trimToNull(rawClientTraceId);
        if (clientTraceId == null) {
            return;
        }
        if (!CLIENT_TRACE_ID_PATTERN.matcher(clientTraceId).matches()
                || PHONE_LIKE_PATTERN.matcher(clientTraceId).find()
                || (babyName != null
                        && clientTraceId.toLowerCase(Locale.ROOT).contains(babyName.toLowerCase(Locale.ROOT)))) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_client_trace_id",
                    "clientTraceId 不合法。",
                    Map.of("field", "clientTraceId")
            );
        }
    }

    private String requireAllowed(String value, Set<String> allowed, String code, String message) {
        if (value == null || !allowed.contains(value)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, code, message, Map.of("allowed", allowed));
        }
        return value;
    }

    private String optionalAllowed(String value, Set<String> allowed, String code, String message) {
        if (value == null) {
            return null;
        }
        if (!allowed.contains(value)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, code, message, Map.of("allowed", allowed));
        }
        return value;
    }

    private String requireMaxLength(String value, int maxLength, String code) {
        if (value != null && value.length() > maxLength) {
            throw new ContractException(HttpStatus.BAD_REQUEST, code, "starter 字段过长。");
        }
        return value;
    }

    private String trimToNull(String value) {
        if (value == null) {
            return null;
        }
        var trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private ContractException profileNotFound() {
        return new ContractException(
                HttpStatus.NOT_FOUND,
                "onboarding_profile_not_found",
                "当前账号还没有宝宝档案。"
        );
    }

    private ContractException versionConflict(Integer expectedVersion, Integer currentVersion) {
        var details = new LinkedHashMap<String, Object>();
        if (expectedVersion != null) {
            details.put("expectedVersion", expectedVersion);
        }
        if (currentVersion != null) {
            details.put("currentVersion", currentVersion);
        }
        return new ContractException(
                HttpStatus.CONFLICT,
                "version_conflict",
                "宝宝档案已在其他地方更新，请重新加载后再保存。",
                details
        );
    }

    private OnboardingProfileResponse toResponse(OnboardingProfileRepository.ProfileRow row) {
        return new OnboardingProfileResponse(
                row.profileId(),
                row.babyName(),
                row.ageRange(),
                row.parentGoal(),
                row.starterSceneId() == null
                        && row.starterMomentId() == null
                        && row.starterActivityId() == null
                        && row.starterUtteranceId() == null
                        && row.starterPhraseId() == null
                        && row.starterSource() == null
                        ? null
                        : new StarterResponse(
                                row.starterSceneId(),
                                row.starterMomentId(),
                                row.starterActivityId(),
                                row.starterUtteranceId(),
                                row.starterPhraseId(),
                                row.starterSource()
                        ),
                row.onboardingState(),
                row.onboardingCompletedAt(),
                row.version(),
                row.createdAt(),
                row.updatedAt()
        );
    }

    public record PutOnboardingProfileRequest(
            @Positive Integer expectedVersion,
            String babyName,
            @NotBlank(message = "ageRange 不能为空。") String ageRange,
            String parentGoal,
            @Valid StarterRequest starter,
            @NotBlank(message = "onboardingState 不能为空。") String onboardingState,
            Instant completedAt,
            @Size(max = 96, message = "clientTraceId 过长。") String clientTraceId
    ) {
    }

    public record StarterRequest(
            String sceneId,
            String momentId,
            String activityId,
            String utteranceId,
            String phraseId,
            String source
    ) {
    }

    public record OnboardingProfileResponse(
            String babyProfileId,
            String babyName,
            String ageRange,
            String parentGoal,
            StarterResponse starter,
            String onboardingState,
            Instant onboardingCompletedAt,
            int version,
            Instant createdAt,
            Instant updatedAt
    ) {
    }

    public record StarterResponse(
            String sceneId,
            String momentId,
            String activityId,
            String utteranceId,
            String phraseId,
            String source
    ) {
    }

    private record ValidatedProfile(
            Integer expectedVersion,
            String babyName,
            String ageRange,
            String parentGoal,
            StarterValue starter,
            String onboardingState,
            Instant onboardingCompletedAt
    ) {

        OnboardingProfileRepository.ProfilePatch toPatch() {
            return new OnboardingProfileRepository.ProfilePatch(
                    babyName,
                    ageRange,
                    parentGoal,
                    starter == null ? null : starter.sceneId(),
                    starter == null ? null : starter.momentId(),
                    starter == null ? null : starter.activityId(),
                    starter == null ? null : starter.utteranceId(),
                    starter == null ? null : starter.phraseId(),
                    starter == null ? null : starter.source(),
                    onboardingState,
                    onboardingCompletedAt
            );
        }
    }

    private record StarterValue(
            String sceneId,
            String momentId,
            String activityId,
            String utteranceId,
            String phraseId,
            String source
    ) {

        boolean isComplete() {
            return sceneId != null
                    && momentId != null
                    && activityId != null
                    && utteranceId != null
                    && phraseId != null
                    && source != null;
        }
    }
}
