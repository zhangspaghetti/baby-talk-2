package com.zhangspaghetti.babytalk.practice.generated.audio;

import java.util.Arrays;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;

@Configuration(proxyBeanMethods = false)
public class GeneratedSpeechSynthesisConfiguration {

    @Bean
    GeneratedSpeechSynthesisPort generatedSpeechSynthesisPort(
            GeneratedSpeechProperties properties,
            Environment environment
    ) {
        return switch (properties.providerMode()) {
            case "disabled" -> new DisabledGeneratedSpeechSynthesisProvider();
            case "fake" -> fakeProvider(properties, environment);
            case "openai" -> new ConfiguredGeneratedSpeechProvider(
                    properties,
                    environment.getRequiredProperty(properties.apiKeyEnvironmentVariable())
            );
            default -> throw new IllegalStateException("unsupported generated speech provider mode");
        };
    }

    private GeneratedSpeechSynthesisPort fakeProvider(GeneratedSpeechProperties properties, Environment environment) {
        var devProfile = Arrays.stream(environment.getActiveProfiles()).anyMatch("dev"::equals);
        if (!devProfile) {
            throw new IllegalStateException("fake generated speech provider is restricted to the dev profile");
        }
        return new FakeGeneratedSpeechSynthesisProvider(properties);
    }
}
