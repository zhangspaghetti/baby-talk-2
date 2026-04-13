package com.zhangspaghetti.babytalk.config;

import com.zhangspaghetti.babytalk.service.DevMentorProvider;
import com.zhangspaghetti.babytalk.service.MentorProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MentorProviderConfiguration {

    @Bean
    public MentorProvider mentorProvider(MentorProperties properties) {
        if ("dev".equalsIgnoreCase(properties.providerMode())) {
            return new DevMentorProvider(properties);
        }
        return request -> {
            throw new MentorProvider.ProviderUnavailableException(
                    "Mentor provider mode `%s` 尚未实现，请先使用 dev seam 或接入真实 provider。"
                            .formatted(properties.providerMode())
            );
        };
    }
}
