package com.zhangspaghetti.babytalk.onboarding.conversation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.onboarding.conversation.OnboardingConversationStore.StoredConversation;
import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentKeyFactory;
import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentOwnerProperties;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;

class OnboardingConversationTurnServiceTest {

    private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-08-14T10:00:00Z"), ZoneOffset.UTC);
    private final OnboardingConversationStore conversations = mock(OnboardingConversationStore.class);
    private final FakeTurnStore turns = new FakeTurnStore();
    private final CapturingGenerator generator = new CapturingGenerator();
    private final PracticeGeneratedContentKeyFactory keys = new PracticeGeneratedContentKeyFactory(
            new PracticeGeneratedContentOwnerProperties("v1", "0123456789abcdef0123456789abcdef"));
    private final OnboardingConversationTurnService service = new OnboardingConversationTurnService(
            conversations, turns, generator, keys,
            new OnboardingAudioCapabilityService(keys, CLOCK), CLOCK);

    @Test
    void noReactionReachesGeneratorAndExactReplayDoesNotGenerateTwice() {
        when(conversations.findByConversationId("onbc_test_1234")).thenReturn(conversation(false));

        var first = service.next("onbc_test_1234", request("turn-event-1", false, null, null));
        var replay = service.next("onbc_test_1234", request("turn-event-1", false, null, null));

        assertThat(first.utterance().utteranceId()).isEqualTo("next-utterance-1");
        assertThat(replay.utterance().utteranceId()).isEqualTo(first.utterance().utteranceId());
        assertThat(generator.calls).isOne();
        assertThat(generator.last.parentAction()).isEqualTo("said_it");
        assertThat(generator.last.reactionProvided()).isFalse();
        assertThat(generator.last.reaction()).isNull();
        assertThat(generator.last.reactionText()).isNull();
    }

    @Test
    void everyCanonicalReactionReachesGeneratorUnchanged() {
        when(conversations.findByConversationId("onbc_test_1234")).thenReturn(conversation(false));

        for (var reaction : new String[] {"cooperating", "hesitant", "resisting", "no_response", "other"}) {
            service.next("onbc_test_1234", request("turn-" + reaction, true, reaction,
                    "other".equals(reaction) ? "宝宝想抱一会儿" : null));
            assertThat(generator.last.reaction()).isEqualTo(reaction);
        }
        assertThat(turns.rows.values().toString()).doesNotContain("宝宝想抱一会儿");
    }

    @Test
    void invalidReactionShapesRejectWithoutGenerating() {
        when(conversations.findByConversationId("onbc_test_1234")).thenReturn(conversation(false));

        assertThatThrownBy(() -> service.next("onbc_test_1234", request("turn-bad-1", false, "other", null)))
                .isInstanceOf(ContractException.class);
        assertThatThrownBy(() -> service.next("onbc_test_1234", request("turn-bad-2", true, "cooperating", "private")))
                .isInstanceOf(ContractException.class);
        assertThatThrownBy(() -> service.next("onbc_test_1234", request("turn-bad-3", true, "unknown", null)))
                .isInstanceOf(ContractException.class);
        assertThat(generator.calls).isZero();
    }

    @Test
    void unknownExpiredAndWrongPreviousUtteranceFailClosed() {
        assertThatThrownBy(() -> service.next("onbc_test_1234", request("turn-missing", false, null, null)))
                .isInstanceOfSatisfying(ContractException.class,
                        error -> assertThat(error.status().value()).isEqualTo(404));
        when(conversations.findByConversationId("onbc_test_1234")).thenReturn(conversation(true));
        assertThatThrownBy(() -> service.next("onbc_test_1234", request("turn-expired", false, null, null)))
                .isInstanceOfSatisfying(ContractException.class,
                        error -> assertThat(error.status().value()).isEqualTo(404));
        when(conversations.findByConversationId("onbc_test_1234")).thenReturn(conversation(false));
        var mismatch = request("turn-mismatch", false, null, null);
        mismatch = new OnboardingConversationTurnService.NextRequest(
                mismatch.localEventId(), "wrong-utterance", mismatch.parentAction(),
                mismatch.reactionProvided(), mismatch.reaction(), mismatch.reactionText(),
                mismatch.generationScene());
        var finalMismatch = mismatch;
        assertThatThrownBy(() -> service.next("onbc_test_1234", finalMismatch))
                .isInstanceOfSatisfying(ContractException.class,
                        error -> assertThat(error.status().value()).isEqualTo(404));
        assertThat(generator.calls).isZero();
    }

