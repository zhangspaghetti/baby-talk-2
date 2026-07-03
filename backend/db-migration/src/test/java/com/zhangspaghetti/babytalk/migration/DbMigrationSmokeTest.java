package com.zhangspaghetti.babytalk.migration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
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
        assertThat(appliedCount).isEqualTo(DbMigrationApplication.EXPECTED_APPLIED_MIGRATION_COUNT);

        String currentVersion = jdbcTemplate.queryForObject(
                """
                select version
                from flyway_schema_history
                where success = true
                  and version is not null
                order by installed_rank desc
                limit 1
                """,
                String.class);
        assertThat(currentVersion).isEqualTo(DbMigrationApplication.EXPECTED_CURRENT_VERSION);

        Integer trackedVersions = jdbcTemplate.queryForObject(
                """
                select count(*)
                from flyway_schema_history
                where success = true
                  and version in ('3', '14', '15', '16', '17', '18', '19', '24')
                """,
                Integer.class);
        assertThat(trackedVersions).isEqualTo(8);

        assertThat(tableExists("accounts")).isTrue();
        assertThat(tableExists("spring_ai_chat_memory")).isTrue();
        assertThat(tableExists("kg_entities")).isTrue();
        assertThat(tableExists("admin_principals")).isTrue();
        assertThat(tableExists("admin_refresh_tokens")).isTrue();
        assertThat(tableExists("account_refresh_tokens")).isTrue();
        assertThat(tableExists("admin_permissions")).isTrue();
        assertThat(tableExists("admin_role_permissions")).isTrue();
        assertThat(tableExists("palace_rooms")).isTrue();
        assertThat(tableExists("palace_bridge_edges")).isTrue();
        assertThat(tableExists("palace_projection_version")).isTrue();
        assertThat(tableExists("palace_query_traces")).isTrue();
        assertThat(tableExists("baby_profiles")).isTrue();

        List<String> expectedPermissionCodes = List.of(
                "users:read",
                "users:write",
                "admins:read",
                "admins:write",
                "rbac:read",
                "rbac:write",
                "rag:read",
                "rag:write",
                "kg:read",
                "kg:review",
                "mentor:audit",
                "distribution:read");
        List<String> seededPermissionCodes = jdbcTemplate.queryForList(
                """
                select permission_code
                from admin_permissions
                order by permission_code asc
                """,
                String.class);
        assertThat(seededPermissionCodes)
                .containsExactlyInAnyOrderElementsOf(expectedPermissionCodes);

        Integer seededSuperAdminGrants = jdbcTemplate.queryForObject(
                """
                select count(*)
                from admin_role_permissions
                where role_code = 'super_admin'
                """,
                Integer.class);
        assertThat(seededSuperAdminGrants).isEqualTo(expectedPermissionCodes.size());
    }

    @Test
    void createsPalaceProjectionTablesAndIndexes() {
        assertThat(columnNamesFor("palace_rooms"))
                .containsExactlyInAnyOrder("id", "wing", "room", "hall", "last_updated", "source_book_count");
        assertThat(columnNamesFor("palace_bridge_edges"))
                .containsExactlyInAnyOrder(
                        "id",
                        "room_a_id",
                        "room_b_id",
                        "confidence",
                        "status",
                        "source_book_a",
                        "source_book_b",
                        "created_at",
                        "reviewed_by",
                        "reviewed_at");
        assertThat(columnNamesFor("palace_projection_version"))
                .containsExactlyInAnyOrder(
                        "id",
                        "version_num",
                        "last_ingestion_batch_id",
                        "created_at",
                        "status",
                        "room_count");
        assertThat(columnNamesFor("palace_query_traces"))
                .containsExactlyInAnyOrder(
                        "id",
                        "entry_rooms",
                        "temporal_rule_applied",
                        "candidates_json",
                        "bridge_edges_crossed",
                        "projection_version_used",
                        "queried_at",
                        "installation_id");

        assertThat(indexExists("idx_palace_rooms_wing_room")).isTrue();
        assertThat(indexExists("uq_palace_rooms_wing_room")).isTrue();
        assertThat(indexExists("idx_palace_bridge_edges_status")).isTrue();
        assertThat(indexExists("idx_palace_bridge_edges_room_a_id")).isTrue();
        assertThat(indexExists("idx_palace_bridge_edges_room_b_id")).isTrue();
        assertThat(indexExists("uq_palace_bridge_edges_room_pair")).isTrue();
        assertThat(indexExists("idx_palace_query_traces_queried_at_desc")).isTrue();
        assertThat(indexExists("idx_palace_query_traces_installation_id")).isTrue();
    }

    @Test
    void createsBabyProfilesTableConstraintsAndIndexes() {
        assertThat(columnNamesFor("baby_profiles"))
                .containsExactly(
                        "profile_id",
                        "account_id",
                        "baby_name",
                        "age_range",
                        "parent_goal",
                        "starter_scene_id",
                        "starter_moment_id",
                        "starter_activity_id",
                        "starter_utterance_id",
                        "starter_phrase_id",
                        "starter_source",
                        "onboarding_state",
                        "onboarding_completed_at",
                        "version",
                        "created_at",
                        "updated_at");
        assertThat(constraintExists("uq_baby_profiles_account_id")).isTrue();
        assertThat(indexExists("idx_baby_profiles_updated_at")).isTrue();
        assertThat(indexExists("idx_baby_profiles_state_updated_at")).isTrue();

        assertBabyProfileRejected(
                "profile_bad_age",
                "acct_bad_age",
                "m99",
                null,
                null,
                "draft",
                null,
                1);
        assertBabyProfileRejected(
                "profile_bad_goal",
                "acct_bad_goal",
                "m7_11",
                "sleep_better",
                null,
                "draft",
                null,
                1);
        assertBabyProfileRejected(
                "profile_bad_state",
                "acct_bad_state",
                "m7_11",
                null,
                null,
                "done",
                null,
                1);
        assertBabyProfileRejected(
                "profile_bad_completed",
                "acct_bad_completed",
                "m7_11",
                "calmer_care",
                null,
                "completed",
                Instant.parse("2026-07-03T02:00:00Z"),
                1);
        assertBabyProfileRejected(
                "profile_bad_version",
                "acct_bad_version",
                "m7_11",
                null,
                null,
                "draft",
                null,
                0);
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

    private List<String> columnNamesFor(String tableName) {
        return jdbcTemplate.queryForList(
                """
                select column_name
                from information_schema.columns
                where table_schema = current_schema()
                  and table_name = ?
                order by ordinal_position
                """,
                String.class,
                tableName);
    }

    private boolean indexExists(String indexName) {
        Boolean exists = jdbcTemplate.queryForObject(
                """
                select exists(
                    select 1
                    from pg_indexes
                    where schemaname = current_schema()
                      and indexname = ?
                )
                """,
                Boolean.class,
                indexName);
        return Boolean.TRUE.equals(exists);
    }

    private boolean constraintExists(String constraintName) {
        Boolean exists = jdbcTemplate.queryForObject(
                """
                select exists(
                    select 1
                    from information_schema.table_constraints
                    where table_schema = current_schema()
                      and constraint_name = ?
                )
                """,
                Boolean.class,
                constraintName);
        return Boolean.TRUE.equals(exists);
    }

    private void assertBabyProfileRejected(
            String profileId,
            String accountId,
            String ageRange,
            String parentGoal,
            Starter starter,
            String onboardingState,
            Instant completedAt,
            int version
    ) {
        insertAccount(accountId);
        assertThatThrownBy(() -> insertBabyProfile(
                profileId,
                accountId,
                ageRange,
                parentGoal,
                starter,
                onboardingState,
                completedAt,
                version))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    private void insertAccount(String accountId) {
        jdbcTemplate.update(
                """
                insert into accounts (
                    account_id,
                    phone_number,
                    status,
                    latest_consent_status,
                    created_at,
                    deleted_at
                ) values (?, ?, 'active', 'accepted', ?, null)
                """,
                accountId,
                accountId + "_phone",
                Timestamp.from(Instant.parse("2026-07-03T00:00:00Z")));
    }

    private void insertBabyProfile(
            String profileId,
            String accountId,
            String ageRange,
            String parentGoal,
            Starter starter,
            String onboardingState,
            Instant completedAt,
            int version
    ) {
        var now = Timestamp.from(Instant.parse("2026-07-03T00:00:00Z"));
        jdbcTemplate.update(
                """
                insert into baby_profiles (
                    profile_id,
                    account_id,
                    baby_name,
                    age_range,
                    parent_goal,
                    starter_scene_id,
                    starter_moment_id,
                    starter_activity_id,
                    starter_utterance_id,
                    starter_phrase_id,
                    starter_source,
                    onboarding_state,
                    onboarding_completed_at,
                    version,
                    created_at,
                    updated_at
                ) values (?, ?, null, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                profileId,
                accountId,
                ageRange,
                parentGoal,
                starter == null ? null : starter.sceneId(),
                starter == null ? null : starter.momentId(),
                starter == null ? null : starter.activityId(),
                starter == null ? null : starter.utteranceId(),
                starter == null ? null : starter.phraseId(),
                starter == null ? null : starter.source(),
                onboardingState,
                completedAt == null ? null : Timestamp.from(completedAt),
                version,
                now,
                now);
    }

    private record Starter(
            String sceneId,
            String momentId,
            String activityId,
            String utteranceId,
            String phraseId,
            String source
    ) {
    }
}
