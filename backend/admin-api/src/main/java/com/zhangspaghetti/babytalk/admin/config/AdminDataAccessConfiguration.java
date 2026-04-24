package com.zhangspaghetti.babytalk.admin.config;

import com.zhangspaghetti.babytalk.admin.distribution.AdminDistributionStatsReadRepository;
import com.zhangspaghetti.babytalk.admin.knowledge.AdminKnowledgeIngestionRepository;
import com.zhangspaghetti.babytalk.admin.knowledge.AdminKnowledgeKgRepository;
import com.zhangspaghetti.babytalk.admin.mentor.AdminMentorAuditReadRepository;
import com.zhangspaghetti.babytalk.admin.rbac.AdminPermissionCatalog;
import com.zhangspaghetti.babytalk.admin.rbac.AdminRbacRepository;
import com.zhangspaghetti.babytalk.admin.users.AdminUserReadRepository;
import com.zhangspaghetti.babytalk.config.AsyncConfiguration;
import com.zhangspaghetti.babytalk.config.EmbeddingConfiguration;
import com.zhangspaghetti.babytalk.config.MinioProperties;
import com.zhangspaghetti.babytalk.ingestion.IngestionRepository;
import com.zhangspaghetti.babytalk.ingestion.IngestionService;
import io.minio.MinioClient;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;

@Configuration
@EnableConfigurationProperties(MinioProperties.class)
@Import({AsyncConfiguration.class, EmbeddingConfiguration.class, IngestionService.class})
public class AdminDataAccessConfiguration {

    @Bean
    AdminPermissionCatalog adminPermissionCatalog() {
        return new AdminPermissionCatalog();
    }

    @Bean
    AdminRbacRepository adminRbacRepository(JdbcTemplate jdbcTemplate) {
        return new AdminRbacRepository(jdbcTemplate);
    }

    @Bean
    AdminUserReadRepository adminUserReadRepository(JdbcTemplate jdbcTemplate) {
        return new AdminUserReadRepository(jdbcTemplate);
    }

    @Bean
    AdminMentorAuditReadRepository adminMentorAuditReadRepository(JdbcTemplate jdbcTemplate) {
        return new AdminMentorAuditReadRepository(jdbcTemplate);
    }

    @Bean
    AdminDistributionStatsReadRepository adminDistributionStatsReadRepository(JdbcTemplate jdbcTemplate) {
        return new AdminDistributionStatsReadRepository(jdbcTemplate);
    }

    @Bean
    AdminKnowledgeIngestionRepository adminKnowledgeIngestionRepository(JdbcTemplate jdbcTemplate) {
        return new AdminKnowledgeIngestionRepository(jdbcTemplate);
    }

    @Bean
    AdminKnowledgeKgRepository adminKnowledgeKgRepository(JdbcTemplate jdbcTemplate) {
        return new AdminKnowledgeKgRepository(jdbcTemplate);
    }

    @Bean
    IngestionRepository ingestionRepository(JdbcTemplate jdbcTemplate) {
        return new IngestionRepository(jdbcTemplate);
    }

    @Bean
    MinioClient minioClient(MinioProperties properties) {
        return MinioClient.builder()
                .endpoint(properties.endpoint())
                .credentials(properties.accessKey(), properties.secretKey())
                .build();
    }
}
