package com.zhangspaghetti.babytalk.practice.discovery;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiOperationRunner;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiCapability;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiChatClientFactory;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiOpenAiOptionsFactory;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiProviderConfiguration;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiProviderManager;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller;
import com.zhangspaghetti.babytalk.practice.generated.AgenticCustomSceneGenerator;
import com.zhangspaghetti.babytalk.practice.generated.AgenticCustomSceneQualityJudge;
import com.zhangspaghetti.babytalk.practice.generated.AgenticCustomSceneRepairer;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneQualityJudge;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneRepairer;
import com.zhangspaghetti.babytalk.practice.generated.DisabledCustomSceneQualityJudge;
import com.zhangspaghetti.babytalk.practice.generated.DisabledCustomSceneRepairer;
import com.zhangspaghetti.babytalk.practice.generated.FakeCustomSceneRepairer;
import com.zhangspaghetti.babytalk.practice.generated.FakeCustomSceneQualityJudge;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeResultAuditPort;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdictCalculator;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;

class CustomSceneGenerationProviderWiringTest {

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withUserConfiguration(ProviderConfiguration.class)
            .withPropertyValues(
                    "babytalk.practice.discovery.custom-scene.enabled=true",
                    "babytalk.practice.discovery.custom-scene.timeout=5s"
            );

    @Test
    void fakeProviderModeWiresFakeBeanAndReturnsSuccessfulCandidate() {
        contextRunner
                .withPropertyValues(
                        "spring.profiles.active=test",
                        "babytalk.practice.discovery.custom-scene.provider-mode=fake")
                .run(context -> {
                    assertThat(context).hasSingleBean(CustomSceneGenerator.class);
                    assertThat(context.getBean(CustomSceneGenerator.class))
                            .isInstanceOf(FakeCustomSceneGenerationService.class);
                    assertThat(context).hasSingleBean(CustomSceneQualityJudge.class);
                    assertThat(context.getBean(CustomSceneQualityJudge.class))
                            .isInstanceOf(FakeCustomSceneQualityJudge.class);
                    assertThat(context).hasSingleBean(CustomSceneRepairer.class);
                    assertThat(context.getBean(CustomSceneRepairer.class))
                            .isInstanceOf(FakeCustomSceneRepairer.class);

                    var candidate = context.getBean(CustomSceneGenerator.class)
                            .generate(request("睡前哄宝宝"));

                    assertThat(candidate.englishText()).isEqualTo("Sleepy baby.");
                    assertThat(candidate.generationSource()).isEqualTo("fake");
                });
    }

    @Test
    void fakeProviderReturnsShoesAlignedCandidateForShoesScene() {
        contextRunner
                .withPropertyValues(
                        "spring.profiles.active=test",
                        "babytalk.practice.discovery.custom-scene.provider-mode=fake")
                .run(context -> {
                    var candidate = context.getBean(CustomSceneGenerator.class)
                            .generate(request("出门前宝宝不想穿鞋"));

                    assertThat(candidate.activityTitleZh()).contains("穿鞋");
                    assertThat(candidate.sceneTagEn()).containsIgnoringCase("shoe");
                    assertThat(candidate.englishText()).containsIgnoringCase("shoe");
                });
    }

    @Test
    void fakeProviderRejectsUnrecognizedSceneInsteadOfReturningBathFallback() {
        contextRunner
                .withPropertyValues(
                        "spring.profiles.active=test",
                        "babytalk.practice.discovery.custom-scene.provider-mode=fake")
                .run(context -> {
                    assertThat(org.assertj.core.api.Assertions.catchThrowable(() -> context
                            .getBean(CustomSceneGenerator.class)
                            .generate(request("给宝宝涂防晒"))))
                            .isInstanceOf(CustomSceneGenerator.GenerationUnavailableException.class)
                            .satisfies(error -> {
                                var unavailable = (CustomSceneGenerator.GenerationUnavailableException) error;
                                assertThat(unavailable.reason()).isEqualTo("fake_scene_not_supported");
                                assertThat(unavailable.retryable()).isFalse();
                            });
                });
    }

