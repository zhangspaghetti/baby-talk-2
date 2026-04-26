package com.zhangspaghetti.babytalk.admin.config;

import com.zhangspaghetti.babytalk.admin.distribution.AdminDistributionStatsReadMapper;
import com.zhangspaghetti.babytalk.admin.distribution.AdminDistributionStatsReadRepository;
import com.zhangspaghetti.babytalk.admin.knowledge.AdminKnowledgeIngestionMapper;
import com.zhangspaghetti.babytalk.admin.knowledge.AdminKnowledgeIngestionRepository;
import com.zhangspaghetti.babytalk.admin.knowledge.AdminKnowledgeKgMapper;
import com.zhangspaghetti.babytalk.admin.knowledge.AdminKnowledgeKgRepository;
import com.zhangspaghetti.babytalk.admin.mentor.AdminMentorAuditReadMapper;
import com.zhangspaghetti.babytalk.admin.mentor.AdminMentorAuditReadRepository;
import com.zhangspaghetti.babytalk.admin.overview.AdminOverviewReadRepository;
import com.zhangspaghetti.babytalk.admin.rbac.AdminPermissionCatalog;
import com.zhangspaghetti.babytalk.admin.rbac.AdminRbacMapper;
import com.zhangspaghetti.babytalk.admin.rbac.AdminRbacRepository;
import com.zhangspaghetti.babytalk.admin.users.AdminUserReadMapper;
import com.zhangspaghetti.babytalk.admin.users.AdminUserReadRepository;
import com.zhangspaghetti.babytalk.config.AsyncConfiguration;
import com.zhangspaghetti.babytalk.config.EmbeddingConfiguration;
import com.zhangspaghetti.babytalk.config.MinioProperties;
import com.zhangspaghetti.babytalk.ingestion.IngestionMapper;
import com.zhangspaghetti.babytalk.ingestion.IngestionRepository;
import com.zhangspaghetti.babytalk.ingestion.IngestionService;
import io.minio.MinioClient;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;

@Configuration
@EnableConfigurationProperties(MinioProperties.class)
@Import({AsyncConfiguration.class, EmbeddingConfiguration.class, IngestionService.class})
public class AdminDataAccessConfiguration {

    @Bean
    AdminPermissionCatalog adminPermissionCatalog() {
        return new AdminPermissionCatalog();
    }

    @Bean
    AdminRbacRepository adminRbacRepository(AdminRbacMapper adminRbacMapper) {
        return new AdminRbacRepository(adminRbacMapper);
    }

    @Bean
    AdminUserReadRepository adminUserReadRepository(AdminUserReadMapper adminUserReadMapper) {
        return new AdminUserReadRepository(adminUserReadMapper);
    }

    @Bean
    AdminMentorAuditReadRepository adminMentorAuditReadRepository(AdminMentorAuditReadMapper adminMentorAuditReadMapper) {
        return new AdminMentorAuditReadRepository(adminMentorAuditReadMapper);
    }

    @Bean
    AdminDistributionStatsReadRepository adminDistributionStatsReadRepository(
            AdminDistributionStatsReadMapper adminDistributionStatsReadMapper
    ) {
        return new AdminDistributionStatsReadRepository(adminDistributionStatsReadMapper);
    }

    @Bean
    AdminKnowledgeIngestionRepository adminKnowledgeIngestionRepository(
            AdminKnowledgeIngestionMapper adminKnowledgeIngestionMapper
    ) {
        return new AdminKnowledgeIngestionRepository(adminKnowledgeIngestionMapper);
    }

    @Bean
    AdminKnowledgeKgRepository adminKnowledgeKgRepository(AdminKnowledgeKgMapper adminKnowledgeKgMapper) {
        return new AdminKnowledgeKgRepository(adminKnowledgeKgMapper);
    }

    @Bean
    AdminOverviewReadRepository adminOverviewReadRepository(
            AdminKnowledgeIngestionRepository adminKnowledgeIngestionRepository,
            AdminKnowledgeKgRepository adminKnowledgeKgRepository,
            AdminMentorAuditReadRepository adminMentorAuditReadRepository,
            AdminDistributionStatsReadRepository adminDistributionStatsReadRepository
    ) {
        return new AdminOverviewReadRepository(
                adminKnowledgeIngestionRepository,
                adminKnowledgeKgRepository,
                adminMentorAuditReadRepository,
                adminDistributionStatsReadRepository
        );
    }

    @Bean
    IngestionRepository ingestionRepository(IngestionMapper ingestionMapper) {
        return new IngestionRepository(ingestionMapper);
    }

    @Bean
    MinioClient minioClient(MinioProperties properties) {
        return MinioClient.builder()
                .endpoint(properties.endpoint())
                .credentials(properties.accessKey(), properties.secretKey())
                .build();
    }
}
