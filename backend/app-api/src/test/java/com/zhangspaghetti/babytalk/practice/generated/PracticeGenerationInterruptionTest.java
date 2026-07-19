package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class PracticeGenerationInterruptionTest extends AbstractIntegrationTest {

    private static final OffsetDateTime NOW = OffsetDateTime.of(
            2026, 7, 19, 10, 0, 0, 0, ZoneOffset.UTC);
    private static final String HASH = "a".repeat(64);
    private static final String CONTENT_ID = "pgc_interruption_started";

    @Autowired
    private PracticeGeneratedContentCommands commands;

    @Autowired
    private PracticeGeneratedContentService service;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    @AfterEach
    void clean() {
        jdbcTemplate.update("delete from practice_generated_content where generated_content_id like 'pgc_interruption_%'");
    }

    @Test
    void staleGenerationInterruptsAllStartedAuditsThenExpiresParentAndClearsInput() {
        var draft = reserveGeneratingContent();
        var attemptId = UUID.randomUUID();
        var operationId = UUID.randomUUID();
        var providerCallId = UUID.randomUUID();
        insertStartedAttempt(attemptId, draft.generatedContentId());
        insertStartedOperation(operationId, draft.generatedContentId());
        insertStartedProviderCall(providerCallId, operationId);

        assertThat(service.expireStaleDrafts(NOW, 10)).isEqualTo(1);

        assertThat(jdbcTemplate.queryForMap("""
                select status, outcome
                from practice_generated_content_attempts where attempt_id = ?
                """, attemptId))
                .containsEntry("status", "interrupted")
                .containsEntry("outcome", "interrupted");
        assertThat(completedAt("practice_generated_content_attempts", "attempt_id", attemptId)).isEqualTo(NOW);
        assertThat(jdbcTemplate.queryForMap("""
                select status, outcome
                from practice_ai_operation_runs where operation_run_id = ?
                """, operationId))
                .containsEntry("status", "interrupted")
                .containsEntry("outcome", "interrupted");
        assertThat(completedAt("practice_ai_operation_runs", "operation_run_id", operationId)).isEqualTo(NOW);
        assertThat(jdbcTemplate.queryForMap("""
                select outcome
                from practice_ai_provider_calls where provider_call_id = ?
                """, providerCallId))
                .containsEntry("outcome", "interrupted");
        assertThat(completedAt("practice_ai_provider_calls", "provider_call_id", providerCallId)).isEqualTo(NOW);
        assertThat(jdbcTemplate.queryForMap("""
                select status, generation_error_code, generation_error_retryable, normalized_scene_text
                from practice_generated_content where generated_content_id = ?
                """, CONTENT_ID))
                .containsEntry("status", "expired")
                .containsEntry("generation_error_code", "generation_interrupted")
                .containsEntry("generation_error_retryable", true)
                .containsEntry("normalized_scene_text", null);
    }

    @Test
    void staleParentLimitInterruptsEveryStartedProviderCallAcrossItsOperationRuns() {
        var draft = reserveGeneratingContent();
        var firstOperationId = UUID.randomUUID();
        var secondOperationId = UUID.randomUUID();
        var firstProviderCallId = UUID.randomUUID();
        var secondProviderCallId = UUID.randomUUID();
        insertStartedAttempt(UUID.randomUUID(), draft.generatedContentId());
        insertStartedOperation(firstOperationId, draft.generatedContentId());
        insertStartedOperation(secondOperationId, draft.generatedContentId());
        insertStartedProviderCall(firstProviderCallId, firstOperationId);
        insertStartedProviderCall(secondProviderCallId, secondOperationId);

        assertThat(service.expireStaleDrafts(NOW, 1)).isEqualTo(1);

        assertProviderCallInterrupted(firstProviderCallId);
        assertProviderCallInterrupted(secondProviderCallId);
    }

    @Test
    void staleCleanupUsesOneCandidateSetForMixedDraftAndGeneratingParents() {
        var staleDraft = reserveDraft(
                "pgc_interruption_mixed_draft", "fp_interruption_mixed_draft", NOW.minusMinutes(2));
        var staleGenerating = reserveGeneratingContent(
                "pgc_interruption_mixed_generating", "fp_interruption_mixed_generating", NOW.minusMinutes(1));
        var staleDraftAttemptId = UUID.randomUUID();
        var staleDraftOperationId = UUID.randomUUID();
        var staleDraftProviderCallId = UUID.randomUUID();
        var staleGeneratingAttemptId = UUID.randomUUID();
        var staleGeneratingOperationId = UUID.randomUUID();
        var staleGeneratingProviderCallId = UUID.randomUUID();
        insertStartedAttempt(staleDraftAttemptId, staleDraft.generatedContentId());
        insertStartedOperation(staleDraftOperationId, staleDraft.generatedContentId());
        insertStartedProviderCall(staleDraftProviderCallId, staleDraftOperationId);
        insertStartedAttempt(staleGeneratingAttemptId, staleGenerating.generatedContentId());
        insertStartedOperation(staleGeneratingOperationId, staleGenerating.generatedContentId());
        insertStartedProviderCall(staleGeneratingProviderCallId, staleGeneratingOperationId);

        assertThat(service.expireStaleDrafts(NOW, 1)).isEqualTo(1);

        assertThat(jdbcTemplate.queryForObject("""
                select status from practice_generated_content where generated_content_id = ?
                """, String.class, staleDraft.generatedContentId())).isEqualTo("expired");
        assertThat(jdbcTemplate.queryForObject("""
                select status from practice_generated_content where generated_content_id = ?
                """, String.class, staleGenerating.generatedContentId())).isEqualTo("generating");
        assertAuditInterrupted(staleDraftAttemptId, staleDraftOperationId, staleDraftProviderCallId);
        assertAuditStillStarted(staleGeneratingAttemptId, staleGeneratingOperationId, staleGeneratingProviderCallId);
    }

    @Test
    void rejectedAndExpiredTerminalsCreateNewDraftsWithoutRevivingHistoricalRows() {
        var rejected = reserveDraft("pgc_interruption_rejected", "fp_interruption_rejected", NOW.plusMinutes(5));
        commands.reject(rejected.generatedContentId(), "generation_invalid_output", false, NOW, NOW.plusDays(7));
        var rejectedReplacement = commands.reserveDraft(
                draft("pgc_interruption_rejected_replacement", "fp_interruption_rejected", NOW.plusMinutes(5)),
                reservationPolicy());

        var expired = reserveDraft("pgc_interruption_expired", "fp_interruption_expired", NOW.plusMinutes(5));
        commands.expire(expired.generatedContentId(), "generation_timeout", true, NOW, NOW.plusDays(7));
        var expiredReplacement = commands.reserveDraft(
                draft("pgc_interruption_expired_replacement", "fp_interruption_expired", NOW.plusMinutes(5)),
                reservationPolicy());

        assertThat(rejectedReplacement.created()).isTrue();
        assertThat(rejectedReplacement.content().generatedContentId()).isEqualTo("pgc_interruption_rejected_replacement");
        assertThat(expiredReplacement.created()).isTrue();
        assertThat(expiredReplacement.content().generatedContentId()).isEqualTo("pgc_interruption_expired_replacement");
        assertThat(jdbcTemplate.queryForMap("""
                select status, generation_error_code from practice_generated_content
                where generated_content_id = 'pgc_interruption_rejected'
                """))
                .containsEntry("status", "rejected")
                .containsEntry("generation_error_code", "generation_invalid_output");
        assertThat(jdbcTemplate.queryForMap("""
                select status, generation_error_code from practice_generated_content
                where generated_content_id = 'pgc_interruption_expired'
                """))
                .containsEntry("status", "expired")
                .containsEntry("generation_error_code", "generation_timeout");
    }

    private OffsetDateTime completedAt(String table, String idColumn, UUID id) {
        return jdbcTemplate.queryForObject(
                "select completed_at from " + table + " where " + idColumn + " = ?",
                OffsetDateTime.class,
                id);
    }

    private void assertProviderCallInterrupted(UUID providerCallId) {
        assertThat(jdbcTemplate.queryForMap("""
                select outcome from practice_ai_provider_calls where provider_call_id = ?
                """, providerCallId))
                .containsEntry("outcome", "interrupted");
        assertThat(completedAt("practice_ai_provider_calls", "provider_call_id", providerCallId)).isEqualTo(NOW);
    }

    private void assertAuditInterrupted(UUID attemptId, UUID operationId, UUID providerCallId) {
        assertThat(jdbcTemplate.queryForObject("""
                select status from practice_generated_content_attempts where attempt_id = ?
                """, String.class, attemptId)).isEqualTo("interrupted");
        assertThat(jdbcTemplate.queryForObject("""
                select status from practice_ai_operation_runs where operation_run_id = ?
                """, String.class, operationId)).isEqualTo("interrupted");
        assertProviderCallInterrupted(providerCallId);
    }

    private void assertAuditStillStarted(UUID attemptId, UUID operationId, UUID providerCallId) {
        assertThat(jdbcTemplate.queryForObject("""
                select status from practice_generated_content_attempts where attempt_id = ?
                """, String.class, attemptId)).isEqualTo("started");
        assertThat(jdbcTemplate.queryForObject("""
                select status from practice_ai_operation_runs where operation_run_id = ?
                """, String.class, operationId)).isEqualTo("started");
        assertThat(jdbcTemplate.queryForObject("""
                select outcome from practice_ai_provider_calls where provider_call_id = ?
                """, String.class, providerCallId)).isEqualTo("started");
        assertThat(completedAt("practice_ai_provider_calls", "provider_call_id", providerCallId)).isNull();
    }

    private PracticeGeneratedContentEntity reserveGeneratingContent() {
        return reserveGeneratingContent(CONTENT_ID, "fp_interruption", NOW.minusMinutes(1));
    }

    private PracticeGeneratedContentEntity reserveGeneratingContent(String id, String fingerprint, OffsetDateTime expiresAt) {
        var draft = draft(id, fingerprint, expiresAt);
        var reserved = commands.reserveDraft(
                draft,
                new ReservationPolicy(NOW.minusMinutes(10), NOW.minusMinutes(20), 10, NOW.plusDays(7)));
        assertThat(commands.startGeneration(id, NOW.minusDays(1), 10, NOW.minusMinutes(10)))
                .isEqualTo(GenerationStartDecision.STARTED);
        return reserved.content();
    }

    private PracticeGeneratedContentEntity reserveDraft(String id, String fingerprint, OffsetDateTime expiresAt) {
        return commands.reserveDraft(draft(id, fingerprint, expiresAt), reservationPolicy()).content();
    }

    private PracticeGeneratedContentEntity draft(String id, String fingerprint, OffsetDateTime expiresAt) {
        var draft = new PracticeGeneratedContentEntity();
        draft.setGeneratedContentId(id);
        draft.setOwnerScope("installation");
        draft.setOwnerKey("owner_interruption_" + fingerprint);
        draft.setOwnerKeyVersion("v1");
        draft.setInstallationRefHash("installation_interruption");
        draft.setSurface("onboarding");
        draft.setMode("custom_scene");
        draft.setRequestFingerprint(fingerprint);
        draft.setNormalizedSceneText("宝宝不肯穿鞋");
        draft.setAgeRange("m7_11");
        draft.setParentGoal("calmer_care");
        draft.setLocale("zh-CN");
        draft.setStatus("draft");
        draft.setGenerationProfileVersion("profile-v1");
        draft.setGenerationProfileHash(HASH);
        draft.setRubricVersion("rubric-v1");
        draft.setRubricContentHash(HASH);
        draft.setEvidencePolicyVersion("evidence-v1");
        draft.setEvidencePolicyContentHash(HASH);
        draft.setProviderRoutingPolicyVersion("routing-v1");
        draft.setProviderRoutingPolicyHash(HASH);
        draft.setGenerationAttemptLimit(3);
        draft.setContentRefreshEpoch(1);
        draft.setContentVersion(1);
        draft.setGenerationExpiresAt(expiresAt);
        draft.setCreatedAt(NOW.minusMinutes(10));
        draft.setUpdatedAt(NOW.minusMinutes(10));
        return draft;
    }

    private ReservationPolicy reservationPolicy() {
        return new ReservationPolicy(NOW, NOW.minusMinutes(20), 10, NOW.plusDays(7));
    }

    private void insertStartedAttempt(UUID attemptId, String generatedContentId) {
        jdbcTemplate.update("""
                insert into practice_generated_content_attempts (
                    attempt_id, generated_content_id, attempt_number, attempt_type, status, outcome,
                    violation_codes, started_at, completed_at
                ) values (?, ?, 1, 'generator', 'started', null, '{}', ?, null)
                """, attemptId, generatedContentId, NOW.minusMinutes(10));
    }

    private void insertStartedOperation(UUID operationId, String generatedContentId) {
        jdbcTemplate.update("""
                insert into practice_ai_operation_runs (
                    operation_run_id, operation_type, subject_type, subject_id, generated_content_id,
                    attempt_number, evidence_bundle_id, capability_name, prompt_version, prompt_content_hash,
                    policy_version, policy_content_hash, status, outcome, started_at, completed_at
                ) values (?, 'generator', 'generated_content', ?, ?, 1, null, 'generation', 'profile-v1', ?,
                    null, null, 'started', null, ?, null)
                """, operationId, generatedContentId, generatedContentId, HASH, NOW.minusMinutes(10));
    }

    private void insertStartedProviderCall(UUID providerCallId, UUID operationId) {
        jdbcTemplate.update("""
                insert into practice_ai_provider_calls (
                    provider_call_id, operation_run_id, provider_name, provider_type, model_name,
                    fallback_index, attempt_trace_id, provider_trace_id, routing_policy_version,
                    routing_policy_hash, outcome, latency_ms, started_at, completed_at
                ) values (?, ?, 'fake', 'fake', 'fake-model', 0, ?, null, 'routing-v1', ?,
                    'started', null, ?, null)
                """, providerCallId, operationId, UUID.randomUUID(), HASH, NOW.minusMinutes(10));
    }
}
