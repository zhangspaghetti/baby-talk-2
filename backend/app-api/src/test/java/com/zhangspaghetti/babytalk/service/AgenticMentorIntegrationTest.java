package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.config.MentorProperties;
import com.zhangspaghetti.babytalk.palace.HybridCandidate;
import com.zhangspaghetti.babytalk.palace.MemPalacePromptBuilder;
import com.zhangspaghetti.babytalk.palace.PalaceHybridRetrievalService;
import com.zhangspaghetti.babytalk.palace.PalaceToolProvider;
import com.zhangspaghetti.babytalk.palace.QueryTrace;
import com.zhangspaghetti.babytalk.palace.RetrievalResult;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.ChatClient.CallResponseSpec;
import org.springframework.ai.chat.client.ChatClient.ChatClientRequestSpec;

/**
 * Agentic/RAG 行为集成测试：验证 SpringAiMentorProvider 与 hybrid pre-retrieval 的链路拼接。
 */
class AgenticMentorIntegrationTest {

    private ChatClient chatClient;
    private ChatClientRequestSpec requestSpec;
    private CallResponseSpec callResponseSpec;
    private PalaceToolProvider toolProvider;
    private PalaceHybridRetrievalService hybridRetrievalService;

    @BeforeEach
    void setUp() {
        chatClient = mock(ChatClient.class);
        requestSpec = mock(ChatClientRequestSpec.class);
        callResponseSpec = mock(CallResponseSpec.class);
        toolProvider = mock(PalaceToolProvider.class);
        hybridRetrievalService = mock(PalaceHybridRetrievalService.class);

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
                "ghp_test_key_123",
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
                "corr-agentic-001",
                "install-001",
                "home",
                "single_turn",
                "宝宝18个月还不会说话正常吗？",
                "宝宝18个月不说话",
                true,
                Instant.now(),
                null,
                18
        );
    }

    private RetrievalResult sampleRetrievalResult(String... contents) {
        var candidates = java.util.stream.IntStream.range(0, contents.length)
                .mapToObj(index -> new HybridCandidate(
                        "chunk-" + index,
                        contents[index],
                        0.9d - (index * 0.1d),
                        0.3d,
                        1.0d - (index * 0.1d),
                        "0-24个月",
                        1.0d,
                        "hybrid"))
                .toList();
        return new RetrievalResult(
                candidates,
                new QueryTrace(
                        List.of("language_development/early_communication"),
                        List.of("language_development/early_communication"),
                        List.of("bridge-a"),
                        "soft-boost: child=18mo",
                        candidates,
                        "42"));
    }

    @Nested
    @DisplayName("searchMode=agentic")
    class AgenticMode {

        @Test
        @DisplayName("agentic 模式注册 PalaceToolProvider 并把 hybrid 证据写入 system prompt")
        void agenticModeRegistersToolProvider() {
            var props = makeProperties("agentic");
            var provider = new SpringAiMentorProvider(chatClient, props, toolProvider, hybridRetrievalService);

            when(hybridRetrievalService.retrieve(any()))
                    .thenReturn(sampleRetrievalResult("证据：18个月宝宝要多轮流回应。"));
            when(callResponseSpec.content()).thenReturn("18个月不说话通常需要先增加互动。（来源：《婴幼儿语言》）");

            var response = provider.respond(sampleRequest());

            verify(requestSpec).tools(toolProvider);
            assertThat(response.responseText()).contains("婴幼儿语言");

            var captor = ArgumentCaptor.forClass(String.class);
            verify(requestSpec).system(captor.capture());
            assertThat(captor.getValue()).contains("参考知识（来自知识宫殿）");
            assertThat(captor.getValue()).contains("证据：18个月宝宝要多轮流回应。");
            assertThat(captor.getValue()).contains("工具使用指引");
        }

        @Test
        @DisplayName("agentic 模式下 hybrid 失败仍注册 tools 且保留 L2")
        void agenticL1FailureStillRegistersTool() {
            var props = makeProperties("agentic");
            var provider = new SpringAiMentorProvider(chatClient, props, toolProvider, hybridRetrievalService);

            when(hybridRetrievalService.retrieve(any()))
                    .thenThrow(new RuntimeException("Search engine unavailable"));
            when(callResponseSpec.content()).thenReturn("回复内容");

            provider.respond(sampleRequest());

            verify(requestSpec).tools(toolProvider);
            var captor = ArgumentCaptor.forClass(String.class);
            verify(requestSpec).system(captor.capture());
            assertThat(captor.getValue()).contains("工具使用指引");
            assertThat(captor.getValue()).doesNotContain("参考知识");
        }
    }

    @Nested
    @DisplayName("searchMode=rag")
    class RagMode {

        @Test
        @DisplayName("rag 模式不注册 tools()，但会把 hybrid 证据注入 prompt")
        void ragModeDoesNotRegisterTools() {
            var props = makeProperties("rag");
            var provider = new SpringAiMentorProvider(chatClient, props, toolProvider, hybridRetrievalService);

            when(hybridRetrievalService.retrieve(any()))
                    .thenReturn(sampleRetrievalResult("证据：面对面说短句更容易跟读。"));
            when(callResponseSpec.content()).thenReturn("多和宝宝说话。（来源：《亲子沟通》）");

            provider.respond(sampleRequest());

            verify(requestSpec, never()).tools(any());
            var captor = ArgumentCaptor.forClass(String.class);
            verify(requestSpec).system(captor.capture());
            assertThat(captor.getValue()).contains("参考知识（来自知识宫殿）");
            assertThat(captor.getValue()).contains("证据：面对面说短句更容易跟读。");
            assertThat(captor.getValue()).doesNotContain("工具使用指引");
        }
    }

    @Nested
    @DisplayName("searchMode=none")
    class NoneMode {

        @Test
        @DisplayName("none 模式行为与原有 SpringAiMentorProvider 一致")
        void noneModeIsBackwardCompatible() {
            var props = makeProperties("none");
            var provider = new SpringAiMentorProvider(chatClient, props, toolProvider, hybridRetrievalService);

            when(callResponseSpec.content()).thenReturn("先只描述眼前一件事，句子越短越好。");

            var response = provider.respond(sampleRequest());

            verify(requestSpec, never()).tools(any());
            verify(hybridRetrievalService, never()).retrieve(any());

            var captor = ArgumentCaptor.forClass(String.class);
            verify(requestSpec).system(captor.capture());
            assertThat(captor.getValue()).isEqualTo(MemPalacePromptBuilder.L0_SYSTEM_PROMPT);
            assertThat(response.responseText()).contains("眼前一件事");
        }
    }
}
