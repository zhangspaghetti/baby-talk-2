package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.config.MentorProperties;
import com.zhangspaghetti.babytalk.config.MentorProviderConfiguration;
import com.zhangspaghetti.babytalk.palace.PalaceSearchService;
import com.zhangspaghetti.babytalk.palace.PalaceToolProvider;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.client.advisor.MessageChatMemoryAdvisor;
import org.springframework.beans.factory.ObjectProvider;

/**
 * MentorProviderConfiguration 纯单元测试。
 * 直接构造 Configuration 实例验证 bean 创建逻辑，不需要 Docker/Spring context。
 */
class MentorProviderConfigurationTest {

    @SuppressWarnings("unchecked")
    private final ObjectProvider<PalaceToolProvider> toolOp = mock(ObjectProvider.class);
    @SuppressWarnings("unchecked")
    private final ObjectProvider<PalaceSearchService> searchOp = mock(ObjectProvider.class);
    @SuppressWarnings("unchecked")
    private final ObjectProvider<MessageChatMemoryAdvisor> memoryAdvisorOp = mock(ObjectProvider.class);

    private final MentorProviderConfiguration configuration = new MentorProviderConfiguration();

    private MentorProperties makeProperties(String providerMode, String searchMode) {
        return new MentorProperties(
                providerMode,
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

    @Nested
    @DisplayName("dev 模式")
    class DevMode {

        @Test
        @DisplayName("dev 模式创建 DevMentorProvider")
        void devModeCreatesDevMentorProvider() {
            var props = makeProperties("dev", "none");
            when(toolOp.getIfAvailable()).thenReturn(null);
            when(searchOp.getIfAvailable()).thenReturn(null);

            var provider = configuration.mentorProvider(props, toolOp, searchOp, memoryAdvisorOp);
            assertThat(provider).isInstanceOf(DevMentorProvider.class);
        }
    }

    @Nested
    @DisplayName("github-models 模式")
    class GithubModelsMode {

        @Test
        @DisplayName("github-models 模式创建 SpringAiMentorProvider")
        void githubModelsModeCreatesSpringAiProvider() {
            var props = makeProperties("github-models", "none");
            when(toolOp.getIfAvailable()).thenReturn(null);
            when(searchOp.getIfAvailable()).thenReturn(null);

            var provider = configuration.mentorProvider(props, toolOp, searchOp, memoryAdvisorOp);
            assertThat(provider).isInstanceOf(SpringAiMentorProvider.class);
        }

        @Test
        @DisplayName("github-models + agentic 模式注入 PalaceToolProvider")
        void githubModelsAgenticInjectsToolProvider() {
            var mockTool = mock(PalaceToolProvider.class);
            var mockSearch = mock(PalaceSearchService.class);
            var props = makeProperties("github-models", "agentic");
            when(toolOp.getIfAvailable()).thenReturn(mockTool);
            when(searchOp.getIfAvailable()).thenReturn(mockSearch);

            var provider = configuration.mentorProvider(props, toolOp, searchOp, memoryAdvisorOp);
            assertThat(provider).isInstanceOf(SpringAiMentorProvider.class);
        }

        @Test
        @DisplayName("github-models 模式下 PalaceToolProvider 可选（dev 环境下不存在）")
        void toolProviderIsOptional() {
            var props = makeProperties("github-models", "agentic");
            when(toolOp.getIfAvailable()).thenReturn(null);
            when(searchOp.getIfAvailable()).thenReturn(null);

            // 不应抛异常
            var provider = configuration.mentorProvider(props, toolOp, searchOp, memoryAdvisorOp);
            assertThat(provider).isInstanceOf(SpringAiMentorProvider.class);
        }
    }

    @Nested
    @DisplayName("不支持的模式")
    class UnsupportedMode {

        @Test
        @DisplayName("unknown 模式抛出 ProviderUnavailableException")
        void unknownModeThrowsProviderUnavailableException() {
            var props = makeProperties("unknown-mode", "none");
            when(toolOp.getIfAvailable()).thenReturn(null);
            when(searchOp.getIfAvailable()).thenReturn(null);

            assertThatThrownBy(() -> configuration.mentorProvider(props, toolOp, searchOp, memoryAdvisorOp))
                    .isInstanceOf(MentorProvider.ProviderUnavailableException.class)
                    .hasMessageContaining("unknown-mode")
                    .hasMessageContaining("不支持");
        }
    }

    @Nested
    @DisplayName("searchMode 配置传递")
    class SearchModeConfig {

        @Test
        @DisplayName("searchMode 正确传递到 MentorProperties.effectiveSearchMode()")
        void searchModePassedToProperties() {
            var propsAgentic = makeProperties("dev", "agentic");
            assertThat(propsAgentic.effectiveSearchMode()).isEqualTo("agentic");

            var propsRag = makeProperties("dev", "rag");
            assertThat(propsRag.effectiveSearchMode()).isEqualTo("rag");

            var propsNone = makeProperties("dev", "none");
            assertThat(propsNone.effectiveSearchMode()).isEqualTo("none");
        }

        @Test
        @DisplayName("null searchMode 默认降级为 none")
        void nullSearchModeDefaultsToNone() {
            var props = makeProperties("dev", null);
            assertThat(props.effectiveSearchMode()).isEqualTo("none");
        }

        @Test
        @DisplayName("空字符串 searchMode 默认降级为 none")
        void emptySearchModeDefaultsToNone() {
            var props = makeProperties("dev", "");
            assertThat(props.effectiveSearchMode()).isEqualTo("none");
        }

        @Test
        @DisplayName("searchMode 大小写不敏感")
        void searchModeCaseInsensitive() {
            var props = makeProperties("dev", "AGENTIC");
            assertThat(props.effectiveSearchMode()).isEqualTo("agentic");

            var props2 = makeProperties("dev", " Rag ");
            assertThat(props2.effectiveSearchMode()).isEqualTo("rag");
        }
    }
}
