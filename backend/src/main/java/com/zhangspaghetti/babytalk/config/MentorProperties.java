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
        String aiBaseUrl,
        String aiApiKey,
        String aiModel,
        Double aiTemperature,
        Integer aiMaxTokens,
        @Min(1) int rateLimitMaxRequests,
        @NotNull Duration rateLimitWindow,
        @Min(1) int promptMaxLength,
        @Min(1) int responseMaxLength,
        @NotEmpty List<@NotBlank String> allowedSurfaces,
        @NotEmpty List<@NotBlank String> allowedModes,
        List<@NotBlank String> blockedKeywords,
        @NotBlank String simulateTimeoutToken,
        @NotBlank String simulateMalformedToken,
        @NotBlank String simulateUnavailableToken,
        String searchMode,
        Duration sessionTimeout
) {
    /**
     * 返回 searchMode，默认为 "none"。
     * 有效值: "agentic", "rag", "none"
     */
    public String effectiveSearchMode() {
        return (searchMode == null || searchMode.isBlank()) ? "none" : searchMode.trim().toLowerCase();
    }

    /**
     * 返回 sessionTimeout，默认 30 分钟。
     */
    public Duration effectiveSessionTimeout() {
        return sessionTimeout == null ? Duration.ofMinutes(30) : sessionTimeout;
    }
}
