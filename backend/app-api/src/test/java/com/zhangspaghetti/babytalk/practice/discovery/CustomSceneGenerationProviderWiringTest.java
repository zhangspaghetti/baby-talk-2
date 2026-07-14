package com.zhangspaghetti.babytalk.practice.discovery;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
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
                    assertThat(context).hasSingleBean(CustomSceneGenerationService.class);
                    assertThat(context.getBean(CustomSceneGenerationService.class))
                            .isInstanceOf(FakeCustomSceneGenerationService.class);

                    var candidate = context.getBean(CustomSceneGenerationService.class)
                            .generateCustomSceneStarter(request("睡前哄宝宝"));

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
                    var candidate = context.getBean(CustomSceneGenerationService.class)
                            .generateCustomSceneStarter(request("出门前宝宝不想穿鞋"));

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
                            .getBean(CustomSceneGenerationService.class)
                            .generateCustomSceneStarter(request("给宝宝涂防晒"))))
                            .isInstanceOf(CustomSceneGenerationService.GenerationUnavailableException.class)
                            .satisfies(error -> {
                                var unavailable = (CustomSceneGenerationService.GenerationUnavailableException) error;
                                assertThat(unavailable.reason()).isEqualTo("fake_scene_not_supported");
                                assertThat(unavailable.retryable()).isFalse();
                            });
                });
    }

    @Test
    void fakeProviderIsNotAvailableOutsideDevOrTestProfiles() {
        contextRunner
                .withPropertyValues("babytalk.practice.discovery.custom-scene.provider-mode=fake")
                .run(context -> assertThat(context).doesNotHaveBean(CustomSceneGenerationService.class));
    }

    @Test
    void disabledProviderModeWiresDisabledBean() {
        contextRunner
                .withPropertyValues("babytalk.practice.discovery.custom-scene.provider-mode=disabled")
                .run(context -> {
                    assertThat(context).hasSingleBean(CustomSceneGenerationService.class);
                    assertThat(context.getBean(CustomSceneGenerationService.class))
                            .isInstanceOf(DisabledCustomSceneGenerationService.class);
                });
    }

    @Test
    void agenticProviderModeWiresExplicitNotImplementedBean() {
        contextRunner
                .withPropertyValues("babytalk.practice.discovery.custom-scene.provider-mode=agentic")
                .run(context -> {
                    assertThat(context).hasSingleBean(CustomSceneGenerationService.class);
                    assertThat(context.getBean(CustomSceneGenerationService.class).getClass().getSimpleName())
                            .isEqualTo("AgenticUnavailableCustomSceneGenerationService");
                    assertThat(org.assertj.core.api.Assertions.catchThrowable(() -> context
                            .getBean(CustomSceneGenerationService.class)
                            .generateCustomSceneStarter(request("睡前哄宝宝"))))
                            .isInstanceOf(CustomSceneGenerationService.GenerationUnavailableException.class)
                            .satisfies(error -> {
                                var unavailable = (CustomSceneGenerationService.GenerationUnavailableException) error;
                                assertThat(unavailable.reason()).isEqualTo("agentic_not_implemented");
                                assertThat(unavailable.retryable()).isFalse();
                            });
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

    private CustomSceneGenerationService.CustomSceneGenerationRequest request(String normalizedSceneText) {
        return new CustomSceneGenerationService.CustomSceneGenerationRequest(
                "pgc_wiring_test",
                normalizedSceneText,
                PracticeDiscoverySurface.ONBOARDING,
                PracticeDiscoveryMode.CUSTOM_SCENE,
                "m7_11",
                "calmer_care",
                "zh-CN",
                "trace_wiring_test",
                Duration.ofSeconds(5),
                CustomSceneGenerationService.ContentConstraints.defaults(),
                "practice-custom-scene-v1",
                "fake-generator-v1"
        );
    }

    @Configuration(proxyBeanMethods = false)
    @EnableConfigurationProperties(PracticeDiscoveryCustomSceneProperties.class)
    @Import({
            FakeCustomSceneGenerationService.class,
            DisabledCustomSceneGenerationService.class,
            AgenticUnavailableCustomSceneGenerationService.class
    })
    static class ProviderConfiguration {
    }
}
