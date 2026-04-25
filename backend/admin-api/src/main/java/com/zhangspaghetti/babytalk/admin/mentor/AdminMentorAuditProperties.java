package com.zhangspaghetti.babytalk.admin.mentor;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.admin.mentor-audit")
public record AdminMentorAuditProperties(
        @Min(1) int defaultLimit,
        @Min(1) int maxLimit,
        @Min(1) int rateLimitMaxRequests,
        @NotNull Duration rateLimitWindow
) {
}
