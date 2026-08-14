package com.zhangspaghetti.babytalk.onboarding.conversation;

import com.zhangspaghetti.babytalk.onboarding.conversation.OnboardingConversationGenerator.GenerationRequest;
import com.zhangspaghetti.babytalk.onboarding.conversation.OnboardingConversationStore.StoredConversation;
import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentKeyFactory;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class OnboardingConversationService {

    private static final Duration TTL = Duration.ofHours(24);
    private static final Duration GENERATION_LEASE = Duration.ofMinutes(5);
    private static final Duration REPLAY_WAIT = Duration.ofSeconds(4);
    private static final Pattern SAFE_INSTALLATION_ID = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_.:-]{7,95}$");
    private static final Pattern SAFE_EVENT_ID = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_.:-]{5,95}$");
    private static final Pattern PHONE_LIKE = Pattern.compile("^\\+?[0-9 ()-]{10,}$");
    private static final Pattern SAFE_FACET = Pattern.compile("^[A-Za-z0-9_.:-]{1,80}$");
    private static final Set<String> SCENES = Set.of("bedtime", "feeding", "post_cry", "diaper_change");
    private static final Set<String> TIME_BANDS = Set.of("morning", "afternoon", "evening", "night");
    private static final Map<String, String> CARE_ENTRY_SCENES = Map.of(
            "care.bedtime_soothing", "bedtime",
            "care.feeding_now", "feeding",
            "care.post_cry_soothing", "post_cry",
            "care.diaper_change", "diaper_change");

    private final OnboardingConversationStore store;
    private final OnboardingConversationGenerator generator;
    private final PracticeGeneratedContentKeyFactory keyFactory;
    private final OnboardingAudioCapabilityService audioCapabilities;
    private final Clock clock;

    @Autowired
    public OnboardingConversationService(
            OnboardingConversationStore store,
            OnboardingConversationGenerator generator,
            PracticeGeneratedContentKeyFactory keyFactory,
            OnboardingAudioCapabilityService audioCapabilities
    ) {
        this(store, generator, keyFactory, audioCapabilities, Clock.systemUTC());
    }

    OnboardingConversationService(
            OnboardingConversationStore store,
            OnboardingConversationGenerator generator,
            PracticeGeneratedContentKeyFactory keyFactory,
            OnboardingAudioCapabilityService audioCapabilities,
            Clock clock
    ) {
        this.store = store;
        this.generator = generator;
        this.keyFactory = keyFactory;
        this.audioCapabilities = audioCapabilities;
        this.clock = clock;
    }

    public Conversation create(CreateRequest request) {
        validate(request);
        var installationRef = keyFactory.installationRefHash(request.installationId());
        var now = utcNow();
        store.deleteExpired(now, 100);
        store.deleteExpiredIdentity(installationRef, request.localEventId(), now);
        var fingerprint = keyFactory.onboardingConversationFingerprint(
                installationRef,
                canonicalRequest(request));
        var existing = store.find(installationRef, request.localEventId());
        if (existing != null) {
            return awaitExisting(request, installationRef, fingerprint, existing);
        }

        var conversationId = "onbc_" + UUID.randomUUID().toString().replace("-", "");
        var reservation = new StoredConversation(
                conversationId, installationRef, request.localEventId(), fingerprint,
                request.registryRevision(), request.careEntryId(), request.generationScene().namespace(),
                request.generationScene().key(), request.generationScene().version(), canonicalFacets(request),
                request.locale(), request.timeBand(), null, null, null, null, null, null,
                "generating", now.plus(GENERATION_LEASE), now, now,
                keyFactory.ownerKey("installation", request.installationId()));
        if (store.reserve(reservation) == 0) {
            return awaitExisting(request, installationRef, fingerprint,
                    store.find(installationRef, request.localEventId()));
        }

        try {
            var generated = generator.generate(new GenerationRequest(
                    request.installationId(), request.localEventId(), request.generationScene().key(),
                    Map.copyOf(request.generationScene().facets()), request.locale(), request.timeBand()));
            var completedAt = utcNow();
            var expiresAt = completedAt.plus(TTL);
            if (store.activate(
                    conversationId, generated.generatedContentId(), generated.utteranceId(),
                    generated.englishText(), generated.chineseText(), generated.pronunciationHint(),
                    generated.audioRef(), expiresAt, completedAt) != 1) {
                return awaitExisting(request, installationRef, fingerprint,
                        store.find(installationRef, request.localEventId()));
            }
            return response(store.find(installationRef, request.localEventId()), expiresAt);
        } catch (RuntimeException exception) {
            store.deleteReservation(conversationId);
            throw exception;
        }
    }

    private Conversation awaitExisting(
            CreateRequest request,
            String installationRef,
            String fingerprint,
            StoredConversation initial
    ) {
        var existing = initial;
        var deadline = System.nanoTime() + REPLAY_WAIT.toNanos();
        var delayMillis = 25L;
        while (existing != null) {
            if (!fingerprint.equals(existing.requestFingerprint())) {
                throw new ContractException(
                        HttpStatus.CONFLICT,
                        "onboarding_idempotency_conflict",
                        "同一本地事件已使用不同请求。");
            }
            if ("active".equals(existing.status())) {
                var now = utcNow();
                var expiresAt = now.plus(TTL);
                if (store.extendExpiry(existing.conversationId(), expiresAt, now) == 1) {
                    return response(existing, expiresAt);
                }
                store.deleteExpiredIdentity(installationRef, request.localEventId(), now);
                return create(request);
            }
            var now = utcNow();
            if (!existing.expiresAt().isAfter(now)) {
                store.deleteExpiredIdentity(installationRef, request.localEventId(), now);
                return create(request);
            }
            if (System.nanoTime() >= deadline) {
                throw generationInProgress();
            }
            try {
                Thread.sleep(delayMillis);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                throw generationInProgress();
            }
            delayMillis = Math.min(delayMillis * 2, 400L);
            existing = store.find(installationRef, request.localEventId());
        }
        return create(request);
    }

    private ContractException generationInProgress() {
        return new ContractException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "onboarding_generation_in_progress",
                "首句仍在准备中，请稍后重试。");
    }

    private OffsetDateTime utcNow() {
        return OffsetDateTime.now(clock).withOffsetSameInstant(ZoneOffset.UTC);
    }

    private void validate(CreateRequest request) {
        if (request == null || request.generationScene() == null) {
            throw invalid("invalid_onboarding_conversation_request", "请求不完整。");
        }
        if (request.installationId() == null
                || !SAFE_INSTALLATION_ID.matcher(request.installationId()).matches()
                || PHONE_LIKE.matcher(request.installationId()).matches()) {
            throw invalid("invalid_installation_id", "安装标识格式无效。");
        }
        if (request.localEventId() == null || !SAFE_EVENT_ID.matcher(request.localEventId()).matches()) {
            throw invalid("invalid_local_event_id", "本地事件标识格式无效。");
        }
        var scene = request.generationScene();
        if (!"babytalk.care".equals(scene.namespace()) || scene.version() != 1 || !SCENES.contains(scene.key())) {
            throw invalid("unsupported_generation_scene", "生成场景不受支持。");
        }
        if (!scene.key().equals(CARE_ENTRY_SCENES.get(request.careEntryId()))) {
            throw invalid("unsupported_generation_scene", "入口与生成场景不匹配。");
        }
        if (scene.facets() == null || scene.facets().size() > 8
                || scene.facets().entrySet().stream().anyMatch(entry ->
                entry.getKey() == null || entry.getValue() == null
                        || entry.getKey().length() > 40 || entry.getValue().length() > 80
                        || !SAFE_FACET.matcher(entry.getKey()).matches()
                        || !SAFE_FACET.matcher(entry.getValue()).matches())) {
            throw invalid("invalid_generation_facets", "生成场景参数无效。");
        }
        requireLength(request.registryRevision(), 1, 64, "registry_revision");
        if (!"zh-CN".equals(request.locale())) {
            throw invalid("invalid_locale", "语言区域不受支持。");
        }
        if (!TIME_BANDS.contains(request.timeBand())) {
            throw invalid("invalid_time_band", "时间段不受支持。");
        }
        if (request.babyNickname() != null && request.babyNickname().length() > 40) {
            throw invalid("invalid_baby_nickname", "宝宝昵称过长。");
        }
    }

    private void requireLength(String value, int min, int max, String field) {
        if (value == null || value.length() < min || value.length() > max) {
            throw invalid("invalid_onboarding_conversation_request", field + " 格式无效。");
        }
    }

    private ContractException invalid(String code, String message) {
        return new ContractException(HttpStatus.BAD_REQUEST, code, message);
    }

    private String canonicalRequest(CreateRequest request) {
        return java.util.stream.Stream.of(
                        request.careEntryId(), request.registryRevision(),
                        request.generationScene().namespace(), request.generationScene().key(),
                        Integer.toString(request.generationScene().version()), canonicalFacets(request),
                        request.locale(), request.timeBand(),
                        request.babyNickname() == null ? "" : request.babyNickname())
                .map(this::canonicalSegment)
                .collect(java.util.stream.Collectors.joining());
    }

    private String canonicalSegment(String value) {
        return value.length() + ":" + value;
    }

    private String canonicalFacets(CreateRequest request) {
        var members = request.generationScene().facets().entrySet().stream()
                .sorted(Map.Entry.comparingByKey())
                .map(entry -> "\"" + entry.getKey() + "\":\"" + entry.getValue() + "\"")
                .reduce((left, right) -> left + "," + right)
                .orElse("");
        return "{" + members + "}";
    }

    private Conversation response(StoredConversation stored, OffsetDateTime expiresAt) {
        var audioCapability = audioCapabilities.issue(
                stored.conversationId(), stored.utteranceId(), expiresAt);
        return new Conversation(
                stored.conversationId(), expiresAt,
                new Utterance(stored.utteranceId(), stored.englishText(), stored.chineseText(),
                        stored.pronunciationHint(), audioCapability, "remote_generated"));
    }

    public record CreateRequest(
            String installationId,
            String localEventId,
            String careEntryId,
            String registryRevision,
            GenerationScene generationScene,
            String locale,
            String timeBand,
            String babyNickname
    ) {
    }

    public record GenerationScene(String namespace, String key, int version, Map<String, String> facets) {
    }

    public record Conversation(String conversationId, OffsetDateTime expiresAt, Utterance utterance) {
    }

    public record Utterance(
            String utteranceId,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String audioRef,
            String source
    ) {
    }
}
