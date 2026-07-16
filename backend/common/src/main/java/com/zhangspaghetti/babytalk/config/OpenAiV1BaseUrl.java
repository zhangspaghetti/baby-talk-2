package com.zhangspaghetti.babytalk.config;

/**
 * Adapts the configured provider root to the versioned base URL expected by
 * the Spring AI 2 native OpenAI SDK.
 */
public final class OpenAiV1BaseUrl {

    private OpenAiV1BaseUrl() {
    }

    public static String fromProviderRoot(String baseUrl) {
        String normalized = baseUrl == null ? "" : baseUrl.trim();
        while (normalized.endsWith("/")) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }
        return normalized.endsWith("/v1") ? normalized : normalized + "/v1";
    }
}
