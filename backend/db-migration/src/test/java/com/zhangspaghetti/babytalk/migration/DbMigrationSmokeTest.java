package com.zhangspaghetti.babytalk.migration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.flywaydb.core.Flyway;
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

    private static final String V13_UPGRADE_SCHEMA = "flyway_v13_chat_memory_upgrade";
    private static final String V22_1_REACTION_UPGRADE_SCHEMA = "flyway_v22_1_reaction_upgrade";

    @SuppressWarnings("resource")
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("pgvector/pgvector:pg17")
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
                  and version in ('3', '14', '15', '16', '17', '18', '19', '24', '25', '26')
                """,
                Integer.class);
        assertThat(trackedVersions).isEqualTo(10);

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
        assertThat(tableExists("practice_generated_content")).isTrue();

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
    void upgradesChatMemorySchemaForSpringAi2SequenceOrdering() {
        assertThat(columnNamesFor("spring_ai_chat_memory"))
                .contains("conversation_id", "content", "type", "timestamp", "sequence_id");
        assertThat(columnIsNullable("spring_ai_chat_memory", "sequence_id")).isFalse();
        assertThat(columnDefault("spring_ai_chat_memory", "sequence_id"))
                .containsIgnoringCase("nextval")
                .contains("spring_ai_chat_memory_sequence_id_seq");
        assertThat(indexExists("uq_spring_ai_chat_memory_conversation_sequence")).isTrue();
        assertThat(indexIsUnique("uq_spring_ai_chat_memory_conversation_sequence")).isTrue();
    }

    @Test
    void flywayUpgradeFromV13PreservesChatMemoryRowsAndAddsSpringAi2Contract() {
        Flyway v13 = flywayFor(V13_UPGRADE_SCHEMA, "13");
        v13.migrate();
        assertThat(v13.info().current().getVersion().getVersion()).isEqualTo("13");

        String chatMemoryTable = V13_UPGRADE_SCHEMA + ".spring_ai_chat_memory";
        Timestamp first = Timestamp.from(Instant.parse("2026-07-03T01:00:00Z"));
        Timestamp second = Timestamp.from(Instant.parse("2026-07-03T01:00:00Z"));
        jdbcTemplate.update(
                "INSERT INTO " + chatMemoryTable + " (conversation_id, content, type, \"timestamp\") VALUES (?, ?, ?, ?)",
                "legacy-conversation", "first", "USER", first);
        jdbcTemplate.update(
                "INSERT INTO " + chatMemoryTable + " (conversation_id, content, type, \"timestamp\") VALUES (?, ?, ?, ?)",
                "legacy-conversation", "second", "ASSISTANT", second);
        jdbcTemplate.update(
                "INSERT INTO " + chatMemoryTable + " (conversation_id, content, type, \"timestamp\") VALUES (?, ?, ?, ?)",
                "second-legacy-conversation", "independent", "USER", first);

        Flyway v26 = flywayFor(V13_UPGRADE_SCHEMA, "26");
        v26.migrate();
        assertThat(v26.info().current().getVersion().getVersion()).isEqualTo("26");

        assertThat(jdbcTemplate.queryForList(
                "SELECT content FROM " + chatMemoryTable + " WHERE conversation_id = ? ORDER BY sequence_id",
                String.class,
                "legacy-conversation")).containsExactly("first", "second");
        assertThat(jdbcTemplate.queryForList(
                "SELECT sequence_id FROM " + chatMemoryTable + " WHERE conversation_id = ? ORDER BY sequence_id",
                Long.class,
                "legacy-conversation")).containsExactly(1L, 2L);
        assertThat(jdbcTemplate.queryForObject(
                "SELECT sequence_id FROM " + chatMemoryTable + " WHERE conversation_id = ?",
                Long.class,
                "second-legacy-conversation")).isEqualTo(1L);
        assertThat(columnIsNullable(V13_UPGRADE_SCHEMA, "spring_ai_chat_memory", "sequence_id")).isFalse();
        assertThat(columnDefault(V13_UPGRADE_SCHEMA, "spring_ai_chat_memory", "sequence_id"))
                .containsIgnoringCase("nextval")
                .contains("spring_ai_chat_memory_sequence_id_seq");
        assertThat(indexIsUnique(V13_UPGRADE_SCHEMA, "uq_spring_ai_chat_memory_conversation_sequence")).isTrue();
        jdbcTemplate.update(
                "INSERT INTO " + chatMemoryTable + " (conversation_id, content, type, \"timestamp\") VALUES (?, ?, ?, ?)",
                "legacy-conversation", "database-default", "USER", second);
        assertThat(jdbcTemplate.queryForObject(
                "SELECT sequence_id FROM " + chatMemoryTable + " WHERE conversation_id = ? AND content = ?",
                Long.class,
                "legacy-conversation",
                "database-default")).isGreaterThan(2L);
        assertThatThrownBy(() -> jdbcTemplate.update(
                "INSERT INTO " + chatMemoryTable + " (conversation_id, content, type, \"timestamp\", sequence_id) VALUES (?, ?, ?, ?, ?)",
                "legacy-conversation", "duplicate-sequence", "USER", second, 1L))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void flywayUpgradeFromV22_1PreservesAndRemapsReactionRowsToV23Contract() {
        Flyway v22_1 = flywayFor(V22_1_REACTION_UPGRADE_SCHEMA, "22.1");
        v22_1.migrate();
        assertThat(v22_1.info().current().getVersion().getVersion()).isEqualTo("22.1");

        String accountsTable = V22_1_REACTION_UPGRADE_SCHEMA + ".accounts";
        String sessionsTable = V22_1_REACTION_UPGRADE_SCHEMA + ".account_sessions";
        String eventsTable = V22_1_REACTION_UPGRADE_SCHEMA + ".interaction_events";
        Timestamp now = Timestamp.from(Instant.parse("2026-07-03T04:00:00Z"));
        jdbcTemplate.update(
                "INSERT INTO " + accountsTable
                        + " (account_id, phone_number, status, latest_consent_status, created_at)"
                        + " VALUES (?, ?, 'active', 'accepted', ?)",
                "acct_reaction_upgrade", "phone_reaction_upgrade", now);
        jdbcTemplate.update(
                "INSERT INTO " + sessionsTable
                        + " (session_id, account_id, installation_id, status, created_at)"
                        + " VALUES (?, ?, ?, 'active', ?)",
                "session_reaction_upgrade", "acct_reaction_upgrade", "installation_reaction_upgrade", now);

        List<String> legacyReactions = List.of("calm", "engaged", "imitated", "needs_break");
        for (String reaction : legacyReactions) {
            insertReactionEvent(eventsTable, "legacy_" + reaction, reaction, now);
        }

        Flyway v23 = flywayFor(V22_1_REACTION_UPGRADE_SCHEMA, "23");
        v23.migrate();
        assertThat(v23.info().current().getVersion().getVersion()).isEqualTo("23");

        assertThat(jdbcTemplate.query(
                "SELECT local_event_id, reaction_type FROM " + eventsTable + " ORDER BY local_event_id",
                (resultSet, rowNumber) -> resultSet.getString("local_event_id")
                        + "=" + resultSet.getString("reaction_type")))
                .containsExactly(
                        "legacy_calm=cooperating",
                        "legacy_engaged=cooperating",
                        "legacy_imitated=cooperating",
                        "legacy_needs_break=resisting");

        for (String reaction : legacyReactions) {
            assertThatThrownBy(() -> insertReactionEvent(
                    eventsTable, "rejected_" + reaction, reaction, now))
                    .isInstanceOf(DataIntegrityViolationException.class)
                    .hasMessageContaining("chk_interaction_events_reaction_type");
        }

        List<String> currentReactions = List.of(
                "cooperating", "hesitant", "resisting", "no_response", "other");
        for (String reaction : currentReactions) {
            insertReactionEvent(eventsTable, "current_" + reaction, reaction, now);
        }
        assertThat(jdbcTemplate.queryForList(
                "SELECT reaction_type FROM " + eventsTable
                        + " WHERE local_event_id LIKE 'current_%' ORDER BY local_event_id",
                String.class))
                .containsExactly("cooperating", "hesitant", "no_response", "other", "resisting");
    }

    private void insertReactionEvent(
            String eventsTable,
            String eventId,
            String reactionType,
            Timestamp occurredAt
    ) {
        jdbcTemplate.update(
                "INSERT INTO " + eventsTable + " ("
                        + "event_key, account_id, session_id, installation_id, local_event_id, "
                        + "space_id, activity_id, phrase_id, reaction_type, client_timestamp, received_at"
                        + ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                "event_" + eventId,
                "acct_reaction_upgrade",
                "session_reaction_upgrade",
                "installation_reaction_upgrade",
                eventId,
                "space_reaction_upgrade",
                "activity_reaction_upgrade",
                "phrase_reaction_upgrade",
                reactionType,
                occurredAt,
                occurredAt);
    }

    private Flyway flywayFor(String schema, String target) {
        return Flyway.configure()
                .dataSource(jdbcTemplate.getDataSource())
                .locations("classpath:db/migration")
                .schemas(schema)
                .defaultSchema(schema)
                .createSchemas(true)
                .target(target)
                .load();
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
                dbTime("2026-07-03T02:00:00Z"),
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

    @Test
    void createsPracticeGeneratedContentTableConstraintsAndIndexes() {
        assertThat(columnNamesFor("practice_generated_content"))
                .containsExactly(
                        "generated_content_id",
                        "owner_scope",
                        "owner_key",
                        "owner_key_version",
                        "account_id",
                        "installation_ref_hash",
                        "profile_id",
                        "surface",
                        "mode",
                        "request_fingerprint",
                        "normalized_scene_text",
                        "age_range",
                        "parent_goal",
                        "locale",
                        "space_slug",
                        "activity_slug",
                        "phrase_slug",
                        "space_title_zh",
                        "activity_title_zh",
                        "scene_tag_en",
                        "coach_tip_zh",
                        "english_text",
                        "chinese_text",
                        "pronunciation_hint",
                        "difficulty",
                        "generation_source",
                        "status",
                        "provider_trace_id",
                        "retrieval_trace_id",
                        "model_name",
                        "prompt_version",
                        "strategy_version",
                        "policy_version",
                        "content_version",
                        "generation_error_code",
                        "generation_started_at",
                        "generation_expires_at",
                        "retention_expires_at",
                        "created_at",
                        "updated_at");

        assertThat(columnIsNullable("practice_generated_content", "normalized_scene_text")).isTrue();
        assertThat(columnComment("practice_generated_content", "owner_key_version"))
                .containsIgnoringCase("future migration metadata")
                .containsIgnoringCase("one active key version")
                .doesNotContain("controlled key rotation");

        assertThat(indexExists("uq_practice_generated_content_live_fingerprint")).isTrue();
        assertThat(indexExists("uq_practice_generated_content_active_space_slug")).isTrue();
        assertThat(indexExists("uq_practice_generated_content_active_activity_slug")).isTrue();
        assertThat(indexExists("uq_practice_generated_content_active_phrase_slug")).isTrue();
        assertThat(indexExists("idx_practice_generated_content_owner_created")).isTrue();
        assertThat(indexExists("idx_practice_generated_content_status_updated")).isTrue();
        assertThat(indexExists("idx_practice_generated_content_generated_id_status")).isFalse();
        assertThat(indexExists("idx_practice_generated_content_installation_cleanup")).isTrue();
        assertThat(indexExists("idx_practice_generated_content_stale_draft_cleanup")).isTrue();
        assertThat(indexExists("idx_practice_generated_content_account_cleanup")).isTrue();
        assertThat(indexDefinition("idx_practice_generated_content_installation_cleanup"))
                .containsIgnoringCase("(retention_expires_at, generated_content_id)")
                .doesNotContainIgnoringCase("owner_key_version")
                .containsIgnoringCase("owner_scope")
                .containsIgnoringCase("'installation'")
                .containsIgnoringCase("status")
                .containsIgnoringCase("'active'")
                .containsIgnoringCase("'expired'")
                .containsIgnoringCase("'rejected'");
        assertThat(indexDefinition("idx_practice_generated_content_stale_draft_cleanup"))
                .containsIgnoringCase("(generation_expires_at, generated_content_id)")
                .doesNotContainIgnoringCase("owner_key_version")
                .containsIgnoringCase("status")
                .containsIgnoringCase("'draft'");
        assertThat(constraintExists("uq_baby_profiles_profile_account")).isTrue();
        assertThat(constraintExists("fk_practice_generated_content_profile_owner")).isTrue();
        assertThat(constraintExists("chk_practice_generated_content_draft_shape")).isTrue();
        assertThat(constraintExists("chk_practice_generated_content_installation_retention")).isTrue();
        assertThat(constraintExists("chk_practice_generated_content_installation_not_promoted")).isTrue();
        assertThat(constraintExists("chk_practice_generated_content_success_error_clear")).isTrue();
        assertThat(constraintExists("chk_practice_generated_content_content_version_positive")).isTrue();

        insertGeneratedContent(generatedContentFixture("pgc_db_expired")
                .status("expired")
                .generationSource(null)
                .build());
        insertGeneratedContent(generatedContentFixture("pgc_db_fake")
                .status("active")
                .generationSource("fake")
                .build());

        assertPracticeGeneratedContentRejected(generatedContentFixture("pgc_db_bad_owner_scope")
                .ownerScope("household")
                .build());
        assertPracticeGeneratedContentRejected(generatedContentFixture("pgc_db_bad_surface")
                .surface("growth")
                .build());
        assertPracticeGeneratedContentRejected(generatedContentFixture("pgc_db_bad_mode")
                .mode("catalog_scene")
                .build());
        assertPracticeGeneratedContentRejected(generatedContentFixture("pgc_db_bad_generation_source")
                .generationSource("provider_direct")
                .build());
        assertPracticeGeneratedContentRejected(generatedContentFixture("pgc_db_bad_status")
                .status("queued")
                .build());
        assertPracticeGeneratedContentRejected(generatedContentFixture("pgc_db_dirty_owner")
                .ownerScope("installation")
                .accountId("acct_pgc_dirty")
                .installationRefHash("install_ref_pgc_dirty")
                .build());
        assertPracticeGeneratedContentRejected(generatedContentFixture("pgc_db_missing_profile")
                .ownerScope("profile")
                .accountId("acct_pgc_missing_profile")
                .profileId("profile_pgc_missing")
                .installationRefHash(null)
                .build());
        assertPracticeGeneratedContentRejected(generatedContentFixture("pgc_db_incomplete_active")
                .status("active")
                .withoutActiveResponseFields()
                .build());
        assertPracticeGeneratedContentRejected(generatedContentFixture("pgc_db_installation_promoted")
                .status("promoted")
                .build());
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

    private boolean indexIsUnique(String indexName) {
        Boolean unique = jdbcTemplate.queryForObject(
                """
                select i.indisunique
                from pg_index i
                join pg_class c on c.oid = i.indexrelid
                join pg_namespace n on n.oid = c.relnamespace
                where n.nspname = current_schema()
                  and c.relname = ?
                """,
                Boolean.class,
                indexName);
        return Boolean.TRUE.equals(unique);
    }

    private boolean indexIsUnique(String schemaName, String indexName) {
        Boolean unique = jdbcTemplate.queryForObject(
                """
                select i.indisunique
                from pg_index i
                join pg_class c on c.oid = i.indexrelid
                join pg_namespace n on n.oid = c.relnamespace
                where n.nspname = ?
                  and c.relname = ?
                """,
                Boolean.class,
                schemaName,
                indexName);
        return Boolean.TRUE.equals(unique);
    }

    private String indexDefinition(String indexName) {
        return jdbcTemplate.queryForObject(
                """
                select indexdef
                from pg_indexes
                where schemaname = current_schema()
                  and indexname = ?
                """,
                String.class,
                indexName);
    }

    private boolean columnIsNullable(String tableName, String columnName) {
        return "YES".equals(jdbcTemplate.queryForObject(
                """
                select is_nullable
                from information_schema.columns
                where table_schema = current_schema()
                  and table_name = ?
                  and column_name = ?
                """,
                String.class,
                tableName,
                columnName));
    }

    private boolean columnIsNullable(String schemaName, String tableName, String columnName) {
        return "YES".equals(jdbcTemplate.queryForObject(
                """
                select is_nullable
                from information_schema.columns
                where table_schema = ?
                  and table_name = ?
                  and column_name = ?
                """,
                String.class,
                schemaName,
                tableName,
                columnName));
    }

    private String columnDefault(String tableName, String columnName) {
        return jdbcTemplate.queryForObject(
                """
                select column_default
                from information_schema.columns
                where table_schema = current_schema()
                  and table_name = ?
                  and column_name = ?
                """,
                String.class,
                tableName,
                columnName);
    }

    private String columnDefault(String schemaName, String tableName, String columnName) {
        return jdbcTemplate.queryForObject(
                """
                select column_default
                from information_schema.columns
                where table_schema = ?
                  and table_name = ?
                  and column_name = ?
                """,
                String.class,
                schemaName,
                tableName,
                columnName);
    }

    private String columnComment(String tableName, String columnName) {
        return jdbcTemplate.queryForObject(
                """
                select col_description(format('%I.%I', current_schema(), ?)::regclass, ordinal_position)
                from information_schema.columns
                where table_schema = current_schema()
                  and table_name = ?
                  and column_name = ?
                """,
                String.class,
                tableName,
                tableName,
                columnName);
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
            OffsetDateTime completedAt,
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
                Timestamp.from(dbTime("2026-07-03T00:00:00Z").toInstant()));
    }

    private void insertBabyProfile(
            String profileId,
            String accountId,
            String ageRange,
            String parentGoal,
            Starter starter,
            String onboardingState,
            OffsetDateTime completedAt,
            int version
    ) {
        var now = Timestamp.from(dbTime("2026-07-03T00:00:00Z").toInstant());
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
                completedAt == null ? null : Timestamp.from(completedAt.toInstant()),
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

    private OffsetDateTime dbTime(String instantText) {
        return OffsetDateTime.ofInstant(Instant.parse(instantText), ZoneOffset.UTC);
    }

    private void assertPracticeGeneratedContentRejected(GeneratedContentFixture fixture) {
        assertThatThrownBy(() -> insertGeneratedContent(fixture))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    private void insertGeneratedContent(GeneratedContentFixture fixture) {
        if (fixture.accountId() != null) {
            insertAccount(fixture.accountId());
        }
        var now = Timestamp.from(dbTime("2026-07-03T03:00:00Z").toInstant());
        var retentionExpiresAt = fixture.ownerScope().equals("installation")
                ? Timestamp.from(dbTime("2026-08-02T03:00:00Z").toInstant())
                : null;
        var generationStartedAt = "draft".equals(fixture.status()) ? now : null;
        var generationExpiresAt = "draft".equals(fixture.status())
                ? Timestamp.from(dbTime("2026-07-03T03:05:00Z").toInstant())
                : null;
        jdbcTemplate.update(
                """
                insert into practice_generated_content (
                    generated_content_id,
                    owner_scope,
                    owner_key,
                    owner_key_version,
                    account_id,
                    installation_ref_hash,
                    profile_id,
                    surface,
                    mode,
                    request_fingerprint,
                    normalized_scene_text,
                    age_range,
                    parent_goal,
                    locale,
                    space_slug,
                    activity_slug,
                    phrase_slug,
                    space_title_zh,
                    activity_title_zh,
                    scene_tag_en,
                    coach_tip_zh,
                    english_text,
                    chinese_text,
                    pronunciation_hint,
                    difficulty,
                    generation_source,
                    status,
                    provider_trace_id,
                    retrieval_trace_id,
                    model_name,
                    prompt_version,
                    strategy_version,
                    policy_version,
                    content_version,
                    generation_error_code,
                    generation_started_at,
                    generation_expires_at,
                    retention_expires_at,
                    created_at,
                    updated_at
                ) values (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
                )
                """,
                fixture.generatedContentId(),
                fixture.ownerScope(),
                fixture.ownerKey(),
                "v1",
                fixture.accountId(),
                fixture.installationRefHash(),
                fixture.profileId(),
                fixture.surface(),
                fixture.mode(),
                fixture.requestFingerprint(),
                "draft".equals(fixture.status()) ? "洗澡前宝宝有点紧张" : null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                fixture.spaceSlug(),
                fixture.activitySlug(),
                fixture.phraseSlug(),
                fixture.spaceTitleZh(),
                fixture.activityTitleZh(),
                fixture.sceneTagEn(),
                fixture.coachTipZh(),
                fixture.englishText(),
                fixture.chineseText(),
                fixture.pronunciationHint(),
                fixture.difficulty(),
                fixture.generationSource(),
                fixture.status(),
                null,
                null,
                null,
                "practice-gen-v1",
                "retrieval-v1",
                "policy-v1",
                1,
                null,
                generationStartedAt,
                generationExpiresAt,
                retentionExpiresAt,
                now,
                now);
    }

    private GeneratedContentFixture.Builder generatedContentFixture(String id) {
        return new GeneratedContentFixture.Builder(id);
    }

    private record GeneratedContentFixture(
            String generatedContentId,
            String ownerScope,
            String ownerKey,
            String accountId,
            String installationRefHash,
            String profileId,
            String surface,
            String mode,
            String requestFingerprint,
            String spaceSlug,
            String activitySlug,
            String phraseSlug,
            String spaceTitleZh,
            String activityTitleZh,
            String sceneTagEn,
            String coachTipZh,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String difficulty,
            String generationSource,
            String status
    ) {
        private static class Builder {
            private final String generatedContentId;
            private String ownerScope = "installation";
            private String ownerKey = "hmac_test_owner_key";
            private String accountId;
            private String installationRefHash = "install_ref_pgc_fixture";
            private String profileId;
            private String surface = "onboarding";
            private String mode = "custom_scene";
            private String requestFingerprint;
            private String spaceSlug;
            private String activitySlug;
            private String phraseSlug;
            private String spaceTitleZh;
            private String activityTitleZh;
            private String sceneTagEn;
            private String coachTipZh;
            private String englishText;
            private String chineseText;
            private String pronunciationHint;
            private String difficulty;
            private String generationSource;
            private String status = "draft";
            private boolean fillActiveResponseFields = true;

            Builder(String generatedContentId) {
                this.generatedContentId = generatedContentId;
                this.requestFingerprint = "fp_" + generatedContentId;
            }

            Builder ownerScope(String ownerScope) {
                this.ownerScope = ownerScope;
                return this;
            }

            Builder accountId(String accountId) {
                this.accountId = accountId;
                return this;
            }

            Builder profileId(String profileId) {
                this.profileId = profileId;
                return this;
            }

            Builder installationRefHash(String installationRefHash) {
                this.installationRefHash = installationRefHash;
                return this;
            }

            Builder surface(String surface) {
                this.surface = surface;
                return this;
            }

            Builder mode(String mode) {
                this.mode = mode;
                return this;
            }

            Builder generationSource(String generationSource) {
                this.generationSource = generationSource;
                return this;
            }

            Builder status(String status) {
                this.status = status;
                return this;
            }

            Builder spaceSlug(String spaceSlug) {
                this.spaceSlug = spaceSlug;
                return this;
            }

            Builder withoutActiveResponseFields() {
                this.fillActiveResponseFields = false;
                return this;
            }

            GeneratedContentFixture build() {
                if (fillActiveResponseFields && ("active".equals(status) || "promoted".equals(status))) {
                    spaceSlug = spaceSlug == null ? "space_" + generatedContentId : spaceSlug;
                    activitySlug = activitySlug == null ? "activity_" + generatedContentId : activitySlug;
                    phraseSlug = phraseSlug == null ? "phrase_" + generatedContentId : phraseSlug;
                    spaceTitleZh = "日常照护";
                    activityTitleZh = "洗澡时间";
                    sceneTagEn = "Bath time";
                    coachTipZh = "慢一点重复说。";
                    englishText = "Warm water.";
                    chineseText = "水暖暖的。";
                    pronunciationHint = "warm water";
                    difficulty = "starter";
                    generationSource = generationSource == null ? "agentic_search" : generationSource;
                }
                return new GeneratedContentFixture(
                        generatedContentId,
                        ownerScope,
                        ownerKey,
                        accountId,
                        installationRefHash,
                        profileId,
                        surface,
                        mode,
                        requestFingerprint,
                        spaceSlug,
                        activitySlug,
                        phraseSlug,
                        spaceTitleZh,
                        activityTitleZh,
                        sceneTagEn,
                        coachTipZh,
                        englishText,
                        chineseText,
                        pronunciationHint,
                        difficulty,
                        generationSource,
                        status);
            }
        }
    }
}
