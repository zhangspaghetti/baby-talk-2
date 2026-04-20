package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.MentorProperties;
import com.zhangspaghetti.babytalk.config.MentorProviderConfiguration;
import com.zhangspaghetti.babytalk.palace.PalaceSearchService;
import com.zhangspaghetti.babytalk.palace.PalaceToolProvider;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * 多 provider 配置集成测试 — 验证不同 provider-mode 下注入的 MentorProvider 类型。
 */
class MentorProviderConfigurationTest extends AbstractIntegrationTest {

    /**
     * dev mode 创建 DevMentorProvider 实例
     */
    @SpringBootTest(properties = {
            "app.contract.min-supported-version=1.2.0",
            "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
            "app.sms.provider-mode=dev",
            "app.sms.dev-code=246810",
            "app.mentor.provider-mode=dev",
    })
    @org.junit.jupiter.api.Nested
    class DevModeTest {
        @Autowired
        private MentorProvider mentorProvider;

        @Test
        void devModeCreatesDevMentorProvider() {
            assertThat(mentorProvider).isInstanceOf(DevMentorProvider.class);
        }
    }

    /**
     * github-models mode 创建 SpringAiMentorProvider 实例
     */
    @SpringBootTest(properties = {
            "app.contract.min-supported-version=1.2.0",
            "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
            "app.sms.provider-mode=dev",
            "app.sms.dev-code=246810",
            "app.mentor.provider-mode=github-models",
            "app.mentor.ai-api-key=test-key-for-integration",
    })
    @org.junit.jupiter.api.Nested
    class GithubModelsModeTest {
        @Autowired
        private MentorProvider mentorProvider;

        @Test
        void githubModelsModeCreatesSpringAiProvider() {
            assertThat(mentorProvider).isInstanceOf(SpringAiMentorProvider.class);
        }
    }

    /**
     * unknown mode 在 bean 创建时抛出 ProviderUnavailableException，
     * 导致 Spring context 启动失败。
     * 使用手动实例化 MentorProviderConfiguration 来测试此场景。
     */
    @Test
    void unknownModeThrowsProviderUnavailableException() {
        var properties = new MentorProperties(
                "unknown-mode",
                Duration.ofSeconds(4),
                null,
                null,
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
                "none"
        );

        var configuration = new MentorProviderConfiguration();
        @SuppressWarnings("unchecked")
        ObjectProvider<PalaceToolProvider> toolOp = mock(ObjectProvider.class);
        @SuppressWarnings("unchecked")
        ObjectProvider<PalaceSearchService> searchOp = mock(ObjectProvider.class);
        when(toolOp.getIfAvailable()).thenReturn(null);
        when(searchOp.getIfAvailable()).thenReturn(null);
        assertThatThrownBy(() -> configuration.mentorProvider(properties, toolOp, searchOp))
                .isInstanceOf(MentorProvider.ProviderUnavailableException.class)
                .hasMessageContaining("unknown-mode")
                .hasMessageContaining("不支持");
    }
}
