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
        assertThat(persistence.items)
                .filteredOn(item -> item.sanitizedSummarySnapshot() != null)
                .allSatisfy(item -> assertThat(item.sanitizedSummaryHash())
                        .isEqualTo(EvidenceSanitizer.sha256(item.sanitizedSummarySnapshot())));
    }

    @Test
    void rejectsForgedOrNonLowercaseSummaryHashAtConstructionBoundary() {
        assertThatThrownBy(() -> new EvidenceItem(
                "scene",
                ReplayMode.SNAPSHOT,
                "approved_external_snapshot",
                null,
                null,
                "scene_support",
                "宝宝哭时先抱稳",
                "f".repeat(64),
                0.90))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("sanitizedSummaryHash");
        assertThatThrownBy(() -> new EvidenceItem(
                "scene",
                ReplayMode.SNAPSHOT,
                "approved_external_snapshot",
                null,
                null,
                "scene_support",
                "宝宝哭时先抱稳",
                EvidenceSanitizer.sha256("宝宝哭时先抱稳").toUpperCase(),
                0.90))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("sanitizedSummaryHash");
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
    void reusedBundleRejectsCrossLineageEmptyNonSequentialAndVersionChangedSources() {
        var factory = factory(new CapturingPersistence(), request -> sufficientResult(request.retrievalTraceId()));
        var initial = factory.createInitial("pgc-5", 1, sufficientResult(trace(1)));

        assertThatThrownBy(() -> factory.deriveReused("pgc-other", 2, initial))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("same generatedContentId");
        assertThatThrownBy(() -> factory.deriveReused("pgc-5", 3, initial))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("next attempt");

        var empty = copy(initial, initial.generatedContentId(), initial.attemptNumber(),
                initial.evidencePolicyVersion(), initial.evidencePolicyContentHash(),
                initial.sanitizerVersion(), initial.bundleHash(), List.of());
        assertThatThrownBy(() -> factory.deriveReused("pgc-5", 2, empty))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("non-empty");

        var incomplete = copy(initial, initial.generatedContentId(), initial.attemptNumber(),
                initial.evidencePolicyVersion(), initial.evidencePolicyContentHash(),
                initial.sanitizerVersion(), initial.bundleHash(), baselineItems());
        assertThatThrownBy(() -> factory.deriveReused("pgc-5", 2, incomplete))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("minimum evidence policy");

        var oldPolicy = copy(initial, initial.generatedContentId(), initial.attemptNumber(),
                "old-policy", initial.evidencePolicyContentHash(),
                initial.sanitizerVersion(), initial.bundleHash(), initial.items());
        assertThatThrownBy(() -> factory.deriveReused("pgc-5", 2, oldPolicy))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("REFRESHED");

        var oldSanitizer = copy(initial, initial.generatedContentId(), initial.attemptNumber(),
                initial.evidencePolicyVersion(), initial.evidencePolicyContentHash(),
                "old-sanitizer", initial.bundleHash(), initial.items());
        assertThatThrownBy(() -> factory.deriveReused("pgc-5", 2, oldSanitizer))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("REFRESHED");
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
    void refreshedBundleRetrievesEachGapSeparatelyAndRequiresPerCallCoverage() {
        var requested = new ArrayList<Set<String>>();
        var factory = factory(new CapturingPersistence(), request -> {
            requested.add(request.requestedClaimTypes());
            var claim = request.requestedClaimTypes().iterator().next();
            var items = new ArrayList<>(baselineItems());
            if (claim.equals("scene_support")) {
                items.add(sceneItem());
            }
            return new EvidenceRetrievalResult(items, request.retrievalTraceId(), RetrievalStatus.INITIAL);
        });
        var request = new EvidenceRetrievalRequest(
                "宝宝哭闹",
                "0-2",
                "日常表达",
                Set.of("age_guidance", "scene_support"),
                trace(3));

        var refreshed = factory.createRefreshed("pgc-5", 2, request);

        assertThat(requested).containsExactlyInAnyOrder(Set.of("age_guidance"), Set.of("scene_support"));
        assertThat(refreshed.status()).isEqualTo(RetrievalStatus.REFRESHED);

        var missingGapFactory = factory(new CapturingPersistence(), request1 -> {
            var items = new ArrayList<>(baselineItems());
            if (request1.requestedClaimTypes().contains("scene_support")) {
                items.add(sceneItem());
            }
            if (request1.requestedClaimTypes().contains("age_guidance")) {
                items.removeIf(item -> item.claimType().equals("age_guidance"));
            }
            return new EvidenceRetrievalResult(items, request1.retrievalTraceId(), RetrievalStatus.INITIAL);
        });
        assertThatThrownBy(() -> missingGapFactory.createRefreshed("pgc-5", 2, request))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("gap claim age_guidance");
    }

    @Test
    void bundleHashChangesWhenOrderedMetadataChanges() {
        var factory = factory(new CapturingPersistence(), request -> sufficientResult(request.retrievalTraceId()));
        var original = sufficientResult(trace(1));
        var changedMetadata = new EvidenceRetrievalResult(
                original.items().stream()
                        .map(item -> item.claimType().equals("scene_support")
                                ? new EvidenceItem("scene-changed", item.replayMode(), item.sourceType(),
                                        item.sourceVersion(), item.strategyId(), item.claimType(),
                                        item.sanitizedSummary(), item.sanitizedSummaryHash(), item.confidence())
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
        var items = new ArrayList<>(baselineItems());
        items.add(sceneItem());
        return new EvidenceRetrievalResult(items,
                traceId,
                RetrievalStatus.INITIAL);
    }

    private static List<EvidenceItem> baselineItems() {
        return List.of(
                reference("age", "age_guidance", "age guidance"),
                reference("pressure", "low_pressure_delivery", "low pressure"),
                reference("speak", "parent_speakability", "short phrases"));
    }

    private static EvidenceItem sceneItem() {
        var summary = "宝宝哭时先抱稳";
        return new EvidenceItem(
                "scene",
                ReplayMode.SNAPSHOT,
                "approved_external_snapshot",
                null,
                null,
                "scene_support",
                summary,
                EvidenceSanitizer.sha256(summary),
                0.90);
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
                EvidenceSanitizer.sha256(summary),
                0.90);
    }

    private static FrozenEvidenceBundle copy(
            FrozenEvidenceBundle source,
            String generatedContentId,
            int attemptNumber,
            String policyVersion,
            String policyHash,
            String sanitizerVersion,
            String bundleHash,
            List<EvidenceItem> items
    ) {
        return new FrozenEvidenceBundle(
                source.evidenceBundleId(),
                generatedContentId,
                attemptNumber,
                source.derivedFromBundleId(),
                source.status(),
                source.retrievalTraceId(),
                policyVersion,
                policyHash,
                sanitizerVersion,
                bundleHash,
                items,
                source.createdAt());
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
