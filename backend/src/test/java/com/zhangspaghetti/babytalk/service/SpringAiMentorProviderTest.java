package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
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
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.ChatClient.CallResponseSpec;
import org.springframework.ai.chat.client.ChatClient.ChatClientRequestSpec;

/**
 * SpringAiMentorProvider 纯单元测试 — 手动 mock ChatClient，无需 @SpringBootTest。
 */
class SpringAiMentorProviderTest {

    private ChatClient chatClient;
    private ChatClientRequestSpec requestSpec;
    private CallResponseSpec callResponseSpec;
    private MentorProperties properties;
    private SpringAiMentorProvider provider;

    @BeforeEach
    void setUp() {
        chatClient = mock(ChatClient.class);
        requestSpec = mock(ChatClientRequestSpec.class);
        callResponseSpec = mock(CallResponseSpec.class);

        // 构造 fluent 链：chatClient.prompt() → requestSpec.system() → requestSpec.user() → requestSpec.call() → callResponseSpec
        when(chatClient.prompt()).thenReturn(requestSpec);
        when(requestSpec.system(anyString())).thenReturn(requestSpec);
        when(requestSpec.user(anyString())).thenReturn(requestSpec);
        when(requestSpec.call()).thenReturn(callResponseSpec);

        properties = new MentorProperties(
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
                "[unavailable]"
        );

        provider = new SpringAiMentorProvider(chatClient, properties);
    }

    private MentorProvider.ProviderRequest sampleRequest() {
        return new MentorProvider.ProviderRequest(
                "corr-001", "install-001", "home", "single_turn",
                "宝宝不肯说话怎么办？", "宝宝不肯说话", true, Instant.now()
        );
    }

    @Test
    void normalResponseReturnsProviderResponse() {
        // mock chatClient 返回有效文本
        when(callResponseSpec.content()).thenReturn("先只描述眼前一件事，句子越短越好。");

        var response = provider.respond(sampleRequest());

        assertThat(response.responseText()).isEqualTo("先只描述眼前一件事，句子越短越好。");
        assertThat(response.responseSummary()).isNotBlank();
    }

    @Test
    void timeoutExceptionMapsToProviderTimeout() {
        // mock chatClient 抛出包含 SocketTimeoutException cause 的异常
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
        // mock chatClient 抛出 RuntimeException（模拟 SDK 5xx）
        when(callResponseSpec.content()).thenThrow(new RuntimeException("500 Internal Server Error"));

        assertThatThrownBy(() -> provider.respond(sampleRequest()))
                .isInstanceOf(MentorProvider.ProviderUnavailableException.class)
                .hasMessageContaining("github-models")
                .hasMessageContaining("不可用");
    }

    @Test
    void nullContentMapsToProviderMalformed() {
        // mock chatClient 返回 null content
        when(callResponseSpec.content()).thenReturn(null);

        assertThatThrownBy(() -> provider.respond(sampleRequest()))
                .isInstanceOf(MentorProvider.ProviderMalformedResponseException.class)
                .hasMessageContaining("空响应");
    }

    @Test
    void blankContentMapsToProviderMalformed() {
        // mock chatClient 返回空字符串 content
        when(callResponseSpec.content()).thenReturn("   ");

        assertThatThrownBy(() -> provider.respond(sampleRequest()))
                .isInstanceOf(MentorProvider.ProviderMalformedResponseException.class)
                .hasMessageContaining("空响应");
    }

    @Test
    void systemPromptIsPassedToClient() {
        when(callResponseSpec.content()).thenReturn("测试回复");

        provider.respond(sampleRequest());

        // 验证 system prompt 被传入并包含 '小禾老师'
        var captor = ArgumentCaptor.forClass(String.class);
        verify(requestSpec).system(captor.capture());
        assertThat(captor.getValue()).contains("小禾老师");
    }

    @Test
    void exceptionMessageDoesNotContainApiKey() {
        // 模拟异常消息中带有 api-key 值
        String apiKey = properties.aiApiKey();
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
        // ConnectException 也应映射为超时异常
        var cause = new java.net.ConnectException("Connection timed out");
        var wrapper = new RuntimeException("Connection failed", cause);
        when(callResponseSpec.content()).thenThrow(wrapper);

        assertThatThrownBy(() -> provider.respond(sampleRequest()))
                .isInstanceOf(MentorProvider.ProviderTimeoutException.class);
    }

    @Test
    void longResponseIsTrimmedToMaxLength() {
        // 验证超长响应被截断到 responseMaxLength
        String longText = "这是一段很长的回复。".repeat(50); // 远超 280 字
        when(callResponseSpec.content()).thenReturn(longText);

        var response = provider.respond(sampleRequest());

        assertThat(response.responseText().length()).isLessThanOrEqualTo(properties.responseMaxLength());
    }
}
