package com.zhangspaghetti.babytalk.config;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.mentor")
public record MentorProperties(
        @NotBlank String providerMode,
        @NotNull Duration providerTimeout,
        @Min(1) int rateLimitMaxRequests,
        @NotNull Duration rateLimitWindow,
        @Min(1) int promptMaxLength,
        @Min(1) int responseMaxLength,
        @NotEmpty List<@NotBlank String> allowedSurfaces,
        @NotEmpty List<@NotBlank String> allowedModes,
        List<@NotBlank String> blockedKeywords,
        @NotBlank String simulateTimeoutToken,
        @NotBlank String simulateMalformedToken,
        @NotBlank String simulateUnavailableToken
) {
}
