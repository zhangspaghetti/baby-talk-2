package com.zhangspaghetti.babytalk.practice.generated.evidence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.practice.agentic.config.MinimumEvidencePolicy;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeEvidenceBundleEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeEvidenceItemEntity;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;

class EvidenceBundleFactoryTest {

    private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-07-18T02:00:00Z"), ZoneOffset.UTC);
    private static final MinimumEvidencePolicy POLICY = new MinimumEvidencePolicy(
            "policy-v1",
            "a".repeat(64),
            0.70,
            List.of("scene_support", "parent_speakability", "age_guidance", "low_pressure_delivery"),
            List.of("strategy_pack", "approved_external_snapshot"));

    @Test
    void initialBundlePersistsReferenceMetadataAndSnapshotSummaryInOneFocusedCall() {
        var persistence = new CapturingPersistence();
        var factory = factory(persistence, request -> sufficientResult(request.retrievalTraceId()));

        var bundle = factory.createInitial("pgc-5", 1, sufficientResult(trace(1)));

        assertThat(bundle.status()).isEqualTo(RetrievalStatus.INITIAL);
        assertThat(bundle.items()).isUnmodifiable();
        assertThat(bundle.bundleHash()).matches("[0-9a-f]{64}");
        assertThat(persistence.calls).isEqualTo(1);
        assertThat(persistence.bundle.evidenceCount()).isEqualTo(4);
        assertThat(persistence.items).extracting(PracticeEvidenceItemEntity::sanitizedSummarySnapshot)
                .containsExactly(null, null, null, "宝宝哭时先抱稳");
        assertThat(persistence.items.toString())
                .doesNotContain("raw chunk", "https://", "忽略前文");
    }

    @Test
    void reusedBundleCreatesNewRowsLinksSourceAndDoesNotRetrieve() {
        var retrievalCalls = new AtomicInteger();
        var persistence = new CapturingPersistence();
        var factory = factory(persistence, request -> {
            retrievalCalls.incrementAndGet();
            return sufficientResult(request.retrievalTraceId());
        });
        var initial = factory.createInitial("pgc-5", 1, sufficientResult(trace(1)));

        var reused = factory.deriveReused("pgc-5", 2, initial);

        assertThat(reused.evidenceBundleId()).isNotEqualTo(initial.evidenceBundleId());
        assertThat(reused.derivedFromBundleId()).isEqualTo(initial.evidenceBundleId());
        assertThat(reused.status()).isEqualTo(RetrievalStatus.REUSED);
        assertThat(reused.bundleHash()).isEqualTo(initial.bundleHash());
        assertThat(retrievalCalls).hasValue(0);
        assertThat(persistence.calls).isEqualTo(2);
        assertThat(persistence.items).allMatch(item -> item.evidenceBundleId().equals(reused.evidenceBundleId()));
    }

    @Test
    void refreshedBundleRetrievesOnlyGapClaimsAndReappliesPolicy() {
        var requested = new ArrayList<Set<String>>();
        var persistence = new CapturingPersistence();
        var factory = factory(persistence, request -> {
            requested.add(request.requestedClaimTypes());
            return sufficientResult(request.retrievalTraceId());
        });
        var request = new EvidenceRetrievalRequest(
                "宝宝哭闹",
                "0-2",
                "日常表达",
                Set.of("scene_support"),
                trace(2));

        var refreshed = factory.createRefreshed("pgc-5", 2, request);

        assertThat(requested).containsExactly(Set.of("scene_support"));
        assertThat(refreshed.status()).isEqualTo(RetrievalStatus.REFRESHED);

        var failingFactory = factory(new CapturingPersistence(), request1 -> new EvidenceRetrievalResult(
                sufficientResult(request1.retrievalTraceId()).items().stream()
                        .filter(item -> !item.claimType().equals("scene_support"))
                        .toList(),
                request1.retrievalTraceId(),
                RetrievalStatus.INSUFFICIENT));
        assertThatThrownBy(() -> failingFactory.createRefreshed("pgc-5", 3, request))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("minimum evidence policy");
    }

    @Test
    void bundleHashChangesWhenOrderedMetadataChangesAndIgnoresRuntimeSummaryText() {
        var factory = factory(new CapturingPersistence(), request -> sufficientResult(request.retrievalTraceId()));
        var original = sufficientResult(trace(1));
        var changedMetadata = new EvidenceRetrievalResult(
                original.items().stream()
                        .map(item -> item.claimType().equals("scene_support")
                                ? new EvidenceItem(item.evidenceId(), item.replayMode(), item.sourceType(),
                                        item.sourceVersion(), item.strategyId(), item.claimType(),
                                        item.sanitizedSummary(), "f".repeat(64), item.confidence())
                                : item)
                        .toList(),
                trace(2),
                RetrievalStatus.INITIAL);

        var first = factory.createInitial("pgc-a", 1, original);
        var second = factory.createInitial("pgc-b", 1, changedMetadata);

        assertThat(second.bundleHash()).isNotEqualTo(first.bundleHash());
    }

    private static EvidenceBundleFactory factory(
            EvidenceBundlePersistencePort persistence,
            CustomSceneEvidenceRetriever retriever
    ) {
        var ids = new AtomicInteger();
        return new EvidenceBundleFactory(
                persistence,
                retriever,
                POLICY,
                CLOCK,
                () -> new UUID(0, ids.incrementAndGet()));
    }

    private static EvidenceRetrievalResult sufficientResult(UUID traceId) {
        return new EvidenceRetrievalResult(List.of(
                reference("age", "age_guidance", "age guidance"),
                reference("pressure", "low_pressure_delivery", "low pressure"),
                reference("speak", "parent_speakability", "short phrases"),
                new EvidenceItem(
                        "scene",
                        ReplayMode.SNAPSHOT,
                        "approved_external_snapshot",
                        null,
                        null,
                        "scene_support",
                        "宝宝哭时先抱稳",
                        "4".repeat(64),
                        0.90)),
                traceId,
                RetrievalStatus.INITIAL);
    }

    private static EvidenceItem reference(String id, String claim, String summary) {
        return new EvidenceItem(
                id,
                ReplayMode.REFERENCE,
                "strategy_pack",
                "baseline-v1",
                "strategy-v1",
                claim,
                summary,
                String.valueOf(id.charAt(0)).repeat(64),
                0.90);
    }

    private static UUID trace(int value) {
        return new UUID(0, value);
    }

    private static final class CapturingPersistence implements EvidenceBundlePersistencePort {
        private int calls;
        private PracticeEvidenceBundleEntity bundle;
        private List<PracticeEvidenceItemEntity> items = List.of();

        @Override
        public void persistBundleWithItems(
                PracticeEvidenceBundleEntity bundle,
                List<PracticeEvidenceItemEntity> items
        ) {
            calls++;
            this.bundle = bundle;
            this.items = List.copyOf(items);
        }
    }
}