    @Test
    void concurrentDuplicateWaitsForAndReturnsOriginalTurn() throws Exception {
        when(conversations.findByConversationId("onbc_test_1234")).thenReturn(conversation(false));
        generator.holdNext();

        var first = CompletableFuture.supplyAsync(() ->
                service.next("onbc_test_1234", request("turn-concurrent", false, null, null)));
        assertThat(generator.entered.await(2, TimeUnit.SECONDS)).isTrue();
        var second = CompletableFuture.supplyAsync(() ->
                service.next("onbc_test_1234", request("turn-concurrent", false, null, null)));
        Thread.sleep(100);

        assertThat(generator.calls).isOne();
        assertThat(second).isNotDone();
        generator.release.countDown();
        assertThat(second.get(2, TimeUnit.SECONDS).utterance().utteranceId())
                .isEqualTo(first.get(2, TimeUnit.SECONDS).utterance().utteranceId());
        assertThat(generator.calls).isOne();
    }

    @Test
    void expiredGenerationLeaseIsAtomicallyReplacedAfterCrash() {
        when(conversations.findByConversationId("onbc_test_1234")).thenReturn(conversation(false));
        turns.ignoreReservationDeletes = true;
        generator.failNext = true;

        assertThatThrownBy(() ->
                service.next("onbc_test_1234", request("turn-crash", false, null, null)))
                .isInstanceOf(IllegalStateException.class);
        var key = "onbc_test_1234|turn-crash";
        var stale = turns.rows.get(key);
        turns.rows.put(key, new OnboardingConversationTurnStore.StoredTurn(
                stale.turnId(), stale.conversationId(), stale.localEventId(), stale.requestFingerprint(),
                stale.previousUtteranceId(), stale.parentAction(), stale.reactionProvided(), stale.reaction(),
                stale.generatedContentId(), stale.utteranceId(), stale.englishText(), stale.chineseText(),
                stale.pronunciationHint(), stale.audioRef(), stale.status(),
                OffsetDateTime.now(CLOCK).minusSeconds(1), stale.createdAt(), stale.updatedAt()));
        turns.ignoreReservationDeletes = false;
        generator.failNext = false;

        var recovered = service.next("onbc_test_1234", request("turn-crash", false, null, null));

        assertThat(recovered.utterance().utteranceId()).isEqualTo("next-utterance-1");
        assertThat(generator.calls).isEqualTo(2);
    }

    private OnboardingConversationTurnService.NextRequest request(
            String eventId, boolean reactionProvided, String reaction, String reactionText) {
        return new OnboardingConversationTurnService.NextRequest(
                eventId, "utterance-first-1", "said_it", reactionProvided, reaction, reactionText,
                new OnboardingConversationTurnService.GenerationScene(
                        "babytalk.care", "bedtime", 1, Map.of("parentTonePreference", "short_gentle")));
    }

    private StoredConversation conversation(boolean expired) {
        var expiresAt = OffsetDateTime.now(CLOCK).plusHours(expired ? -1 : 1);
        return new StoredConversation(
                "onbc_test_1234", "installation_hash", "create-event", "ocf_hash",
                "2026-08-14.1", "care.bedtime_soothing", "babytalk.care", "bedtime", 1,
                "{\"parentTonePreference\":\"short_gentle\"}", "zh-CN", "evening",
                "generated-first-1", "utterance-first-1", "Time to sleep.", "该睡觉啦。",
                "taim tu sliip", null, "active", expiresAt,
                OffsetDateTime.now(CLOCK).minusMinutes(1), OffsetDateTime.now(CLOCK),
                "owner_" + "b".repeat(64));
    }

