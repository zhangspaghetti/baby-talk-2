package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.config.MentorProperties;
import com.zhangspaghetti.babytalk.palace.HybridCandidate;
import com.zhangspaghetti.babytalk.palace.PalaceHybridRetrievalService;
import com.zhangspaghetti.babytalk.palace.PalaceToolProvider;
import com.zhangspaghetti.babytalk.palace.QueryTrace;
import com.zhangspaghetti.babytalk.palace.RetrievalRequest;
import com.zhangspaghetti.babytalk.palace.RetrievalResult;
import java.net.SocketTimeoutException;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.ChatClient.CallResponseSpec;
import org.springframework.ai.chat.client.ChatClient.ChatClientRequestSpec;

/**
 * SpringAiMentorProvider 纯单元测试 — 手动 mock ChatClient，无需 @SpringBootTest。
 * 覆盖 searchMode=none（向后兼容）、rag、agentic 三种模式。
 */
class SpringAiMentorProviderTest {

    private ChatClient chatClient;
    private ChatClientRequestSpec requestSpec;
    private CallResponseSpec callResponseSpec;
    private PalaceToolProvider palaceToolProvider;
    private PalaceHybridRetrievalService palaceHybridRetrievalService;

    @BeforeEach
    void setUpChatClient() {
        chatClient = mock(ChatClient.class);
        requestSpec = mock(ChatClientRequestSpec.class);
        callResponseSpec = mock(CallResponseSpec.class);
        palaceToolProvider = mock(PalaceToolProvider.class);
        palaceHybridRetrievalService = mock(PalaceHybridRetrievalService.class);

        when(chatClient.prompt()).thenReturn(requestSpec);
        when(requestSpec.system(anyString())).thenReturn(requestSpec);
        when(requestSpec.user(anyString())).thenReturn(requestSpec);
        when(requestSpec.tools(any())).thenReturn(requestSpec);
        when(requestSpec.advisors(any(java.util.function.Consumer.class))).thenReturn(requestSpec);
        when(requestSpec.call()).thenReturn(callResponseSpec);
    }

    private MentorProperties makeProperties(String searchMode) {
        return new MentorProperties(
                "github-models",
                Duration.ofSeconds(4),
                "https://models.inference.ai.azure.com",
                "ghp_test_secret_key_12345",
                "gpt-4o-mini",
                0.7,
                300,
                3,
                Duration.ofMinutes(10),
                280,
                280,
                List.of("home"),
                List.of("single_turn"),
                List.of("体罚"),
                "[timeout]",
                "[malformed]",
                "[unavailable]",
                searchMode,
                Duration.ofMinutes(30),
                null
        );
    }

    private MentorProvider.ProviderRequest sampleRequest() {
        return new MentorProvider.ProviderRequest(
                "corr-001", "install-001", "home", "single_turn",
                "宝宝不肯说话怎么办？", "宝宝不肯说话", true, Instant.now(), null
        );
    }

    private MentorProvider.ProviderRequest sampleRequest(Integer childAgeMonths) {
        return new MentorProvider.ProviderRequest(
                "corr-age-aware",
                "install-001",
                "home",
                "single_turn",
                "宝宝%d个月时我该怎么回应他的咿呀声？".formatted(childAgeMonths),
                "宝宝%d个月咿呀声回应".formatted(childAgeMonths),
                true,
                Instant.now(),
                null,
                childAgeMonths
        );
    }

    private RetrievalResult sampleRetrievalResult(String... contents) {
        var candidates = java.util.stream.IntStream.range(0, contents.length)
                .mapToObj(index -> new HybridCandidate(
                        "chunk-" + index,
                        contents[index],
                        0.9d - (index * 0.1d),
                        0.4d,
                        1.0d - (index * 0.1d),
                        "0-24个月",
                        1.0d,
                        "hybrid",
                        "《测试育儿书》"))
                .toList();
        return new RetrievalResult(
                candidates,
                new QueryTrace(
                        List.of("language_development/early_communication"),
                        List.of("language_development/early_communication"),
                        List.of("bridge-a"),
                        "soft-boost: child=6mo",
                        candidates,
                        "42"));
    }

    @Nested
    class SearchModeNone {

        private SpringAiMentorProvider provider;

        @BeforeEach
        void setUp() {
            var props = makeProperties("none");
            provider = new SpringAiMentorProvider(chatClient, props, palaceToolProvider, palaceHybridRetrievalService);
        }

        @Test
        void normalResponseReturnsProviderResponse() {
            when(callResponseSpec.content()).thenReturn("先只描述眼前一件事，句子越短越好。");

            var response = provider.respond(sampleRequest());

            assertThat(response.responseText()).isEqualTo("先只描述眼前一件事，句子越短越好。");
            assertThat(response.responseSummary()).isNotBlank();
        }