    @Test
    void fakeProviderIsNotAvailableOutsideDevOrTestProfiles() {
        contextRunner
                .withPropertyValues("babytalk.practice.discovery.custom-scene.provider-mode=fake")
                .run(context -> {
                    assertThat(context).doesNotHaveBean(CustomSceneGenerator.class);
                    assertThat(context).doesNotHaveBean(PracticeAiChatClientFactory.class);
                    assertThat(context).doesNotHaveBean(PracticeAiProviderManager.class);
                    assertThat(context).doesNotHaveBean(CustomSceneQualityJudge.class);
                    assertThat(context).doesNotHaveBean(CustomSceneRepairer.class);
                });
    }

    @Test
    void disabledProviderModeWiresDisabledBean() {
        contextRunner
                .withPropertyValues("babytalk.practice.discovery.custom-scene.provider-mode=disabled")
                .run(context -> {
                    assertThat(context).hasSingleBean(CustomSceneGenerator.class);
                    assertThat(context.getBean(CustomSceneGenerator.class))
                            .isInstanceOf(DisabledCustomSceneGenerationService.class);
                    assertThat(context).doesNotHaveBean(PracticeAiChatClientFactory.class);
                    assertThat(context).doesNotHaveBean(PracticeAiProviderManager.class);
                    assertThat(context).hasSingleBean(CustomSceneQualityJudge.class);
                    assertThat(context.getBean(CustomSceneQualityJudge.class))
                            .isInstanceOf(DisabledCustomSceneQualityJudge.class);
                    assertThat(context).hasSingleBean(CustomSceneRepairer.class);
                    assertThat(context.getBean(CustomSceneRepairer.class))
                            .isInstanceOf(DisabledCustomSceneRepairer.class);
                });
    }

    @Test
    void agenticProviderModeBuildsAllMandatoryRoutesAndWiresRealGenerator() {
        agenticContextRunner()
                .withPropertyValues("TEST_AI_KEY=test-secret")
                .run(context -> {
                    assertThat(context).hasNotFailed();
                    var manager = context.getBean(PracticeAiProviderManager.class);
                    assertThat(manager.route(PracticeAiCapability.CUSTOM_SCENE_GENERATOR))
                            .extracting(provider -> provider.providerName())
                            .containsExactly("primary");
                    assertThat(manager.route(PracticeAiCapability.CUSTOM_SCENE_QUALITY_JUDGE))
                            .extracting(provider -> provider.providerName())
                            .containsExactly("primary");
                    assertThat(manager.route(PracticeAiCapability.CUSTOM_SCENE_REPAIR))
                            .extracting(provider -> provider.providerName())
                            .containsExactly("primary");
                    assertThat(context).hasSingleBean(CustomSceneGenerator.class);
                    assertThat(context.getBean(CustomSceneGenerator.class))
                            .isInstanceOf(AgenticCustomSceneGenerator.class);
                    assertThat(context).hasSingleBean(CustomSceneQualityJudge.class);
                    assertThat(context.getBean(CustomSceneQualityJudge.class))
                            .isInstanceOf(AgenticCustomSceneQualityJudge.class);
                    assertThat(context).hasSingleBean(CustomSceneRepairer.class);
                    assertThat(context.getBean(CustomSceneRepairer.class))
                            .isInstanceOf(AgenticCustomSceneRepairer.class);
                });
    }

    @Test
    void agenticProviderModeFailsStartupWhenNamedSecretIsMissing() {
        agenticContextRunner().run(context -> {
            assertThat(context).hasFailed();
            assertThat(context.getStartupFailure()).hasRootCauseMessage(
                    "Required key 'TEST_AI_KEY' not found");
        });
    }

