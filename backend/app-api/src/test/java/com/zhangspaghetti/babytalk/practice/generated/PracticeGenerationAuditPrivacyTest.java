package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class PracticeGenerationAuditPrivacyTest extends AbstractIntegrationTest {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void auditSchemaStoresOnlyOperationalMetadataAndPublicPracticeFields() {
        var persistedAuditTables = jdbcTemplate.queryForList(
                """
                select table_name
                from information_schema.tables
                where table_schema = current_schema()
                  and table_name in (
                    'practice_generated_content',
                    'practice_generated_content_attempts',
                    'practice_generated_content_evidence_bundles',
                    'practice_generated_content_evidence_items',
                    'practice_ai_operation_runs',
                    'practice_ai_provider_calls',
                    'practice_generated_content_judge_results'
                  )
                """,
                String.class
        );
        var forbidden = jdbcTemplate.queryForList(
                """
                select column_name
                from information_schema.columns
                where table_schema = current_schema()
                  and table_name in (?, ?, ?, ?, ?, ?, ?)
                  and column_name in (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                order by table_name, column_name
                """,
                String.class,
                "practice_generated_content",
                "practice_generated_content_attempts",
                "practice_generated_content_evidence_bundles",
                "practice_generated_content_evidence_items",
                "practice_ai_operation_runs",
                "practice_ai_provider_calls",
                "practice_generated_content_judge_results",
                "security_text",
                "risk_signals",
                "raw_scene",
                "raw_prompt",
                "prompt_body",
                "raw_response",
                "response_body",
                "raw_error",
                "raw_chunk",
                "chain_of_thought",
                "coach_tip_zh"
        );

        var generatedContentColumns = jdbcTemplate.queryForList(
                """
                select column_name
                from information_schema.columns
                where table_schema = current_schema()
                  and table_name = 'practice_generated_content'
                """,
                String.class
        );

        assertThat(persistedAuditTables).containsExactlyInAnyOrder(
                "practice_generated_content",
                "practice_generated_content_attempts",
                "practice_generated_content_evidence_bundles",
                "practice_generated_content_evidence_items",
                "practice_ai_operation_runs",
                "practice_ai_provider_calls",
                "practice_generated_content_judge_results"
        );
        assertThat(forbidden).isEmpty();
        assertThat(generatedContentColumns).contains(
                "space_slug",
                "activity_slug",
                "phrase_slug",
                "age_range",
                "parent_goal",
                "status",
                "generation_expires_at"
        );
    }
}
