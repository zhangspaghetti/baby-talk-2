package com.zhangspaghetti.babytalk.palace;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import com.zhangspaghetti.babytalk.kg.KgEntityRepository;
import com.zhangspaghetti.babytalk.palace.PalaceKeywordMapper.ChunkRow;
import com.zhangspaghetti.babytalk.palace.PalaceKeywordRepository.ChunkResult;
import com.zhangspaghetti.babytalk.palace.projection.PalaceBridgeEdgeRepository;
import com.zhangspaghetti.babytalk.palace.projection.PalaceProjectionVersionRepository;
import com.zhangspaghetti.babytalk.palace.projection.PalaceQueryTraceRepository;
import com.zhangspaghetti.babytalk.palace.projection.PalaceRoomRepository;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;
import org.springframework.ai.document.Document;
import org.springframework.ai.vectorstore.SearchRequest;
import org.springframework.ai.vectorstore.VectorStore;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;

class PalaceRetrievalLoggingPrivacyTest {

    private static final String SENSITIVE_QUERY = "preset-brief-raw-给宝宝穿鞋-privacy-marker";
    private static final String SENSITIVE_KEYWORDS = "custom-prompt-raw-宝宝拒绝刷牙-keywords-marker";
    private static final String SENSITIVE_EXCEPTION_MESSAGE = "provider exception echoed raw custom prompt marker";

    @Test
    void vectorSearchSuccessLogsLengthAndCountWithoutRawQuery() {
        VectorStore vectorStore = mock(VectorStore.class);
        when(vectorStore.similaritySearch(any(SearchRequest.class))).thenReturn(List.of(document("vector-result")));
        PalaceSearchService service = new PalaceSearchService(vectorStore);

        ListAppender<ILoggingEvent> appender = attach(PalaceSearchService.class);
        try {
            assertThat(service.search(SENSITIVE_QUERY, "language_development", "early_communication", 5))
                    .hasSize(1);

            String logs = logText(appender);
            assertThat(logs)
                    .contains("queryLength=")
                    .contains("resultCount=1")
                    .doesNotContain(SENSITIVE_QUERY, "query='");
        } finally {
            detach(PalaceSearchService.class, appender);
        }
    }

    @Test
    void vectorSearchFailureLogsExceptionTypeWithoutRawQueryOrMessage() {
        VectorStore vectorStore = mock(VectorStore.class);
        when(vectorStore.similaritySearch(any(SearchRequest.class)))
                .thenThrow(new IllegalStateException(SENSITIVE_EXCEPTION_MESSAGE));
        PalaceSearchService service = new PalaceSearchService(vectorStore);

        ListAppender<ILoggingEvent> appender = attach(PalaceSearchService.class);
        try {
            try {
                service.search(SENSITIVE_QUERY, null, null, 5);
            } catch (IllegalStateException expected) {
                // The search contract still propagates provider failures.
            }

            String logs = logText(appender);
            assertThat(logs)
                    .contains("exceptionType=IllegalStateException")
                    .contains("queryLength=")
                    .doesNotContain(SENSITIVE_QUERY, SENSITIVE_EXCEPTION_MESSAGE, "query='");
        } finally {
            detach(PalaceSearchService.class, appender);
        }
    }

    @Test
    void keywordSearchSuccessAndMetadataFailureNeverLogRawKeywordsOrExceptionMessage() {
        PalaceKeywordMapper keywordMapper = mock(PalaceKeywordMapper.class);
        ObjectMapper objectMapper = mock(ObjectMapper.class);
        UUID id = UUID.randomUUID();
        when(keywordMapper.searchByKeywords(SENSITIVE_KEYWORDS, null, null, 5))
                .thenReturn(List.of(new ChunkRow(id, "safe result", "{}", 0.8d)));
        when(objectMapper.readValue(anyString(), (TypeReference<Map<String, Object>>) any()))
                .thenThrow(new IllegalStateException(SENSITIVE_EXCEPTION_MESSAGE));
        PalaceKeywordRepository repository = new PalaceKeywordRepository(keywordMapper, objectMapper);

        ListAppender<ILoggingEvent> appender = attach(PalaceKeywordRepository.class);
        try {
            List<ChunkResult> results = repository.searchByKeywords(SENSITIVE_KEYWORDS, null, null, 5);

            assertThat(results).hasSize(1);
            String logs = logText(appender);
            assertThat(logs)
                    .contains("keywordsLength=")
                    .contains("resultCount=1")
                    .contains("exceptionType=IllegalStateException")
                    .doesNotContain(SENSITIVE_KEYWORDS, SENSITIVE_EXCEPTION_MESSAGE, "keywords='");
        } finally {
            detach(PalaceKeywordRepository.class, appender);
        }
    }

