package com.zhangspaghetti.babytalk.admin.distribution;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.admin.distribution-stats")
public record AdminDistributionStatsProperties(
        @Pattern(regexp = "7d|30d|90d") String defaultRange,
        @Min(1) @Max(500) int detailLimit
) {
}
