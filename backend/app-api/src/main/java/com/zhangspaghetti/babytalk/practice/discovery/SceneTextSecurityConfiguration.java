package com.zhangspaghetti.babytalk.practice.discovery;

import com.ibm.icu.text.SpoofChecker;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration(proxyBeanMethods = false)
public class SceneTextSecurityConfiguration {

    @Bean
    public SpoofChecker sceneTextSpoofChecker() {
        return configuredSpoofChecker();
    }

    public static SpoofChecker configuredSpoofChecker() {
        return new SpoofChecker.Builder().setChecks(SpoofChecker.CONFUSABLE).build();
    }
}
