package com.zhangspaghetti.babytalk.practice.agentic;

import java.util.Objects;

/** Database-safe provider identity limits shared by configuration, audit, and provenance. */
public final class PracticeAiProviderIdentity {

    public static final int PROVIDER_NAME_MAX_CODE_POINTS = 64;
    public static final int MODEL_NAME_MAX_CODE_POINTS = 96;

    private PracticeAiProviderIdentity() {
    }

    public static String requireProviderName(String providerName) {
        return requireWithinCodePointLimit(
                providerName,
                "providerName",
                PROVIDER_NAME_MAX_CODE_POINTS);
    }

    public static String requireModelName(String modelName) {
        return requireWithinCodePointLimit(
                modelName,
                "modelName",
                MODEL_NAME_MAX_CODE_POINTS);
    }

    private static String requireWithinCodePointLimit(
            String value,
            String field,
            int limit
    ) {
        Objects.requireNonNull(value, field);
        if (value.isBlank()) {
            throw new IllegalArgumentException(field + " must be non-blank");
        }
        if (value.codePointCount(0, value.length()) > limit) {
            throw new IllegalArgumentException(field + " must not exceed " + limit + " code points");
        }
        return value;
    }
}
