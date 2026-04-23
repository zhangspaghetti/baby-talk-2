package com.zhangspaghetti.babytalk.migration;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
class DbMigrationSmokeTest {

    @SuppressWarnings("resource")
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("pgvector/pgvector:pg16")
                    .asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("babytalk_migration_test")
            .withUsername("babytalk")
            .withPassword("babytalk");

    static {
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

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void appliesAllSqlMigrationsToFreshDatabase() {
        Integer appliedCount = jdbcTemplate.queryForObject(
                """
                select count(*)
                from flyway_schema_history
                where success = true
                  and version is not null
                """,
                Integer.class);
        assertThat(appliedCount).isEqualTo(13);

        Integer trackedVersions = jdbcTemplate.queryForObject(
                """
                select count(*)
                from flyway_schema_history
                where success = true
                  and version in ('3', '14', '15')
                """,
                Integer.class);
        assertThat(trackedVersions).isEqualTo(3);

        assertThat(tableExists("accounts")).isTrue();
        assertThat(tableExists("spring_ai_chat_memory")).isTrue();
        assertThat(tableExists("kg_entities")).isTrue();
        assertThat(tableExists("admin_principals")).isTrue();
        assertThat(tableExists("admin_refresh_tokens")).isTrue();
    }

    private boolean tableExists(String tableName) {
        Boolean exists = jdbcTemplate.queryForObject(
                """
                select exists(
                    select 1
                    from information_schema.tables
                    where table_schema = current_schema()
                      and table_name = ?
                )
                """,
                Boolean.class,
                tableName);
        return Boolean.TRUE.equals(exists);
    }
}
