package com.zhangspaghetti.babytalk.practice.discovery;

import cn.hutool.core.util.StrUtil;
import java.time.Duration;
import java.util.Locale;
import java.util.Set;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "babytalk.practice.discovery.custom-scene")
public record PracticeDiscoveryCustomSceneProperties(
        boolean enabled,
        Duration timeout,
        String promptVersion,
        String strategyVersion,
        String providerMode,
        Integer installationBurstLimit,
        Integer installationDailyLimit,
        Integer accountBurstLimit,
        Integer accountDailyLimit,
        Duration burstWindow,
        Duration dailyWindow
) {

    public static final Duration DEFAULT_TIMEOUT = Duration.ofSeconds(5);
    public static final Duration MAX_TIMEOUT = Duration.ofSeconds(5);
    public static final String DEFAULT_PROMPT_VERSION = "practice-custom-scene-v1";
    public static final String DEFAULT_STRATEGY_VERSION = "fake-generator-v1";
    public static final int DEFAULT_INSTALLATION_BURST_LIMIT = 3;
    public static final int DEFAULT_INSTALLATION_DAILY_LIMIT = 10;
    public static final int DEFAULT_ACCOUNT_BURST_LIMIT = 5;
    public static final int DEFAULT_ACCOUNT_DAILY_LIMIT = 20;
    public static final Duration DEFAULT_BURST_WINDOW = Duration.ofMinutes(10);
    public static final Duration DEFAULT_DAILY_WINDOW = Duration.ofDays(1);
    private static final Set<String> SUPPORTED_PROVIDER_MODES = Set.of("disabled", "fake", "agentic");

    public PracticeDiscoveryCustomSceneProperties {
        timeout = timeout == null ? DEFAULT_TIMEOUT : timeout;
        promptVersion = defaultString(promptVersion, DEFAULT_PROMPT_VERSION);
        strategyVersion = defaultString(strategyVersion, DEFAULT_STRATEGY_VERSION);
        validateMaxLength(promptVersion, 48, "prompt version");
        validateMaxLength(strategyVersion, 48, "strategy version");
        providerMode = defaultString(providerMode, "disabled").toLowerCase(Locale.ROOT);
        if (!SUPPORTED_PROVIDER_MODES.contains(providerMode)) {
            throw new IllegalArgumentException("custom scene provider mode must be one of disabled, fake, agentic");
        }
        installationBurstLimit = defaultPositive(installationBurstLimit, DEFAULT_INSTALLATION_BURST_LIMIT, "installation burst limit");
        installationDailyLimit = defaultPositive(installationDailyLimit, DEFAULT_INSTALLATION_DAILY_LIMIT, "installation daily limit");
        accountBurstLimit = defaultPositive(accountBurstLimit, DEFAULT_ACCOUNT_BURST_LIMIT, "account burst limit");
        accountDailyLimit = defaultPositive(accountDailyLimit, DEFAULT_ACCOUNT_DAILY_LIMIT, "account daily limit");
        burstWindow = defaultPositiveDuration(burstWindow, DEFAULT_BURST_WINDOW, "burst window");
        dailyWindow = defaultPositiveDuration(dailyWindow, DEFAULT_DAILY_WINDOW, "daily window");

        if (timeout.isZero() || timeout.isNegative()) {
            throw new IllegalArgumentException("custom scene timeout must be positive");
        }
        if (timeout.compareTo(MAX_TIMEOUT) > 0) {
            throw new IllegalArgumentException("custom scene timeout must not exceed " + MAX_TIMEOUT);
        }
    }

    public static PracticeDiscoveryCustomSceneProperties enabledForTest(String providerMode) {
        return new PracticeDiscoveryCustomSceneProperties(
                true,
                DEFAULT_TIMEOUT,
                DEFAULT_PROMPT_VERSION,
                DEFAULT_STRATEGY_VERSION,
                providerMode,
                null,
                null,
                null,
                null,
                null,
                null
        );
    }

    public boolean providerDisabled() {
        return "disabled".equals(providerMode);
    }

    public boolean fakeProvider() {
        return "fake".equals(providerMode);
    }

    public boolean agenticProvider() {
        return "agentic".equals(providerMode);
    }

    private static String defaultString(String value, String defaultValue) {
        var normalized = trimToNull(value);
        return normalized == null ? defaultValue : normalized;
    }

    private static String trimToNull(String value) {
        return StrUtil.trimToNull(value);
    }

    private static int defaultPositive(Integer value, int defaultValue, String label) {
        if (value == null) {
            return defaultValue;
        }
        if (value < 1) {
            throw new IllegalArgumentException("custom scene " + label + " must be positive");
        }
        return value;
    }

    private static Duration defaultPositiveDuration(Duration value, Duration defaultValue, String label) {
        var resolved = value == null ? defaultValue : value;
        if (resolved.isZero() || resolved.isNegative()) {
            throw new IllegalArgumentException("custom scene " + label + " must be positive");
        }
        return resolved;
    }

    private static void validateMaxLength(String value, int maxLength, String label) {
        if (value.codePointCount(0, value.length()) > maxLength) {
            throw new IllegalArgumentException("custom scene " + label + " must not exceed " + maxLength + " characters");
        }
    }
}
