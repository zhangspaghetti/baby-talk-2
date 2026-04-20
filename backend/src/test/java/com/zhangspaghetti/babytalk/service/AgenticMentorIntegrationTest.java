package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.config.MentorProperties;
import com.zhangspaghetti.babytalk.palace.MemPalacePromptBuilder;
import com.zhangspaghetti.babytalk.palace.PalaceSearchService;
import com.zhangspaghetti.babytalk.palace.PalaceToolProvider;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.ChatClient.CallResponseSpec;
import org.springframework.ai.chat.client.ChatClient.ChatClientRequestSpec;
import org.springframework.ai.document.Document;

/**
 * Agentic 模式集成测试 — 验证 SpringAiMentorProvider 在三种 searchMode 下的完整行为链路。
 *
 * <p>策略：手动 mock ChatClient fluent API chain，不需要 @SpringBootTest。
 * 验证 tool 注册、system prompt 内容、以及 L1 预检索降级等端到端行为。
 */
class AgenticMentorIntegrationTest {

    private ChatClient chatClient;
    private ChatClientRequestSpec requestSpec;
    private CallResponseSpec callResponseSpec;
    private PalaceToolProvider toolProvider;
    private PalaceSearchService searchService;

    @BeforeEach
    void setUp() {
        chatClient = mock(ChatClient.class);
        requestSpec = mock(ChatClientRequestSpec.class);
        callResponseSpec = mock(CallResponseSpec.class);
        toolProvider = mock(PalaceToolProvider.class);
        searchService = mock(PalaceSearchService.class);

        // 构造 fluent chain: chatClient.prompt() → requestSpec.system/user/tools/advisors → callResponseSpec
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
                Duration.ofMinutes(30)
        );
    }

    private MentorProvider.ProviderRequest sampleRequest() {
        return new MentorProvider.ProviderRequest(
                "corr-agentic-001", "install-001", "home", "single_turn",
                "宝宝18个月还不会说话正常吗？", "宝宝18个月不说话", true, Instant.now(), null
        );
    }

    private Document createDoc(String text, String sourceBook, String ageRange) {
        return new Document(text, Map.of(
                "source_book", sourceBook,
                "age_range", ageRange,
                "wing", "language_development",
                "room", "early_communication"
        ));
    }

    // ─── Agentic 模式完整链路 ───────────────────────────

    @Nested
    @DisplayName("searchMode=agentic")
    class AgenticMode {

        @Test
        @DisplayName("agentic 模式注册 PalaceToolProvider 并调用 tools()")
        void agenticModeRegistersToolProvider() {
            var props = makeProperties("agentic");
            var provider = new SpringAiMentorProvider(chatClient, props, toolProvider, searchService);

            when(searchService.search(any(), isNull(), isNull(), anyInt()))
                    .thenReturn(List.of(createDoc("语言发展知识", "《婴幼儿语言》", "12-24个月")));
            when(callResponseSpec.content()).thenReturn("18个月不说话通常是正常的。（来源：《婴幼儿语言》）");

            var response = provider.respond(sampleRequest());

            // 验证 tools() 被调用注册了 toolProvider
            verify(requestSpec).tools(toolProvider);
            assertThat(response.responseText()).contains("婴幼儿语言");
        }

        @Test
        @DisplayName("agentic 模式 system prompt 包含 L0 + L1 + L2 工具指引")
        void agenticSystemPromptContainsAllLayers() {
            var props = makeProperties("agentic");
            var provider = new SpringAiMentorProvider(chatClient, props, toolProvider, searchService);

            var docs = List.of(createDoc("宝宝语言发展里程碑", "《发展心理学》", "0-36个月"));
            when(searchService.search(any(), isNull(), isNull(), anyInt())).thenReturn(docs);
            when(callResponseSpec.content()).thenReturn("建议多互动。（来源：《发展心理学》）");

            provider.respond(sampleRequest());

            var captor = ArgumentCaptor.forClass(String.class);
            verify(requestSpec).system(captor.capture());
            String systemPrompt = captor.getValue();

            // L0 核心人格
            assertThat(systemPrompt).contains("小禾老师");
            // L1 预检索知识
            assertThat(systemPrompt).contains("参考知识（来自知识宫殿）");
            assertThat(systemPrompt).contains("《发展心理学》");
            // L2 工具指引
            assertThat(systemPrompt).contains("工具使用指引");
            assertThat(systemPrompt).contains("palace_vector_search");
        }

        @Test
        @DisplayName("agentic 模式下 PalaceToolProvider 为 null 时不调用 tools()")
        void agenticWithoutToolProviderSkipsToolRegistration() {
            var props = makeProperties("agentic");
            var provider = new SpringAiMentorProvider(chatClient, props, null, searchService);

            when(searchService.search(any(), isNull(), isNull(), anyInt())).thenReturn(List.of());
            when(callResponseSpec.content()).thenReturn("回复内容");

            var response = provider.respond(sampleRequest());

            // tools() 不应被调用
            verify(requestSpec, never()).tools(any());
            assertThat(response.responseText()).isEqualTo("回复内容");
        }

        @Test
        @DisplayName("agentic 模式大小写不敏感：Agentic → agentic")
        void agenticModeCaseInsensitive() {
            var props = makeProperties("Agentic");
            var provider = new SpringAiMentorProvider(chatClient, props, toolProvider, searchService);

            when(searchService.search(any(), isNull(), isNull(), anyInt())).thenReturn(List.of());
            when(callResponseSpec.content()).thenReturn("回复");

            provider.respond(sampleRequest());
            verify(requestSpec).tools(toolProvider);
        }
    }

    // ─── RAG 模式 ───────────────────────────────────────

    @Nested
    @DisplayName("searchMode=rag")
    class RagMode {

        @Test
        @DisplayName("rag 模式不注册 tools()，system prompt 包含 L0+L1 无 L2")
        void ragModeDoesNotRegisterTools() {
            var props = makeProperties("rag");
            var provider = new SpringAiMentorProvider(chatClient, props, toolProvider, searchService);

            var docs = List.of(createDoc("早期互动对语言的影响", "《亲子沟通》", "0-24个月"));
            when(searchService.search(any(), isNull(), isNull(), anyInt())).thenReturn(docs);
            when(callResponseSpec.content()).thenReturn("多和宝宝说话。（来源：《亲子沟通》）");

            provider.respond(sampleRequest());

            // rag 模式不调用 tools()
            verify(requestSpec, never()).tools(any());

            // 验证 system prompt 包含 L0+L1，不含 L2
            var captor = ArgumentCaptor.forClass(String.class);
            verify(requestSpec).system(captor.capture());
            String systemPrompt = captor.getValue();

            assertThat(systemPrompt).contains("小禾老师");
            assertThat(systemPrompt).contains("参考知识（来自知识宫殿）");
            assertThat(systemPrompt).contains("《亲子沟通》");
            assertThat(systemPrompt).doesNotContain("工具使用指引");
        }
    }

    // ─── None 模式 ──────────────────────────────────────

    @Nested
    @DisplayName("searchMode=none")
    class NoneMode {

        @Test
        @DisplayName("none 模式行为与原有 SpringAiMentorProvider 完全一致")
        void noneModeIsBackwardCompatible() {
            var props = makeProperties("none");
            var provider = new SpringAiMentorProvider(chatClient, props, toolProvider, searchService);

            when(callResponseSpec.content()).thenReturn("先只描述眼前一件事，句子越短越好。");

            var response = provider.respond(sampleRequest());

            // 不注册 tools
            verify(requestSpec, never()).tools(any());
            // 不调用 searchService
            verify(searchService, never()).search(any(), any(), any(), anyInt());

            // system prompt 仅 L0
            var captor = ArgumentCaptor.forClass(String.class);
            verify(requestSpec).system(captor.capture());
            assertThat(captor.getValue()).isEqualTo(MemPalacePromptBuilder.L0_SYSTEM_PROMPT);

            assertThat(response.responseText()).contains("眼前一件事");
        }

        @Test
        @DisplayName("null searchMode 默认为 none")
        void nullSearchModeDefaultsToNone() {
            var props = makeProperties(null);
            var provider = new SpringAiMentorProvider(chatClient, props, toolProvider, searchService);

            when(callResponseSpec.content()).thenReturn("回复");
            provider.respond(sampleRequest());

            verify(requestSpec, never()).tools(any());
            verify(searchService, never()).search(any(), any(), any(), anyInt());
        }

        @Test
        @DisplayName("空字符串 searchMode 默认为 none")
        void emptySearchModeDefaultsToNone() {
            var props = makeProperties("");
            var provider = new SpringAiMentorProvider(chatClient, props, toolProvider, searchService);

            when(callResponseSpec.content()).thenReturn("回复");
            provider.respond(sampleRequest());

            verify(requestSpec, never()).tools(any());
        }
    }

    // ─── L1 预检索失败降级 ──────────────────────────────

    @Nested
    @DisplayName("L1 预检索降级")
    class L1Fallback {

        @Test
        @DisplayName("L1 预检索抛 RuntimeException → 降级到 L0 only，不影响 LLM 回复")
        void l1FailureFallsBackToL0() {
            var props = makeProperties("rag");
            var provider = new SpringAiMentorProvider(chatClient, props, toolProvider, searchService);

            when(searchService.search(any(), isNull(), isNull(), anyInt()))
                    .thenThrow(new RuntimeException("Database connection timeout"));
            when(callResponseSpec.content()).thenReturn("建议多和宝宝互动说话。");

            // 不应抛异常，而是降级到 L0
            var response = provider.respond(sampleRequest());
            assertThat(response.responseText()).contains("多和宝宝互动");

            // system prompt 应仅包含 L0（因为 L1 失败了）
            var captor = ArgumentCaptor.forClass(String.class);
            verify(requestSpec).system(captor.capture());
            assertThat(captor.getValue()).isEqualTo(MemPalacePromptBuilder.L0_SYSTEM_PROMPT);
        }

        @Test
        @DisplayName("agentic 模式下 L1 失败仍注册 tools 并包含 L2 指引")
        void agenticL1FailureStillRegistersTool() {
            var props = makeProperties("agentic");
            var provider = new SpringAiMentorProvider(chatClient, props, toolProvider, searchService);

            when(searchService.search(any(), isNull(), isNull(), anyInt()))
                    .thenThrow(new RuntimeException("Search engine unavailable"));
            when(callResponseSpec.content()).thenReturn("回复内容");

            provider.respond(sampleRequest());

            // agentic 模式仍注册 tools
            verify(requestSpec).tools(toolProvider);

            // L1 失败但 L2 工具指引仍在
            var captor = ArgumentCaptor.forClass(String.class);
            verify(requestSpec).system(captor.capture());
            assertThat(captor.getValue()).contains("工具使用指引");
            // L1 知识段不应存在
            assertThat(captor.getValue()).doesNotContain("参考知识");
        }
    }
}