    @Test
    void hybridSuccessLogsCountsWithoutRawQuery() {
        PalaceSearchService searchService = mock(PalaceSearchService.class);
        PalaceKeywordRepository keywordRepository = mock(PalaceKeywordRepository.class);
        PalaceHybridRetrievalService service = hybrid(searchService, keywordRepository);
        when(searchService.search(SENSITIVE_QUERY, "language_development", "early_communication", 10))
                .thenReturn(List.of(document("hybrid-result")));
        when(keywordRepository.searchByKeywords(
                SENSITIVE_QUERY, "language_development", "early_communication", 10))
                .thenReturn(List.of());

        ListAppender<ILoggingEvent> appender = attach(PalaceHybridRetrievalService.class);
        try {
            assertThat(service.retrieve(new RetrievalRequest(
                    SENSITIVE_QUERY, "language_development", "early_communication", null, 5, 2))
                    .rankedCandidates()).hasSize(1);

            String logs = logText(appender);
            assertThat(logs)
                    .contains("queryLength=")
                    .contains("vectorCount=1")
                    .contains("keywordCount=0")
                    .contains("resultCount=1")
                    .doesNotContain(SENSITIVE_QUERY, "query='");
        } finally {
            detach(PalaceHybridRetrievalService.class, appender);
        }
    }

    @Test
    void hybridFallbackAndErrorLogsUseExceptionTypeWithoutRawQueryOrMessage() {
        PalaceSearchService searchService = mock(PalaceSearchService.class);
        PalaceKeywordRepository keywordRepository = mock(PalaceKeywordRepository.class);
        PalaceHybridRetrievalService service = hybrid(searchService, keywordRepository);
        when(searchService.search(SENSITIVE_QUERY, null, null, 20))
                .thenThrow(new IllegalStateException(SENSITIVE_EXCEPTION_MESSAGE));
        when(searchService.search(SENSITIVE_QUERY, null, null, 10))
                .thenThrow(new IllegalStateException(SENSITIVE_EXCEPTION_MESSAGE));

        ListAppender<ILoggingEvent> appender = attach(PalaceHybridRetrievalService.class);
        try {
            var result = service.retrieve(new RetrievalRequest(SENSITIVE_QUERY));

            assertThat(result.rankedCandidates()).isEmpty();
            assertThat(result.trace().temporalRuleApplied())
                    .contains("IllegalStateException")
                    .doesNotContain(SENSITIVE_EXCEPTION_MESSAGE, SENSITIVE_QUERY);
            String logs = logText(appender);
            assertThat(logs)
                    .contains("exceptionType=IllegalStateException")
                    .contains("queryLength=")
                    .doesNotContain(SENSITIVE_QUERY, SENSITIVE_EXCEPTION_MESSAGE, "query='");
        } finally {
            detach(PalaceHybridRetrievalService.class, appender);
        }
    }

    private PalaceHybridRetrievalService hybrid(
            PalaceSearchService searchService,
            PalaceKeywordRepository keywordRepository
    ) {
        var kgEntityRepository = mock(KgEntityRepository.class);
        var roomRepository = mock(PalaceRoomRepository.class);
        when(roomRepository.count()).thenReturn(0L);
        when(kgEntityRepository.findByNameLike(anyString())).thenReturn(List.of());
        return new PalaceHybridRetrievalService(
                searchService,
                keywordRepository,
                kgEntityRepository,
                roomRepository,
                mock(PalaceBridgeEdgeRepository.class),
                mock(PalaceProjectionVersionRepository.class),
                mock(PalaceQueryTraceRepository.class),
                JsonMapper.builder().build());
    }

    private Document document(String content) {
        return new Document(
                UUID.randomUUID().toString(),
                content,
                Map.of("score", 0.9d, "age_range", "0-3"));
    }

    private ListAppender<ILoggingEvent> attach(Class<?> type) {
        Logger logger = (Logger) LoggerFactory.getLogger(type);
        ListAppender<ILoggingEvent> appender = new ListAppender<>();
        appender.start();
        logger.addAppender(appender);
        return appender;
    }

    private void detach(Class<?> type, ListAppender<ILoggingEvent> appender) {
        ((Logger) LoggerFactory.getLogger(type)).detachAppender(appender);
        appender.stop();
    }

    private String logText(ListAppender<ILoggingEvent> appender) {
        return appender.list.stream()
                .map(event -> event.getFormattedMessage()
                        + " "
                        + (event.getThrowableProxy() == null
                                ? ""
                                : event.getThrowableProxy().getMessage()))
                .reduce("", (left, right) -> left + "\n" + right);
    }
}
