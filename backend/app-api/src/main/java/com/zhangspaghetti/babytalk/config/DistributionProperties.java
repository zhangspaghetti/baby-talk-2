package com.zhangspaghetti.babytalk.config;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import java.util.Map;
import java.util.Set;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.distribution")
public record DistributionProperties(
        @NotBlank String defaultChannel,
        @NotBlank String downloadDefaultSource,
        @NotBlank String upgradeDefaultSource,
        @NotEmpty Set<String> allowedSources,
        @NotEmpty Map<String, @Valid ChannelProperties> channels
) {

    public record ChannelProperties(
            @NotBlank String label,
            @NotEmpty Map<String, String> platforms
    ) {
    }
}