        @Test
        void requestWithChildAgeMonthsRemainsBackwardCompatible() {
            when(callResponseSpec.content()).thenReturn("先回应宝宝的声音，再重复一个短词。");

            var response = provider.respond(sampleRequest(6));

            assertThat(response.responseText()).contains("回应宝宝的声音");
            verify(palaceHybridRetrievalService, never()).retrieve(any());
        }

        @Test
        void timeoutExceptionMapsToProviderTimeout() {
            var cause = new SocketTimeoutException("Read timed out");
            var wrapper = new RuntimeException("API call failed", cause);
            when(callResponseSpec.content()).thenThrow(wrapper);

            assertThatThrownBy(() -> provider.respond(sampleRequest()))
                    .isInstanceOf(MentorProvider.ProviderTimeoutException.class)
                    .hasMessageContaining("github-models")
                    .hasMessageContaining("调用超时");
        }

        @Test
        void sdkErrorMapsToProviderUnavailable() {
            when(callResponseSpec.content()).thenThrow(new RuntimeException("500 Internal Server Error"));

            assertThatThrownBy(() -> provider.respond(sampleRequest()))
                    .isInstanceOf(MentorProvider.ProviderUnavailableException.class)
                    .hasMessageContaining("github-models")
                    .hasMessageContaining("不可用");
        }

        @Test
        void nullContentMapsToProviderMalformed() {
            when(callResponseSpec.content()).thenReturn(null);

            assertThatThrownBy(() -> provider.respond(sampleRequest()))
                    .isInstanceOf(MentorProvider.ProviderMalformedResponseException.class)
                    .hasMessageContaining("空响应");
        }

        @Test
        void blankContentMapsToProviderMalformed() {
            when(callResponseSpec.content()).thenReturn("   ");

            assertThatThrownBy(() -> provider.respond(sampleRequest()))
                    .isInstanceOf(MentorProvider.ProviderMalformedResponseException.class)
                    .hasMessageContaining("空响应");
        }

        @Test
        void systemPromptContainsXiaoHe() {
            when(callResponseSpec.content()).thenReturn("测试回复");

            provider.respond(sampleRequest());

            var captor = ArgumentCaptor.forClass(String.class);
            verify(requestSpec).system(captor.capture());
            assertThat(captor.getValue()).contains("小禾老师");
        }

        @Test
        void exceptionMessageDoesNotContainApiKey() {
            String apiKey = "ghp_test_secret_key_12345";
            when(callResponseSpec.content()).thenThrow(
                    new RuntimeException("Authentication failed with key " + apiKey));

            assertThatThrownBy(() -> provider.respond(sampleRequest()))
                    .isInstanceOf(MentorProvider.ProviderUnavailableException.class)
                    .satisfies(ex -> {
                        assertThat(ex.getMessage()).doesNotContain(apiKey);
                        assertThat(ex.getMessage()).contains("[REDACTED]");
                    });
        }

        @Test
        void connectTimeoutExceptionMapsToProviderTimeout() {
            var cause = new java.net.ConnectException("Connection timed out");
            var wrapper = new RuntimeException("Connection failed", cause);
            when(callResponseSpec.content()).thenThrow(wrapper);

            assertThatThrownBy(() -> provider.respond(sampleRequest()))
                    .isInstanceOf(MentorProvider.ProviderTimeoutException.class);
        }

        @Test
        void longResponseIsTrimmedToMaxLength() {
            String longText = "这是一段很长的回复。".repeat(50);
            when(callResponseSpec.content()).thenReturn(longText);

            var response = provider.respond(sampleRequest());
            assertThat(response.responseText().length()).isLessThanOrEqualTo(280);
        }
    }

    @Nested
    class SearchModeRag {

        @Test
        void ragModeInjectsHybridEvidenceIntoPrompt() {
            var props = makeProperties("rag");
            var provider = new SpringAiMentorProvider(chatClient, props, palaceToolProvider, palaceHybridRetrievalService);
            var retrievalResult = sampleRetrievalResult("证据一：多回应宝宝的声音。", "证据二：使用短句轮流对话。");
            assertThat(retrievalResult.trace()).isNotNull();
            when(palaceHybridRetrievalService.retrieve(any())).thenReturn(retrievalResult);
            when(callResponseSpec.content()).thenReturn("根据知识宫殿，宝宝需要多互动。");

            var response = provider.respond(sampleRequest(6));

            assertThat(response.responseText()).contains("宝宝需要多互动");
            verify(requestSpec, never()).tools(any());

            var requestCaptor = ArgumentCaptor.forClass(RetrievalRequest.class);
            verify(palaceHybridRetrievalService).retrieve(requestCaptor.capture());
            assertThat(requestCaptor.getValue().query()).isEqualTo("宝宝6个月时我该怎么回应他的咿呀声？");
            assertThat(requestCaptor.getValue().childAgeMonths()).isEqualTo(6);
            assertThat(requestCaptor.getValue().maxResults()).isEqualTo(10);
            assertThat(requestCaptor.getValue().maxHops()).isEqualTo(2);

            var systemPromptCaptor = ArgumentCaptor.forClass(String.class);
            verify(requestSpec).system(systemPromptCaptor.capture());
            assertThat(systemPromptCaptor.getValue()).contains("参考知识（来自知识宫殿）");
            assertThat(systemPromptCaptor.getValue()).contains("证据一：多回应宝宝的声音。");
            assertThat(systemPromptCaptor.getValue()).contains("证据二：使用短句轮流对话。");
            assertThat(systemPromptCaptor.getValue()).doesNotContain("工具使用指引");
        }

