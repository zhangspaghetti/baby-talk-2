package com.zhangspaghetti.babytalk.practice.agentic.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import org.junit.jupiter.api.Test;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.boot.test.context.ConfigDataApplicationContextInitializer;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Import;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.env.StandardEnvironment;

class VersionedResourceRegistryApplicationConfigTest {

    private static final String PROFILE_PROPERTY =
            "babytalk.practice.agentic.versioned-resources.profile";
    private static final String PROFILE_ENVIRONMENT = "BABY_TALK_PRACTICE_AI_PROFILE";
    private static final String LATEST_PROFILE =
            "classpath:config/practice-ai/profiles/custom-scene-generation-v7.yml";
    private static final String LEGACY_PROFILE =
            "classpath:config/practice-ai/profiles/custom-scene-generation-v6.yml";

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withInitializer(context -> {
                var propertySources = context.getEnvironment().getPropertySources();
                propertySources.remove(StandardEnvironment.SYSTEM_PROPERTIES_PROPERTY_SOURCE_NAME);
                propertySources.remove(StandardEnvironment.SYSTEM_ENVIRONMENT_PROPERTY_SOURCE_NAME);
            })
            .withInitializer(new ConfigDataApplicationContextInitializer())
            .withUserConfiguration(RegistryConfiguration.class);

    @Test
    void applicationDefaultsToLatestQualityJudgeInferenceProfile() throws IOException {
        var application = new YamlPropertySourceLoader()
                .load("application", new ClassPathResource("application.yml"))
                .get(0);

        assertThat(application.getProperty(PROFILE_PROPERTY))
                .isEqualTo("${BABY_TALK_PRACTICE_AI_PROFILE:" + LATEST_PROFILE + "}");
    }

    @Test
    void applicationDefaultBindingLoadsQualityJudgeInferencePolicy() {
        contextRunner.run(context -> {
            assertThat(context).hasNotFailed();
            assertThat(context.getBean(VersionedResourceRegistry.class)
                    .currentGenerationProfile()
                    .version())
                    .isEqualTo("custom-scene-generation-v7");
        });
    }

    @Test
    void explicitEnvironmentOverrideCanStillSelectLockedLegacyProfile() {
        contextRunner
                .withPropertyValues(PROFILE_ENVIRONMENT + "=" + LEGACY_PROFILE)
                .run(context -> {
                    assertThat(context).hasNotFailed();
                    assertThat(context.getBean(VersionedResourceRegistry.class)
                            .currentGenerationProfile()
                            .version())
                            .isEqualTo("custom-scene-generation-v6");
                });
    }

    @TestConfiguration(proxyBeanMethods = false)
    @Import(VersionedResourceRegistry.class)
    static class RegistryConfiguration {
    }
}
