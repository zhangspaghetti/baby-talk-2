package com.zhangspaghetti.babytalk.config;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.contract")
public record ApiContractProperties(
        @NotBlank String minSupportedVersion,
        @NotBlank String upgradeUrl,
        @Min(1) int syncMaxBatchSize,
        @Min(1) int bootstrapMaxEvents
) {
}
