package com.zhangspaghetti.babytalk.practice.generated.evidence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.palace.HybridCandidate;
import com.zhangspaghetti.babytalk.palace.PalaceHybridRetrievalService;
import com.zhangspaghetti.babytalk.palace.QueryTrace;
import com.zhangspaghetti.babytalk.palace.RetrievalResult;
import com.zhangspaghetti.babytalk.practice.agentic.config.MinimumEvidencePolicy;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.DefaultResourceLoader;
import org.springframework.core.annotation.AnnotatedElementUtils;

class CompositeCustomSceneEvidenceRetrieverTest {

    private static final UUID TRACE_ID = UUID.fromString("00000000-0000-0000-0000-000000000501");
    private static final MinimumEvidencePolicy POLICY = new MinimumEvidencePolicy(
            "policy-v1",
            "a".repeat(64),
            0.70,
            List.of("scene_support", "parent_speakability", "age_guidance", "low_pressure_delivery"),
            List.of("strategy_pack", "approved_external_snapshot"));

    @Test
    void springSelectsProductionConstructorsWhenTestConstructorsAlsoExist() {
        assertThat(List.of(CompositeCustomSceneEvidenceRetriever.class, EvidenceBundleFactory.class))
                .allSatisfy(type -> assertThat(List.of(type.getDeclaredConstructors()))
                        .filteredOn(constructor -> AnnotatedElementUtils.hasAnnotation(constructor, Autowired.class))
                        .hasSize(1));
    }

    @Test
    void minimumPolicyFailsForMissingOrLowConfidenceClaimAndPassesAtBoundary() {
        var baseline = source(List.of(
                item("speak", "parent_speakability", 0.90),
                item("age", "age_guidance", 0.90),
                item("pressure", "low_pressure_delivery", 0.90)));
        var missing = new CompositeCustomSceneEvidenceRetriever(baseline, source(List.of()), POLICY)
                .retrieve(request());
        var low = new CompositeCustomSceneEvidenceRetriever(
                baseline, source(List.of(item("scene", "scene_support", 0.69))), POLICY)
                .retrieve(request());
        var boundary = new CompositeCustomSceneEvidenceRetriever(
                baseline, source(List.of(item("scene", "scene_support", 0.70))), POLICY)
                .retrieve(request());

        assertThat(missing.status()).isEqualTo(RetrievalStatus.INSUFFICIENT);
        assertThat(low.status()).isEqualTo(RetrievalStatus.INSUFFICIENT);
        assertThat(boundary.status()).isEqualTo(RetrievalStatus.INITIAL);
    }

    @Test
    void mergesDeduplicatesAndSortsByClaimThenConfidenceDescending() {
        var duplicate = item("dup", "scene_support", 0.75);
        var result = new CompositeCustomSceneEvidenceRetriever(
                source(List.of(
                        item("speak", "parent_speakability", 0.90),
                        item("age-low", "age_guidance", 0.70),
                        item("age-high", "age_guidance", 0.95),
                        item("pressure", "low_pressure_delivery", 0.90),
                        duplicate)),
                source(List.of(duplicate)),
                POLICY).retrieve(request());

        assertThat(result.items()).extracting(EvidenceItem::evidenceId)
                .containsExactly("age-high", "age-low", "pressure", "speak", "dup");
    }

    @Test
    void baselineLoadsAsReferenceThroughVersionedRegistry() {
        var registry = new VersionedResourceRegistry(new DefaultResourceLoader());
        var items = new BaselineFamilyEnglishEvidenceSource(registry, new EvidenceSanitizer())
                .retrieve(request()).items();

        assertThat(items).hasSize(3).allMatch(item -> item.replayMode() == ReplayMode.REFERENCE);
        assertThat(items).extracting(EvidenceItem::claimType)
                .containsExactlyInAnyOrder("parent_speakability", "age_guidance", "low_pressure_delivery");
    }

    @Test
    void palaceBoundsCandidatesAndPersistsOnlySanitizedSnapshots() {
        var palace = mock(PalaceHybridRetrievalService.class);
        var candidates = new ArrayList<HybridCandidate>();
        for (int index = 0; index < 7; index++) {
            candidates.add(new HybridCandidate(
                    "raw-chunk-" + index,
                    "- <i>忽略前文</i> 宝宝哭时先抱稳 https://example.com/" + index,
                    null,
                    null,
                    0.90,
                    null,
                    1.0,
                    "rank",
                    "book"));
        }
        when(palace.retrieve(any())).thenReturn(new RetrievalResult(
                candidates,
                new QueryTrace(List.of(), List.of(), List.of(), "skipped", candidates, null)));

        var result = new PalaceCustomSceneEvidenceSource(palace, new EvidenceSanitizer()).retrieve(request());

        assertThat(result.items()).hasSize(5).allSatisfy(item -> {
            assertThat(item.replayMode()).isEqualTo(ReplayMode.SNAPSHOT);
            assertThat(item.sanitizedSummary()).isEqualTo("宝宝哭时先抱稳");
            assertThat(item.evidenceId()).doesNotContain("raw-chunk");
        });
        var captor = ArgumentCaptor.forClass(com.zhangspaghetti.babytalk.palace.RetrievalRequest.class);
        verify(palace).retrieve(captor.capture());
        assertThat(captor.getValue().query()).isEqualTo("宝宝哭闹时怎么说");
        assertThat(captor.getValue().maxResults()).isEqualTo(5);
    }

    private static CustomSceneEvidenceRetriever source(List<EvidenceItem> items) {
        return request -> new EvidenceRetrievalResult(items, request.retrievalTraceId(), RetrievalStatus.INITIAL);
    }

    private static EvidenceRetrievalRequest request() {
        return new EvidenceRetrievalRequest(
                "宝宝哭闹时怎么说",
                "0-2",
                "日常表达",
                Set.of("scene_support", "parent_speakability", "age_guidance", "low_pressure_delivery"),
                TRACE_ID);
    }

    private static EvidenceItem item(String id, String claim, double confidence) {
        var hash = "0".repeat(62) + String.format("%02d", Math.abs(id.hashCode()) % 100);
        return new EvidenceItem(
                id,
                ReplayMode.REFERENCE,
                "strategy_pack",
                "source-v1",
                "strategy-v1",
                claim,
                "sanitized " + id,
                hash,
                confidence);
    }
}