    private static final class CapturingGenerator implements OnboardingConversationGenerator {
        int calls;
        NextGenerationRequest last;
        CountDownLatch entered = new CountDownLatch(0);
        CountDownLatch release = new CountDownLatch(0);
        boolean failNext;

        void holdNext() {
            entered = new CountDownLatch(1);
            release = new CountDownLatch(1);
        }

        @Override
        public GeneratedUtterance generate(GenerationRequest request) {
            throw new UnsupportedOperationException();
        }

        @Override
        public GeneratedUtterance generateNext(NextGenerationRequest request) {
            calls += 1;
            last = request;
            if (failNext) throw new IllegalStateException("simulated process crash");
            entered.countDown();
            try {
                if (!release.await(2, TimeUnit.SECONDS)) {
                    throw new IllegalStateException("timed out waiting for generator release");
                }
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                throw new IllegalStateException("generator interrupted", exception);
            }
            return new GeneratedUtterance(
                    "generated-next-1", "next-utterance-1", "We can go slowly.",
                    "我们可以慢慢来。", "wi kan go slo-li", null);
        }
    }

    private static final class FakeTurnStore implements OnboardingConversationTurnStore {
        final Map<String, StoredTurn> rows = new LinkedHashMap<>();
        boolean ignoreReservationDeletes;

        @Override
        public synchronized StoredTurn find(String conversationId, String localEventId) {
            return rows.get(conversationId + "|" + localEventId);
        }

        @Override
        public synchronized StoredTurn findByUtterance(String conversationId, String utteranceId) {
            return rows.values().stream()
                    .filter(row -> row.conversationId().equals(conversationId))
                    .filter(row -> utteranceId.equals(row.utteranceId()))
                    .findFirst().orElse(null);
        }

        @Override
        public synchronized int reserve(StoredTurn turn) {
            return rows.putIfAbsent(turn.conversationId() + "|" + turn.localEventId(), turn) == null ? 1 : 0;
        }

        @Override
        public synchronized int activate(String turnId, String generatedContentId, String utteranceId,
                            String englishText, String chineseText, String pronunciationHint,
                            String audioRef, OffsetDateTime expiresAt, OffsetDateTime updatedAt) {
            var entry = rows.entrySet().stream()
                    .filter(candidate -> candidate.getValue().turnId().equals(turnId))
                    .findFirst().orElse(null);
            if (entry == null) return 0;
            var row = entry.getValue();
            entry.setValue(new StoredTurn(
                    row.turnId(), row.conversationId(), row.localEventId(), row.requestFingerprint(),
                    row.previousUtteranceId(), row.parentAction(), row.reactionProvided(), row.reaction(),
                    generatedContentId, utteranceId, englishText, chineseText, pronunciationHint,
                    audioRef, "active", expiresAt, row.createdAt(), updatedAt));
            return 1;
        }

        @Override
        public synchronized int deleteReservation(String turnId) {
            if (ignoreReservationDeletes) return 0;
            var removed = rows.entrySet().removeIf(entry -> entry.getValue().turnId().equals(turnId));
            return removed ? 1 : 0;
        }

        @Override
        public synchronized int deleteExpiredReservation(
                String conversationId, String localEventId, OffsetDateTime expiresAtOrBefore) {
            var key = conversationId + "|" + localEventId;
            var row = rows.get(key);
            if (row == null || !"generating".equals(row.status())
                    || row.expiresAt().isAfter(expiresAtOrBefore)) return 0;
            rows.remove(key);
            return 1;
        }
    }
}
