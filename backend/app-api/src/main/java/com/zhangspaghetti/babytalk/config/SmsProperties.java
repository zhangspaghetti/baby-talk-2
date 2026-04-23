package com.zhangspaghetti.babytalk.config;

import jakarta.validation.constraints.NotBlank;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.sms")
public record SmsProperties(
        @NotBlank String providerMode,
        String devCode,
        Duration challengeTtl,
        boolean simulateTimeout
) {
}
