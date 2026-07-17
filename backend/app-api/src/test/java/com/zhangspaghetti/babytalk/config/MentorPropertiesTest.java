package com.zhangspaghetti.babytalk.config;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.autoconfigure.context.ConfigurationPropertiesAutoConfiguration;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

class MentorPropertiesTest {

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(ConfigurationPropertiesAutoConfiguration.class))
            .withUserConfiguration(TestConfiguration.class);

    @Test
    void bindsExplicitAttemptCount() {
        contextRunner
                .withPropertyValues(baseProperties())
                .withPropertyValues("app.mentor.ai-max-attempts=10")
                .run(context -> {
                    assertThat(context).hasNotFailed();
                    assertThat(context.getBean(MentorProperties.class).aiMaxAttempts()).isEqualTo(10);
                });
    }

    @Test
    void rejectsZeroAttempts() {
        contextRunner
                .withPropertyValues(baseProperties())
                .withPropertyValues("app.mentor.ai-max-attempts=0")
                .run(context -> assertThat(context).hasFailed());
    }

    private static String[] baseProperties() {
        return new String[] {
                "app.mentor.provider-mode=dev",
                "app.mentor.provider-timeout=PT4S",
                "app.mentor.rate-limit-max-requests=3",
                "app.mentor.rate-limit-window=PT10M",
                "app.mentor.prompt-max-length=280",
                "app.mentor.response-max-length=280",
                "app.mentor.allowed-surfaces[0]=home",
                "app.mentor.allowed-modes[0]=single_turn",
                "app.mentor.simulate-timeout-token=[timeout]",
                "app.mentor.simulate-malformed-token=[malformed]",
                "app.mentor.simulate-unavailable-token=[unavailable]"
        };
    }

    @org.springframework.boot.test.context.TestConfiguration(proxyBeanMethods = false)
    @EnableConfigurationProperties(MentorProperties.class)
    static class TestConfiguration {
    }
}
