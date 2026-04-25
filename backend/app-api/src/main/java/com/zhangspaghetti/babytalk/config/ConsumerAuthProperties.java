package com.zhangspaghetti.babytalk.config;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.auth")
public record ConsumerAuthProperties(
        String issuer,
        String jwtSecret,
        Duration accessTokenTtl,
        Duration refreshTokenTtl
) {
}
