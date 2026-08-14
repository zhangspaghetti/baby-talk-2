package com.zhangspaghetti.babytalk.onboarding.conversation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentKeyFactory;
import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentOwnerProperties;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

class OnboardingConversationServiceTest {

    private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-08-14T10:00:00Z"), ZoneOffset.UTC);
    private final FakeStore store = new FakeStore();
    private final FakeGenerator generator = new FakeGenerator();
    private final OnboardingConversationService service = new OnboardingConversationService(
            store,
            generator,
            new PracticeGeneratedContentKeyFactory(new PracticeGeneratedContentOwnerProperties(
                    "v1", "0123456789abcdef0123456789abcdef")),
            CLOCK);

    @Test
    void createsHmacScopedConversationWithTwentyFourHourTtl() {
        var result = service.create(request("event-1", "bedtime"));

        assertThat(result.expiresAt()).isEqualTo("2026-08-15T10:00Z");
        assertThat(result.utterance().source()).isEqualTo("remote_generated");
        assertThat(store.only().installationRefHash()).startsWith("installation_");
        assertThat(store.only().installationRefHash()).doesNotContain("install-test-1234");
        assertThat(store.only().requestFingerprint()).startsWith("ocf_");
    }

    @Test
    void exactReplayReturnsSameIdentityWithoutGeneratingAgain() {
        var first = service.create(request("event-1", "bedtime"));
        var second = service.create(request("event-1", "bedtime"));

        assertThat(second.conversationId()).isEqualTo(first.conversationId());
        assertThat(second.utterance().utteranceId()).isEqualTo(first.utterance().utteranceId());
        assertThat(generator.calls).isEqualTo(1);
    }

    @Test
    void exactReplaySlidesExpiryFromInjectedCurrentTime() {
        service.create(request("event-1", "bedtime"));
        var later = new OnboardingConversationService(
                store,
                generator,
                new PracticeGeneratedContentKeyFactory(new PracticeGeneratedContentOwnerProperties(
                        "v1", "0123456789abcdef0123456789abcdef")),
                Clock.fixed(Instant.parse("2026-08-14T11:00:00Z"), ZoneOffset.UTC));

        var replay = later.create(request("event-1", "bedtime"));

        assertThat(replay.expiresAt()).isEqualTo("2026-08-15T11:00Z");
        assertThat(generator.calls).isEqualTo(1);
    }

    @Test
    void changedRequestWithSameInstallationAndEventConflicts() {
        service.create(request("event-1", "bedtime"));

        assertThatThrownBy(() -> service.create(request("event-1", "feeding")))
                .isInstanceOfSatisfying(ContractException.class, exception -> {
                    assertThat(exception.status().value()).isEqualTo(409);
                    assertThat(exception.code()).isEqualTo("onboarding_idempotency_conflict");
                    assertThat(exception.details()).isEmpty();
                });
        assertThat(generator.calls).isEqualTo(1);
    }

    @Test
    void rejectsPhoneLikeInstallationAndUnsupportedSceneBeforeGeneration() {
        var unsafe = new OnboardingConversationService.CreateRequest(
                "13800138000", "event-1", "care.bedtime_soothing", "2026-08-14.1",
                new OnboardingConversationService.GenerationScene("babytalk.care", "bedtime", 1, Map.of()),
                "zh-CN", "evening", null);
        var unsupported = request("event-2", "free-form-prompt");

        assertThatThrownBy(() -> service.create(unsafe))
                .isInstanceOfSatisfying(ContractException.class,
                        exception -> assertThat(exception.code()).isEqualTo("invalid_installation_id"));
        assertThatThrownBy(() -> service.create(unsupported))
                .isInstanceOfSatisfying(ContractException.class,
                        exception -> assertThat(exception.code()).isEqualTo("unsupported_generation_scene"));
        assertThat(generator.calls).isZero();
    }

    @Test
    void rejectsDelimiterBearingTimeBandBeforeFingerprinting() {
        var base = request("event-1", "bedtime");
        var invalid = new OnboardingConversationService.CreateRequest(
                base.installationId(), base.localEventId(), base.careEntryId(), base.registryRevision(),
                base.generationScene(), base.locale(), "evening|night", base.babyNickname());

        assertThatThrownBy(() -> service.create(invalid))
                .isInstanceOfSatisfying(ContractException.class,
                        exception -> assertThat(exception.code()).isEqualTo("invalid_time_band"));
        assertThat(generator.calls).isZero();
    }

