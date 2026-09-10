package com.zhangspaghetti.babytalk.palace;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;
import com.zhangspaghetti.babytalk.kg.KgEntityRepository;
import com.zhangspaghetti.babytalk.palace.PalaceKeywordRepository.ChunkResult;
import com.zhangspaghetti.babytalk.palace.projection.PalaceBridgeEdgeRepository;
import com.zhangspaghetti.babytalk.palace.projection.PalaceProjectionVersion;
import com.zhangspaghetti.babytalk.palace.projection.PalaceProjectionVersionRepository;
import com.zhangspaghetti.babytalk.palace.projection.PalaceQueryTraceRepository;
import com.zhangspaghetti.babytalk.palace.projection.PalaceRoom;
import com.zhangspaghetti.babytalk.palace.projection.PalaceRoomRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.slf4j.LoggerFactory;
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
                JsonMapper.builder().build(),
                Clock.fixed(Instant.parse("2026-04-27T08:00:00Z"), ZoneOffset.UTC));

        when(kgEntityRepository.findByNameLike(anyString())).thenReturn(List.of());
    }

    @Test
    void testDeterministicRankingMerge() {
        when(palaceRoomRepository.count()).thenReturn(0L);
        when(palaceSearchService.search(eq("early communication"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of(
                        makeDocument("00000000-0000-0000-0000-0000000000aa", "candidate A", 0.9d, "0-3"),
                        makeDocument("00000000-0000-0000-0000-0000000000bb", "candidate B", 0.8d, "0-3")));
        when(palaceKeywordRepository.searchByKeywords(eq("early communication"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of(
                        makeKeywordChunk("00000000-0000-0000-0000-0000000000bb", "candidate B", 0.7d, "0-3"),
                        makeKeywordChunk("00000000-0000-0000-0000-0000000000cc", "candidate C", 0.6d, "0-3")));

        RetrievalResult result = service.retrieve(new RetrievalRequest(
                "early communication",
                "language_development",
                "early_communication",
                null,
                10,
                2));

        assertThat(result.rankedCandidates()).extracting(HybridCandidate::chunkId)
                .containsExactly(
                        "00000000-0000-0000-0000-0000000000bb",
                        "00000000-0000-0000-0000-0000000000aa",
                        "00000000-0000-0000-0000-0000000000cc");
        assertThat(result.rankedCandidates().get(0).mergedScore()).isGreaterThan(result.rankedCandidates().get(1).mergedScore());
        assertThat(result.rankedCandidates().get(0).mergedScore()).isGreaterThan(result.rankedCandidates().get(2).mergedScore());
        assertThat(result.trace().temporalRuleApplied()).isEqualTo("skipped");

        verify(palaceQueryTraceRepository).save(any());
    }

    @Test
    void testAgeBoostedDiffers6vs24Months() {
        when(palaceRoomRepository.count()).thenReturn(0L);
        when(palaceSearchService.search(eq("age aware ranking"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of(
                        makeDocument("00000000-0000-0000-0000-0000000000bb", "candidate X: infant friendly", 1.0d, "0-3"),
                        makeDocument("00000000-0000-0000-0000-0000000000aa", "candidate Y: toddler focused", 1.0d, "1-3")));
        when(palaceKeywordRepository.searchByKeywords(eq("age aware ranking"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of());

        RetrievalResult sixMonths = service.retrieve(new RetrievalRequest(
                "age aware ranking",
                "language_development",
                "early_communication",
                6,
                10,
                2));
        RetrievalResult twentyFourMonths = service.retrieve(new RetrievalRequest(
                "age aware ranking",
                "language_development",
                "early_communication",
                24,
                10,
                2));

        assertThat(sixMonths.rankedCandidates()).extracting(HybridCandidate::content)
                .containsExactly("candidate X: infant friendly", "candidate Y: toddler focused");
        assertThat(twentyFourMonths.rankedCandidates()).extracting(HybridCandidate::content)
                .containsExactly("candidate Y: toddler focused", "candidate X: infant friendly");
        assertThat(sixMonths.rankedCandidates().get(0).effectiveScore())
                .isGreaterThan(sixMonths.rankedCandidates().get(1).effectiveScore());
        assertThat(twentyFourMonths.rankedCandidates().get(0).effectiveScore())
                .isEqualTo(twentyFourMonths.rankedCandidates().get(1).effectiveScore());
        assertThat(sixMonths.trace().temporalRuleApplied()).contains("fallback-floor-0.8");
    }

    @Test
    void testTemporalFallbackBelowThreshold() {
        when(palaceRoomRepository.count()).thenReturn(0L);
        when(palaceSearchService.search(eq("fallback window"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of(
                        makeDocument("00000000-0000-0000-0000-000000000001", "candidate-1", 1.0d, "12-36"),
                        makeDocument("00000000-0000-0000-0000-000000000002", "candidate-2", 0.9d, "12-36"),
                        makeDocument("00000000-0000-0000-0000-000000000003", "candidate-3", 0.8d, "12-36"),
                        makeDocument("00000000-0000-0000-0000-000000000004", "candidate-4", 0.7d, "12-36"),
                        makeDocument("00000000-0000-0000-0000-000000000005", "candidate-5", 0.6d, "12-36")));
        when(palaceKeywordRepository.searchByKeywords(eq("fallback window"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of());

        RetrievalResult result = service.retrieve(new RetrievalRequest(
                "fallback window",
                "language_development",
                "early_communication",
                3,
                10,
                2));

        assertThat(result.rankedCandidates()).hasSize(5);
        assertThat(result.trace().temporalRuleApplied()).contains("fallback-floor-0.8");
        assertThat(result.rankedCandidates())
                .allSatisfy(candidate -> assertThat(candidate.ageBoostApplied()).isEqualTo(0.8d));
    }

    @Test
    void testProjectionNotReadyFallback() {
        when(palaceRoomRepository.count()).thenReturn(0L);
        when(palaceSearchService.search(eq("projection fallback"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of(makeDocument("00000000-0000-0000-0000-0000000000dd", "candidate survives", 0.88d, "0-3")));
        when(palaceKeywordRepository.searchByKeywords(eq("projection fallback"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of());

        RetrievalResult result = service.retrieve(new RetrievalRequest(
                "projection fallback",
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

    @Test
    void currentProjectionMembershipComesFromPersistedRoomScope() {
        var projectionRoom = new PalaceRoom(
                UUID.fromString("00000000-0000-0000-0000-000000000101"),
                "LANGUAGE_DEVELOPMENT",
                "EARLY_COMMUNICATION",
                "BABBLING_HALL",
                Instant.parse("2026-04-27T08:00:00Z"),
                1);
        var projectionVersion = new PalaceProjectionVersion(
                UUID.fromString("00000000-0000-0000-0000-000000000102"),
                7L,
                UUID.fromString("00000000-0000-0000-0000-000000000103"),
                Instant.parse("2026-04-27T08:00:00Z"),
                "current",
                1);
        when(palaceRoomRepository.count()).thenReturn(1L);
        when(palaceRoomRepository.findAll()).thenReturn(List.of(projectionRoom));
        when(palaceProjectionVersionRepository.findCurrentVersion()).thenReturn(Optional.of(projectionVersion));
        when(palaceSearchService.search(eq("projection scope"), eq(null), eq(null), anyInt()))
                .thenReturn(List.of(
                        makeDocument("00000000-0000-0000-0000-000000000111", "current", 0.70d, "0-3"),
                        new Document(
                                "00000000-0000-0000-0000-000000000112",
                                "stale",
                                Map.of(
                                        "score", 0.90d,
                                        "wing", "parenting_skills",
                                        "room", "overview"))));
        when(palaceKeywordRepository.searchByKeywords(eq("projection scope"), eq(null), eq(null), anyInt()))
                .thenReturn(List.of());

        var result = service.retrieve(new RetrievalRequest("projection scope", null, null, null, 5, 2));

        assertThat(result.trace().projectionVersionUsed()).isEqualTo("7");
        assertThat(result.rankedCandidates()).extracting(HybridCandidate::content)
                .containsExactly("current");
        assertThat(result.rankedCandidates())
                .filteredOn(candidate -> candidate.content().equals("current"))
                .singleElement()
                .extracting(HybridCandidate::currentProjectionMember)
                .isEqualTo(true);
        assertThat(JsonMapper.builder().build().writeValueAsString(result.rankedCandidates().get(0)))
                .doesNotContain("currentProjectionMember");
    }

    @Test
    void tracePersistenceFailureKeepsRankingAndLogsSafeStructuredWarningOnce() {
        when(palaceRoomRepository.count()).thenReturn(0L);
        when(palaceSearchService.search(eq("persistence failure"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of(makeDocument("00000000-0000-0000-0000-0000000000ee", "candidate survives", 0.88d, "0-3")));
        when(palaceKeywordRepository.searchByKeywords(eq("persistence failure"), eq("language_development"), eq("early_communication"), anyInt()))
                .thenReturn(List.of());
        doThrow(new IllegalStateException("sensitive trace content"))
                .when(palaceQueryTraceRepository)
                .save(any());

        Logger logger = (Logger) LoggerFactory.getLogger(PalaceHybridRetrievalService.class);
        ListAppender<ILoggingEvent> appender = new ListAppender<>();
        appender.start();
        logger.addAppender(appender);
        try {
            RetrievalResult result = service.retrieve(new RetrievalRequest(
                    "persistence failure",
                    "language_development",
                    "early_communication",
                    null,
                    10,
                    2));

            assertThat(result.rankedCandidates()).extracting(HybridCandidate::content)
                    .containsExactly("candidate survives");
            verify(palaceQueryTraceRepository, times(1)).save(any());
            assertThat(appender.list)
                    .filteredOn(event -> event.getLevel() == Level.WARN)
                    .singleElement()
                    .satisfies(event -> {
                        assertThat(event.getFormattedMessage()).contains("event=palace_trace_persistence_failed");
                        assertThat(event.getFormattedMessage()).contains("exceptionType=IllegalStateException");
                        assertThat(event.getFormattedMessage()).doesNotContain("sensitive trace content");
                    });
        } finally {
            logger.detachAppender(appender);
            appender.stop();
        }
    }

    private Document makeDocument(String id, String text, double score, String ageRange) {
        return new Document(id, text, Map.of(
                "score", score,
                "age_range", ageRange,
                "wing", "language_development",
                "room", "early_communication",
                "source_book", "《测试书》"
        ));
    }

    private ChunkResult makeKeywordChunk(String id, String content, double keywordScore, String ageRange) {
        return new ChunkResult(UUID.fromString(id), content, Map.of(
                "wing", "language_development",
                "room", "early_communication",
                "age_range", ageRange,
                "source_book", "《测试书》"
        ), keywordScore);
    }
}
