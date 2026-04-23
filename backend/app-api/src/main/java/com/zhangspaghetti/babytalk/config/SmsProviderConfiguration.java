package com.zhangspaghetti.babytalk.config;

import com.zhangspaghetti.babytalk.service.DevSmsVerificationProvider;
import com.zhangspaghetti.babytalk.service.SmsVerificationProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class SmsProviderConfiguration {

    @Bean
    public SmsVerificationProvider smsVerificationProvider(SmsProperties properties) {
        if ("dev".equalsIgnoreCase(properties.providerMode())) {
            return new DevSmsVerificationProvider(properties);
        }
        return (normalizedPhoneNumber, now) -> {
            throw new SmsVerificationProvider.ProviderMisconfiguredException(
                    "SMS provider mode `%s` 尚未实现，请先配置 dev stub 或接入真实 provider。"
                            .formatted(properties.providerMode())
            );
        };
    }
}