    private OnboardingConversationService.CreateRequest request(String eventId, String sceneKey) {
        var careEntryId = switch (sceneKey) {
            case "bedtime" -> "care.bedtime_soothing";
            case "feeding" -> "care.feeding_now";
            default -> "care.bedtime_soothing";
        };
        return new OnboardingConversationService.CreateRequest(
                "install-test-1234", eventId, careEntryId, "2026-08-14.1",
                new OnboardingConversationService.GenerationScene(
                        "babytalk.care", sceneKey, 1, Map.of("parentTonePreference", "short_gentle")),
                "zh-CN", "evening", null);
    }

    private static final class FakeStore implements OnboardingConversationStore {
        private final Map<String, StoredConversation> rows = new HashMap<>();

        @Override
        public StoredConversation find(String installationRefHash, String localEventId) {
            return rows.get(installationRefHash + "|" + localEventId);
        }

        @Override
        public int reserve(StoredConversation conversation) {
            var key = conversation.installationRefHash() + "|" + conversation.localEventId();
            return rows.putIfAbsent(key, conversation) == null ? 1 : 0;
        }

        @Override
        public int activate(String conversationId, String generatedContentId, String utteranceId,
                            String englishText, String chineseText, String pronunciationHint,
                            String audioRef, java.time.OffsetDateTime expiresAt,
                            java.time.OffsetDateTime updatedAt) {
            var entry = rows.entrySet().stream()
                    .filter(candidate -> candidate.getValue().conversationId().equals(conversationId))
                    .findFirst().orElse(null);
            if (entry == null || !"generating".equals(entry.getValue().status())) {
                return 0;
            }
            var row = entry.getValue();
            entry.setValue(new StoredConversation(
                    row.conversationId(), row.installationRefHash(), row.localEventId(), row.requestFingerprint(),
                    row.registryRevision(), row.careEntryId(), row.generationNamespace(), row.generationKey(),
                    row.generationVersion(), row.generationFacetsJson(), row.locale(), row.timeBand(),
                    generatedContentId, utteranceId, englishText, chineseText, pronunciationHint, audioRef,
                    "active", expiresAt, row.createdAt(), updatedAt));
            return 1;
        }

        @Override
        public int deleteReservation(String conversationId) {
            var key = rows.entrySet().stream()
                    .filter(entry -> entry.getValue().conversationId().equals(conversationId)
                            && "generating".equals(entry.getValue().status()))
                    .map(Map.Entry::getKey).findFirst().orElse(null);
            return key != null && rows.remove(key) != null ? 1 : 0;
        }

        @Override
        public int extendExpiry(String conversationId, java.time.OffsetDateTime expiresAt,
                                java.time.OffsetDateTime updatedAt) {
            return rows.values().stream().anyMatch(row ->
                    row.conversationId().equals(conversationId)
                            && "active".equals(row.status())
                            && row.expiresAt().isAfter(updatedAt)) ? 1 : 0;
        }

        @Override
        public int deleteExpired(java.time.OffsetDateTime expiresAtOrBefore, int limit) {
            return 0;
        }

        @Override
        public int deleteExpiredIdentity(String installationRefHash, String localEventId,
                                         java.time.OffsetDateTime expiresAtOrBefore) {
            var key = installationRefHash + "|" + localEventId;
            var row = rows.get(key);
            if (row != null && !row.expiresAt().isAfter(expiresAtOrBefore)) {
                rows.remove(key);
                return 1;
            }
            return 0;
        }

        StoredConversation only() {
            return rows.values().iterator().next();
        }
    }

    private static final class FakeGenerator implements OnboardingConversationGenerator {
        private int calls;

        @Override
        public GeneratedUtterance generate(GenerationRequest request) {
            calls++;
            return new GeneratedUtterance(
                    "generated-1", "utterance-1", "Time to sleep.", "该睡觉啦。", "taim tu sliip", null);
        }
    }
}