    @Test
    void agenticProviderModeFailsStartupWhenNamedSecretIsBlank() {
        agenticContextRunner()
                .withPropertyValues("TEST_AI_KEY= ")
                .run(context -> {
                    assertThat(context).hasFailed();
                    assertThat(context.getStartupFailure())
                            .hasRootCauseMessage("AI provider secret must not be blank: primary");
                });
    }

    @Test
    void unknownProviderModeFailsContextStartup() {
        contextRunner
                .withPropertyValues("babytalk.practice.discovery.custom-scene.provider-mode=unsafe")
                .run(context -> {
                    assertThat(context).hasFailed();
                    assertThat(context.getStartupFailure())
                            .hasRootCauseInstanceOf(IllegalArgumentException.class)
                            .hasRootCauseMessage("custom scene provider mode must be one of disabled, fake, agentic");
                });
    }

    private CustomSceneGenerator.GeneratorRequest request(String normalizedSceneText) {
        return new CustomSceneGenerator.GeneratorRequest(
                "pgc_wiring_test",
                1,
                normalizedSceneText,
                "m7_11",
                "calmer_care",
                "zh-CN",
                null,
                null,
                CustomSceneGenerator.ContentConstraints.defaults()
        );
    }

    private ApplicationContextRunner agenticContextRunner() {
        return contextRunner.withPropertyValues(
                "babytalk.practice.discovery.custom-scene.provider-mode=agentic",
                "app.ai.routing-policy.version=custom-scene-routing-v1",
                "app.ai.providers.primary.type=openai-compatible",
                "app.ai.providers.primary.base-url=https://example.invalid/v1",
                "app.ai.providers.primary.api-key-environment-variable=TEST_AI_KEY",
                "app.ai.providers.primary.model=gpt-4o-mini",
                "app.ai.providers.primary.timeout=2s",
                "app.ai.providers.primary.max-tokens=128",
                "app.ai.capabilities.custom-scene-generator.provider-names[0]=primary",
                "app.ai.capabilities.custom-scene-quality-judge.provider-names[0]=primary",
                "app.ai.capabilities.custom-scene-repair.provider-names[0]=primary");
    }

    @Configuration(proxyBeanMethods = false)
    @EnableConfigurationProperties(PracticeDiscoveryCustomSceneProperties.class)
    @Import({
            FakeCustomSceneGenerationService.class,
            DisabledCustomSceneGenerationService.class,
            AgenticCustomSceneGenerator.class,
            AgenticCustomSceneQualityJudge.class,
            AgenticCustomSceneRepairer.class,
            DisabledCustomSceneQualityJudge.class,
            FakeCustomSceneRepairer.class,
            DisabledCustomSceneRepairer.class,
            FakeCustomSceneQualityJudge.class,
            JudgeVerdictCalculator.class,
            PracticeAiOpenAiOptionsFactory.class,
            PracticeAiChatClientFactory.class,
            PracticeAiProviderManager.class,
            PracticeAiProviderConfiguration.class
    })
    static class ProviderConfiguration {

        @Bean
        PracticeAiOperationRunner practiceAiOperationRunner() {
            return org.mockito.Mockito.mock(PracticeAiOperationRunner.class);
        }

        @Bean
        PracticeAiStructuredOutputCaller practiceAiStructuredOutputCaller() {
            return org.mockito.Mockito.mock(PracticeAiStructuredOutputCaller.class);
        }

        @Bean
        JudgeResultAuditPort judgeResultAuditPort() {
            return org.mockito.Mockito.mock(JudgeResultAuditPort.class);
        }

        @Bean
        com.zhangspaghetti.babytalk.practice.agentic.PracticeAiAuditPort practiceAiAuditPort() {
            return org.mockito.Mockito.mock(
                    com.zhangspaghetti.babytalk.practice.agentic.PracticeAiAuditPort.class);
        }

        @Bean
        com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry versionedResourceRegistry() {
            return org.mockito.Mockito.mock(
                    com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry.class);
        }
    }
}
