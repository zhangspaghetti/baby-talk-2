package com.zhangspaghetti.babytalk.config;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import java.util.Map;
import java.util.Set;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.share.landing")
public record ShareLandingProperties(
        @NotBlank String publicBaseUrl,
        @NotNull Duration defaultLinkTtl,
        @NotBlank String downloadFallbackPath,
        @NotBlank String downloadFallbackSource,
        @NotEmpty Set<String> allowedSources,
        @NotNull Map<String, String> openAppTargets
) {
}
