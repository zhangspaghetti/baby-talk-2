package com.zhangspaghetti.babytalk.practice.generated.audio;

import java.util.Objects;
import java.util.regex.Pattern;

/**
 * Sanitized runtime identity for authenticated generated-audio UAT. It deliberately excludes
 * credentials, request text, and provider request/response payloads.
 */
public record GeneratedSpeechConfigurationIdentity(
        String provider,
        String model,
        String profile,
        String configurationFingerprint
) {

    private static final Pattern IDENTITY_VALUE = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$");
    private static final Pattern FINGERPRINT = Pattern.compile("^[a-f0-9]{64}$");

    public GeneratedSpeechConfigurationIdentity {
        provider = requireIdentityValue(provider, "provider");
        model = requireIdentityValue(model, "model");
        profile = requireIdentityValue(profile, "profile");
        configurationFingerprint = Objects.requireNonNull(configurationFingerprint, "configuration fingerprint");
        if (!FINGERPRINT.matcher(configurationFingerprint).matches()) {
            throw new IllegalArgumentException("generated speech configuration fingerprint is invalid");
        }
    }

    private static String requireIdentityValue(String value, String field) {
        if (value == null || !IDENTITY_VALUE.matcher(value).matches()) {
            throw new IllegalArgumentException("generated speech " + field + " identity is invalid");
        }
        return value;
    }
}
