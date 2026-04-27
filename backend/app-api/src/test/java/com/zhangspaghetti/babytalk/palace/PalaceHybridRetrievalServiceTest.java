package com.zhangspaghetti.babytalk.palace;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.kg.KgEntityRepository;
import com.zhangspaghetti.babytalk.palace.PalaceKeywordRepository.ChunkResult;
import com.zhangspaghetti.babytalk.palace.projection.PalaceBridgeEdgeRepository;
import com.zhangspaghetti.babytalk.palace.projection.PalaceProjectionVersionRepository;
import com.zhangspaghetti.babytalk.palace.projection.PalaceQueryTraceRepository;
import com.zhangspaghetti.babytalk.palace.projection.PalaceRoomRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.ai.document.Document;

@ExtendWith(MockitoExtension.class)
class PalaceHybridRetrievalServiceTest {

    @Mock
    private PalaceSearchService palaceSearchService;

    @Mock
    private PalaceKeywordRepository palaceKeywordRepository;

    @Mock
    private KgEntityRepository kgEntityRepository;

    @Mock
    private PalaceRoomRepository palaceRoomRepository;

    @Mock
    private PalaceBridgeEdgeRepository palaceBridgeEdgeRepository;

    @Mock
    private PalaceProjectionVersionRepository palaceProjectionVersionRepository;

    @Mock
    private PalaceQueryTraceRepository palaceQueryTraceRepository;

    private PalaceHybridRetrievalService service;

