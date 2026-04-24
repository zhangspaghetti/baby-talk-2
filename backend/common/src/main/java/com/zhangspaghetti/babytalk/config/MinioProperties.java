package com.zhangspaghetti.babytalk.config;

import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * MinIO 对象存储连接配置。
 * 绑定 application.yml 中 app.minio.* 前缀。
 */
@Validated
@ConfigurationProperties(prefix = "app.minio")
public record MinioProperties(
        @NotBlank String endpoint,
        @NotBlank String accessKey,
        @NotBlank String secretKey,
        @NotBlank String bucketName
) {
}