        @Test
        void ragModeFallsBackToL0WhenHybridRetrievalThrows() {
            var props = makeProperties("rag");
            var provider = new SpringAiMentorProvider(chatClient, props, palaceToolProvider, palaceHybridRetrievalService);
            when(palaceHybridRetrievalService.retrieve(any())).thenThrow(new RuntimeException("db timeout"));
            when(callResponseSpec.content()).thenReturn("建议多和宝宝互动说话。");

            var response = provider.respond(sampleRequest(6));

            assertThat(response.responseText()).contains("多和宝宝互动");
            verify(requestSpec, never()).tools(any());

            var captor = ArgumentCaptor.forClass(String.class);
            verify(requestSpec).system(captor.capture());
            assertThat(captor.getValue()).isEqualTo(SpringAiMentorProvider.SYSTEM_PROMPT);
        }
    }

    @Nested
    class SearchModeAgentic {

        @Test
        void agenticModeCallsToolsAndInjectsHybridEvidence() {
            var props = makeProperties("agentic");
            var provider = new SpringAiMentorProvider(chatClient, props, palaceToolProvider, palaceHybridRetrievalService);
            var retrievalResult = sampleRetrievalResult("证据三：夸张语调更容易吸引注意。", "证据四：停顿后等待宝宝回应。");
            assertThat(retrievalResult.trace()).isNotNull();
            when(palaceHybridRetrievalService.retrieve(any())).thenReturn(retrievalResult);
            when(callResponseSpec.content()).thenReturn("根据宫殿知识，建议多说短句。（来源：《语言发展指南》）");

            var response = provider.respond(sampleRequest(24));

            assertThat(response.responseText()).contains("语言发展指南");
            verify(requestSpec).tools(palaceToolProvider);

            var requestCaptor = ArgumentCaptor.forClass(RetrievalRequest.class);
            verify(palaceHybridRetrievalService).retrieve(requestCaptor.capture());
            assertThat(requestCaptor.getValue().childAgeMonths()).isEqualTo(24);

            var systemPromptCaptor = ArgumentCaptor.forClass(String.class);
            verify(requestSpec).system(systemPromptCaptor.capture());
            assertThat(systemPromptCaptor.getValue()).contains("参考知识（来自知识宫殿）");
            assertThat(systemPromptCaptor.getValue()).contains("证据三：夸张语调更容易吸引注意。");
            assertThat(systemPromptCaptor.getValue()).contains("工具使用指引");
        }

        @Test
        void agenticModeWithoutToolProviderDoesNotCallTools() {
            var props = makeProperties("agentic");
            var provider = new SpringAiMentorProvider(chatClient, props, null, palaceHybridRetrievalService);
            when(palaceHybridRetrievalService.retrieve(any())).thenReturn(sampleRetrievalResult("证据五：面对面交流。"));
            when(callResponseSpec.content()).thenReturn("回复内容");

            var response = provider.respond(sampleRequest());
            assertThat(response.responseText()).isEqualTo("回复内容");
            verify(requestSpec, never()).tools(any());
        }

        @Test
        void agenticModeStillRegistersToolsWhenHybridRetrievalFails() {
            var props = makeProperties("agentic");
            var provider = new SpringAiMentorProvider(chatClient, props, palaceToolProvider, palaceHybridRetrievalService);
            when(palaceHybridRetrievalService.retrieve(any())).thenThrow(new RuntimeException("Search engine unavailable"));
            when(callResponseSpec.content()).thenReturn("回复内容");

            provider.respond(sampleRequest());

            verify(requestSpec).tools(palaceToolProvider);
            var captor = ArgumentCaptor.forClass(String.class);
            verify(requestSpec).system(captor.capture());
            assertThat(captor.getValue()).contains("工具使用指引");
            assertThat(captor.getValue()).doesNotContain("参考知识");
        }
    }

    @Nested
    class BackwardCompatibility {

        @Test
        void twoArgConstructorWorksWithNullSearchMode() {
            var props = makeProperties(null);
            var provider = new SpringAiMentorProvider(chatClient, props);

            when(callResponseSpec.content()).thenReturn("回复");
            var response = provider.respond(sampleRequest());
            assertThat(response.responseText()).isEqualTo("回复");
        }

        @Test
        void systemPromptConstantMatchesL0() {
            assertThat(SpringAiMentorProvider.SYSTEM_PROMPT)
                    .isEqualTo(com.zhangspaghetti.babytalk.palace.MemPalacePromptBuilder.L0_SYSTEM_PROMPT);
        }
    }
}
