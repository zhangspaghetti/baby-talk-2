package com.zhangspaghetti.babytalk.practice.generated.audio;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.autoconfigure.context.ConfigurationPropertiesAutoConfiguration;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;

class GeneratedSpeechSynthesisConfigurationTest {

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(ConfigurationPropertiesAutoConfiguration.class))
            .withUserConfiguration(TestConfiguration.class)
            .withPropertyValues(commonProperties());

    @Test
    void disabledModeStartsWithTheNoNetworkProvider() {
        contextRunner.run(context -> assertThat(context.getBean(GeneratedSpeechSynthesisPort.class))
                .isInstanceOf(DisabledGeneratedSpeechSynthesisProvider.class));
    }

    @Test
    void fakeModeIsRestrictedToTheDevProfile() {
        contextRunner.withPropertyValues(
                        "babytalk.practice.generated-audio.enabled=true",
                        "babytalk.practice.generated-audio.provider-mode=fake"
                )
                .run(context -> assertThat(context.getStartupFailure())
                        .hasMessageContaining("restricted to the dev profile"));
    }

    @Test
    void fakeModeStartsOnlyWhenTheDevProfileIsActive() {
        contextRunner.withInitializer(context -> context.getEnvironment().setActiveProfiles("dev"))
                .withPropertyValues(
                        "babytalk.practice.generated-audio.enabled=true",
                        "babytalk.practice.generated-audio.provider-mode=fake"
                )
                .run(context -> assertThat(context.getBean(GeneratedSpeechSynthesisPort.class))
                        .isInstanceOf(FakeGeneratedSpeechSynthesisProvider.class));
    }

    @Test
    void configuredModeFailsStartupWithoutItsDedicatedSecret() {
        contextRunner.withPropertyValues(
                        "babytalk.practice.generated-audio.enabled=true",
                        "babytalk.practice.generated-audio.provider-mode=openai",
                        "babytalk.practice.generated-audio.base-url=https://provider.example.com/v1",
                        "babytalk.practice.generated-audio.api-key-environment-variable=TEST_GENERATED_AUDIO_KEY",
                        "babytalk.practice.generated-audio.model=gpt-4o-mini-tts",
                        "babytalk.practice.generated-audio.voice=alloy"
                )
                .run(context -> assertThat(context.getStartupFailure())
                        .hasMessageContaining("TEST_GENERATED_AUDIO_KEY"));
    }

    private String[] commonProperties() {
        return new String[] {
                "babytalk.practice.generated-audio.enabled=false",
                "babytalk.practice.generated-audio.provider-mode=disabled",
                "babytalk.practice.generated-audio.timeout=5s",
                "babytalk.practice.generated-audio.max-bytes=524288",
                "babytalk.practice.generated-audio.voice-version=generated-tts-v1",
                "babytalk.practice.generated-audio.format=mp3"
        };
    }

    @Configuration(proxyBeanMethods = false)
    @EnableConfigurationProperties(GeneratedSpeechProperties.class)
    @Import(GeneratedSpeechSynthesisConfiguration.class)
    static class TestConfiguration {
    }
}
