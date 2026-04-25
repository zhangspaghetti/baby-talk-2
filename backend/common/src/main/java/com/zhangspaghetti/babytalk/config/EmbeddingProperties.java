package com.zhangspaghetti.babytalk.config;

import jakarta.validation.constraints.Min;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Embedding 模型连接配置。
 * 绑定 application.yml 中 app.embedding.* 前缀。
 */
@Validated
@ConfigurationProperties(prefix = "app.embedding")
public record EmbeddingProperties(
        Mode mode,
        String baseUrl,
        String apiKey,
        String model,
        @Min(1) int dimensions
) {

    public enum Mode {
        OPENAI,
        DEV_HASH
    }

    public EmbeddingProperties {
        mode = mode != null ? mode : Mode.OPENAI;
        baseUrl = normalize(baseUrl);
        apiKey = normalize(apiKey);
        model = normalize(model);
        if (dimensions <= 0) {
            dimensions = 1536;
        }
        if (mode == Mode.OPENAI) {
            requireNotBlank(baseUrl, "app.embedding.base-url");
            requireNotBlank(apiKey, "app.embedding.api-key");
            requireNotBlank(model, "app.embedding.model");
        } else if (model.isBlank()) {
            model = "dev-hash-v1";
        }
    }

    public boolean usesDevHashMode() {
        return mode == Mode.DEV_HASH;
    }

    private static String normalize(String value) {
        return value == null ? "" : value.trim();
    }

    private static void requireNotBlank(String value, String fieldName) {
        if (value.isBlank()) {
            throw new IllegalArgumentException(fieldName + " must not be blank when app.embedding.mode=openai");
        }
    }
}
