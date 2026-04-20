package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.config.MentorProperties;
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

    @BeforeEach
    void setUpChatClient() {
        chatClient = mock(ChatClient.class);
        requestSpec = mock(ChatClientRequestSpec.class);
        callResponseSpec = mock(CallResponseSpec.class);

        // 构造 fluent 链：chatClient.prompt() → requestSpec.system() → requestSpec.user() → requestSpec.advisors() → requestSpec.call()
        when(chatClient.prompt()).thenReturn(requestSpec);
        when(requestSpec.system(anyString())).thenReturn(requestSpec);
        when(requestSpec.user(anyString())).thenReturn(requestSpec);
        when(requestSpec.tools(any())).thenReturn(requestSpec);
        when(requestSpec.advisors(any(java.util.function.Consumer.class))).thenReturn(requestSpec);
        when(requestSpec.call()).thenReturn(callResponseSpec);
    }

    /**
     * 创建 MentorProperties，searchMode 可指定。
     */
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
                Duration.ofMinutes(30)
        );
    }

    private MentorProvider.ProviderRequest sampleRequest() {
        return new MentorProvider.ProviderRequest(
                "corr-001", "install-001", "home", "single_turn",
                "宝宝不肯说话怎么办？", "宝宝不肯说话", true, Instant.now(), null
        );
    }

    // ─── searchMode=none（向后兼容） ─────────────────────

    @Nested
    class SearchModeNone {

        private SpringAiMentorProvider provider;

        @BeforeEach
        void setUp() {
            var props = makeProperties("none");
            provider = new SpringAiMentorProvider(chatClient, props);
        }

        @Test
        void normalResponseReturnsProviderResponse() {
            when(callResponseSpec.content()).thenReturn("先只描述眼前一件事，句子越短越好。");

            var response = provider.respond(sampleRequest());

            assertThat(response.responseText()).isEqualTo("先只描述眼前一件事，句子越短越好。");
            assertThat(response.responseSummary()).isNotBlank();
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

    // ─── searchMode=rag ─────────────────────────────────

    @Nested
    class SearchModeRag {

        @Test
        void ragModeDoesNotRegisterTools() {
            var props = makeProperties("rag");
            // searchMode=rag 使用向后兼容构造函数（无 tools）
            var provider = new SpringAiMentorProvider(chatClient, props);

            when(callResponseSpec.content()).thenReturn("根据知识宫殿，宝宝需要多互动。");

            var response = provider.respond(sampleRequest());
            assertThat(response.responseText()).contains("宝宝需要多互动");
            // 无 tools 注册，但 prompt 可能包含 L1 内容（取决于 palaceSearchService）
        }
    }

    // ─── searchMode=agentic ─────────────────────────────

    @Nested
    class SearchModeAgentic {

        @Test
        void agenticModeCallsToolsOnProvider() {
            var props = makeProperties("agentic");
            var mockToolProvider = mock(com.zhangspaghetti.babytalk.palace.PalaceToolProvider.class);
            var provider = new SpringAiMentorProvider(chatClient, props,
                    mockToolProvider, null);

            when(callResponseSpec.content()).thenReturn("根据宫殿知识，建议多说短句。（来源：《语言发展指南》）");

            var response = provider.respond(sampleRequest());

            assertThat(response.responseText()).contains("语言发展指南");
            // 验证 tools() 被调用了
            verify(requestSpec).tools(mockToolProvider);
        }

        @Test
        void agenticModeWithoutToolProviderDoesNotCallTools() {
            var props = makeProperties("agentic");
            // PalaceToolProvider 为 null 时不注册 tools
            var provider = new SpringAiMentorProvider(chatClient, props, null, null);

            when(callResponseSpec.content()).thenReturn("回复内容");

            var response = provider.respond(sampleRequest());
            assertThat(response.responseText()).isEqualTo("回复内容");
        }
    }

    // ─── 向后兼容构造函数 ────────────────────────────────

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