    @BeforeEach
    void setUp() {
        service = new PalaceHybridRetrievalService(
                palaceSearchService,
                palaceKeywordRepository,
                kgEntityRepository,
                palaceRoomRepository,
                palaceBridgeEdgeRepository,
                palaceProjectionVersionRepository,
                palaceQueryTraceRepository,
                new ObjectMapper(),
                Clock.fixed(Instant.parse("2026-04-27T08:00:00Z"), ZoneOffset.UTC));

        when(kgEntityRepository.findByNameLike(anyString())).thenReturn(List.of());
        when(palaceQueryTraceRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
    }

    @Test
    void deterministicMergeRanksHybridCandidateAboveSingleChannelCandidate() {
        when(palaceRoomRepository.count()).thenReturn(0L);
        when(palaceSearchService.search(eq("早期沟通"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of(
                        makeDocument("00000000-0000-0000-0000-0000000000aa", "混合命中的内容", 0.80d, "0-1", "language_development", "early_communication"),
                        makeDocument("chunk-b", "仅向量命中的内容", 0.60d, "0-1", "language_development", "early_communication")));
        when(palaceKeywordRepository.searchByKeywords(eq("早期沟通"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of(
                        new ChunkResult(UUID.fromString("00000000-0000-0000-0000-00000000000a"), "关键字单命中", Map.of(
                                "wing", "language_development",
                                "room", "early_communication",
                                "age_range", "0-1"
                        ), 0.30d),
                        new ChunkResult(UUID.fromString("00000000-0000-0000-0000-0000000000aa"), "混合命中的内容", Map.of(
                                "wing", "language_development",
                                "room", "early_communication",
                                "age_range", "0-1"
                        ), 0.90d)));

        RetrievalResult result = service.retrieve(new RetrievalRequest(
                "早期沟通",
                "language_development",
                "early_communication",
                null,
                10,
                2));

        assertThat(result.rankedCandidates()).hasSize(3);
        HybridCandidate top = result.rankedCandidates().get(0);
        assertThat(top.chunkId()).isEqualTo("00000000-0000-0000-0000-0000000000aa");
        assertThat(top.vectorScore()).isEqualTo(0.80d);
        assertThat(top.keywordScore()).isEqualTo(0.90d);
        assertThat(top.mergedScore()).isGreaterThan(result.rankedCandidates().get(1).mergedScore());
        assertThat(result.trace().temporalRuleApplied()).isEqualTo("skipped");

        verify(palaceQueryTraceRepository).save(any());
    }

    @Test
    void ageBoostDifferentiatesSameCandidateBetweenSixAndTwentyFourMonths() {
        when(palaceRoomRepository.count()).thenReturn(0L);
        when(palaceSearchService.search(eq("宝宝说话"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of(makeDocument("chunk-infant", "婴儿期语言输入", 1.0d, "0-1", "language_development", "early_communication")));
        when(palaceKeywordRepository.searchByKeywords(eq("宝宝说话"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of());

        RetrievalResult sixMonths = service.retrieve(new RetrievalRequest(
                "宝宝说话",
                "language_development",
                "early_communication",
                6,
                10,
                2));
        RetrievalResult twentyFourMonths = service.retrieve(new RetrievalRequest(
                "宝宝说话",
                "language_development",
                "early_communication",
                24,
                10,
                2));

        assertThat(sixMonths.rankedCandidates()).hasSize(1);
        assertThat(twentyFourMonths.rankedCandidates()).hasSize(1);
        assertThat(sixMonths.rankedCandidates().get(0).effectiveScore())
                .isGreaterThan(twentyFourMonths.rankedCandidates().get(0).effectiveScore());
        assertThat(sixMonths.rankedCandidates().get(0).ageBoostApplied()).isEqualTo(1.0d);
        assertThat(twentyFourMonths.rankedCandidates().get(0).ageBoostApplied()).isEqualTo(0.8d);
        assertThat(twentyFourMonths.trace().temporalRuleApplied()).contains("fallback-floor-0.8");
    }

    @Test
    void temporalFallbackFiresWhenFewerThanThreeCandidatesStayAboveDefaultFloor() {
        when(palaceRoomRepository.count()).thenReturn(0L);
        when(palaceSearchService.search(eq("亲子互动"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of(
                        makeDocument("chunk-a", "12到36个月候选A", 1.0d, "1-3", "language_development", "early_communication"),
                        makeDocument("chunk-b", "12到36个月候选B", 0.9d, "1-3", "language_development", "early_communication")));
        when(palaceKeywordRepository.searchByKeywords(eq("亲子互动"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of());

        RetrievalResult result = service.retrieve(new RetrievalRequest(
                "亲子互动",
                "language_development",
                "early_communication",
                6,
                10,
                2));

        assertThat(result.rankedCandidates()).hasSize(2);
        assertThat(result.trace().temporalRuleApplied()).contains("fallback-floor-0.8");
        assertThat(result.rankedCandidates())
                .allSatisfy(candidate -> assertThat(candidate.ageBoostApplied()).isGreaterThanOrEqualTo(0.8d));
    }

    @Test
    void emptyProjectionFallsBackGracefullyAndPersistsNotReadyTrace() {
        when(palaceRoomRepository.count()).thenReturn(0L);
        when(palaceSearchService.search(eq("语言启蒙"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of(makeDocument("chunk-ready", "仍然返回候选", 0.88d, "0-1", "language_development", "early_communication")));
        when(palaceKeywordRepository.searchByKeywords(eq("语言启蒙"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of());

        RetrievalResult result = service.retrieve(new RetrievalRequest(
                "语言启蒙",
                "language_development",
                "early_communication",
                null,
                10,
                2));

        assertThat(result.rankedCandidates()).isNotEmpty();
        assertThat(result.trace().projectionVersionUsed()).isEqualTo("not-ready");
        assertThat(result.trace().entryRooms()).containsExactly("language_development/early_communication");

        ArgumentCaptor<com.zhangspaghetti.babytalk.palace.projection.PalaceQueryTrace> captor =
                ArgumentCaptor.forClass(com.zhangspaghetti.babytalk.palace.projection.PalaceQueryTrace.class);
        verify(palaceQueryTraceRepository).save(captor.capture());
        assertThat(captor.getValue().getProjectionVersionUsed()).isNull();
        assertThat(captor.getValue().getEntryRooms().toString()).contains("language_development/early_communication");
    }

    private Document makeDocument(
            String id,
            String text,
            double score,
            String ageRange,
            String wing,
            String room) {
        return new Document(id, text, Map.of(
                "score", score,
                "age_range", ageRange,
                "wing", wing,
                "room", room,
                "source_book", "《测试书》"
        ));
    }
}
