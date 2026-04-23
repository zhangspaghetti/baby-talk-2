package com.zhangspaghetti.babytalk.config;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Embedding 模型连接配置。
 * 绑定 application.yml 中 app.embedding.* 前缀。
 * 独立于 Mentor chat 的配置，允许使用不同的 API 端点/密钥/模型。
 */
@Validated
@ConfigurationProperties(prefix = "app.embedding")
public record EmbeddingProperties(
        @NotBlank String baseUrl,
        @NotBlank String apiKey,
        @NotBlank String model,
        @Min(1) int dimensions
) {
    /**
     * 默认构造：dimensions 默认值 1536（OpenAI text-embedding-3-small / ada-002）
     */
    public EmbeddingProperties {
        if (dimensions <= 0) {
            dimensions = 1536;
        }
    }
}
