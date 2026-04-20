package com.zhangspaghetti.babytalk;

import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * 集成测试共享基类 — Singleton Container Pattern。
 * <p>
 * 所有继承此类的测试共享同一个 PostgreSQL (pgvector) 容器，
 * 由 {@link DynamicPropertySource} 在 Spring context 初始化前动态注入数据源配置。
 * Spring context caching 确保同配置的测试类共享 ApplicationContext，
 * 避免每个测试类各启动一个容器或 context。
 */
@SpringBootTest
@ActiveProfiles("test")
public abstract class AbstractIntegrationTest {

    // Singleton container — JVM 级别只启动一次，所有测试类复用
    @SuppressWarnings("resource")
    static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>(
                    DockerImageName.parse("pgvector/pgvector:pg16")
                            .asCompatibleSubstituteFor("postgres"))
                    .withDatabaseName("babytalk_test")
                    .withUsername("babytalk")
                    .withPassword("babytalk");

    static {
        // Docker Desktop v29+ 要求 API version >= 1.44，而 docker-java 3.4.1 默认使用更低版本
        // 通过系统属性告知 docker-java 使用兼容的 API 版本
        if (System.getenv("DOCKER_API_VERSION") == null
                && System.getProperty("api.version") == null) {
            System.setProperty("api.version", "1.44");
        }
        POSTGRES.start();
    }

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }
}
