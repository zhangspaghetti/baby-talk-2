package com.zhangspaghetti.babytalk.practice.generated.audio;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "babytalk.practice.generated-audio")
public record GeneratedSpeechProperties(
        boolean enabled,
        String providerMode,
        Duration timeout,
        Integer maxBytes,
        String voiceVersion,
        String format,
        String baseUrl,
        String apiKeyEnvironmentVariable,
        String model,
        String voice,
        String providerProfile
) {

    private static final Set<String> PROVIDER_MODES = Set.of("disabled", "fake", "openai");
    private static final int MAX_AUDIO_BYTES = 1_048_576;
    private static final Duration MAX_TIMEOUT = Duration.ofSeconds(5);
    private static final Pattern IDENTITY_VALUE = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$");

    public GeneratedSpeechProperties {
        providerMode = normalized(providerMode, "generated speech provider mode").toLowerCase(Locale.ROOT);
        if (!PROVIDER_MODES.contains(providerMode)) {
            throw new IllegalArgumentException("unsupported generated speech provider mode: " + providerMode);
        }
        if (timeout == null || timeout.isZero() || timeout.isNegative() || timeout.compareTo(MAX_TIMEOUT) > 0) {
            throw new IllegalArgumentException("generated speech timeout must be positive and at most 5 seconds");
        }
        if (maxBytes == null || maxBytes <= 0 || maxBytes > MAX_AUDIO_BYTES) {
            throw new IllegalArgumentException("generated speech max bytes must be between 1 and " + MAX_AUDIO_BYTES);
        }
        voiceVersion = normalized(voiceVersion, "generated speech voice version");
        validateIdentityValue(voiceVersion, "voice version");
        format = normalized(format, "generated speech format").toLowerCase(Locale.ROOT);
        if (!"mp3".equals(format)) {
            throw new IllegalArgumentException("generated speech format must be mp3");
        }
        if (enabled && "disabled".equals(providerMode)) {
            throw new IllegalArgumentException("enabled generated speech requires a configured provider");
        }
        if (!enabled && !"disabled".equals(providerMode)) {
            throw new IllegalArgumentException("disabled generated speech must use the disabled provider");
        }
        if ("openai".equals(providerMode)) {
            baseUrl = normalized(baseUrl, "generated speech provider base URL");
            var uri = URI.create(baseUrl);
            if (!"http".equalsIgnoreCase(uri.getScheme()) && !"https".equalsIgnoreCase(uri.getScheme())) {
                throw new IllegalArgumentException("generated speech provider base URL must use HTTP or HTTPS");
            }
            apiKeyEnvironmentVariable = normalized(
                    apiKeyEnvironmentVariable, "generated speech provider API key environment variable");
            if (!apiKeyEnvironmentVariable.matches("[A-Z][A-Z0-9_]*")) {
                throw new IllegalArgumentException("generated speech API key environment variable is invalid");
            }
            model = normalized(model, "generated speech model");
            validateIdentityValue(model, "model");
            voice = normalized(voice, "generated speech voice");
        } else {
            baseUrl = null;
            apiKeyEnvironmentVariable = null;
            model = null;
            voice = null;
        }
        providerProfile = normalized(providerProfile == null ? "default" : providerProfile, "generated speech provider profile");
        validateIdentityValue(providerProfile, "provider profile");
    }

    public String mimeType() {
        return "audio/mpeg";
    }

    public GeneratedSpeechConfigurationIdentity configurationIdentity() {
        return new GeneratedSpeechConfigurationIdentity(
                providerMode,
                "openai".equals(providerMode) ? model : providerMode,
                providerProfile,
                sha256(String.join("\n",
                        providerMode,
                        timeout.toString(),
                        Integer.toString(maxBytes),
                        voiceVersion,
                        format,
                        providerProfile,
                        nullToEmpty(baseUrl),
                        nullToEmpty(model),
                        nullToEmpty(voice)))
        );
    }

    private static String normalized(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " must not be blank");
        }
        return value.trim();
    }

    private static void validateIdentityValue(String value, String field) {
        if (!IDENTITY_VALUE.matcher(value).matches()) {
            throw new IllegalArgumentException("generated speech " + field + " identity is invalid");
        }
    }

    private static String nullToEmpty(String value) {
        return value == null ? "" : value;
    }

    private static String sha256(String value) {
        try {
            return java.util.HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }
}
