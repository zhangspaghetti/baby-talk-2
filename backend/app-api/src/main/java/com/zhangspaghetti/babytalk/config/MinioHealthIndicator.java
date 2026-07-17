package com.zhangspaghetti.babytalk.config;

import io.minio.BucketExistsArgs;
import io.minio.MinioClient;
import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.HealthIndicator;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * MinIO 健康指示器 — 通过 bucketExists 检测 MinIO 连通性。
 * 只检测连通性，不创建 bucket（bucket 创建由 ingestion 管道负责）。
 */
@Component
@Profile("!test")
public class MinioHealthIndicator implements HealthIndicator {

    private final MinioClient minioClient;
    private final MinioProperties properties;

    public MinioHealthIndicator(MinioClient minioClient, MinioProperties properties) {
        this.minioClient = minioClient;
        this.properties = properties;
    }

    @Override
    public Health health() {
        try {
            boolean exists = minioClient.bucketExists(
                    BucketExistsArgs.builder()
                            .bucket(properties.bucketName())
                            .build()
            );
            return Health.up()
                    .withDetail("endpoint", properties.endpoint())
                    .withDetail("bucket", properties.bucketName())
                    .withDetail("bucketExists", exists)
                    .build();
        } catch (Exception e) {
            return Health.down(e)
                    .withDetail("endpoint", properties.endpoint())
                    .withDetail("bucket", properties.bucketName())
                    .build();
        }
    }
}
