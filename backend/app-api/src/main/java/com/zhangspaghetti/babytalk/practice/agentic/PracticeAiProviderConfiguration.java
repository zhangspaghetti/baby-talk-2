package com.zhangspaghetti.babytalk.practice.agentic;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.bind.Bindable;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;

@Configuration(proxyBeanMethods = false)
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "agentic"
)
public class PracticeAiProviderConfiguration {

    @Bean
    PracticeAiProperties practiceAiProperties(Environment environment) {
        return Binder.get(environment)
                .bind("app.ai", Bindable.of(PracticeAiProperties.class))
                .orElseThrow(() -> new IllegalStateException("app.ai configuration is required in agentic mode"));
    }
}
