package com.zhangspaghetti.babytalk.account;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class AccountDataPurgeIntegrationTest extends AbstractIntegrationTest {

    private static final Instant CREATED_AT = Instant.parse("2026-08-20T00:00:00Z");
    private static final OffsetDateTime DELETED_AT = OffsetDateTime.parse("2026-08-20T01:00:00Z");

    @Autowired
    private AccountDataPurgeService purgeService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void purgeRemovesAccountOwnedRowsTransfersHouseholdAndPreservesOtherAccount() {
        seedAccount("acct_deleted", "v1:deleted-phone", "deleted-phone", "active", "accepted");
        seedAccount("acct_other", "v1:other-phone", "other-phone", "active", "accepted");
        seedSession("sess_deleted", "acct_deleted", "install-deleted");
        seedSession("sess_other", "acct_other", "install-other");
        seedRefreshToken("crt_deleted", "acct_deleted", "sess_deleted", "active");
        seedRefreshToken("crt_other", "acct_other", "sess_other", "active");
        seedSmsChallenge("acct_deleted");
        seedInteractionEvent("deleted-event", "acct_deleted", "sess_deleted");
        seedInteractionEvent("other-event", "acct_other", "sess_other");
        seedMentorRows("acct_deleted", "sess_deleted", "turn-deleted", "audit-deleted");
        seedMentorRows("acct_other", "sess_other", "turn-other", "audit-other");
        seedGardenRows("acct_deleted");
        seedGardenRows("acct_other");
        seedBabyProfile("profile-deleted", "acct_deleted");
        seedBabyProfile("profile-other", "acct_other");
        seedGeneratedContent("generated-deleted", "acct_deleted", "delete");
        seedGeneratedContent("generated-other", "acct_other", "other");
        seedConsentAudit("acct_deleted", "sess_deleted", "delete-before-purge");
        seedHouseholdWithOtherMember();

        var result = purgeService.purge("acct_deleted", DELETED_AT);

        assertThat(result.applied()).isTrue();
        assertThat(result.deletedInteractionEventCount()).isEqualTo(1);
        assertThat(result.deletedMentorTurnCount()).isEqualTo(1);
        assertThat(result.deletedMentorAuditLogCount()).isEqualTo(1);
        assertThat(result.revokedRefreshTokenCount()).isEqualTo(1);
        assertThat(result.deletedSessionCount()).isEqualTo(1);
        assertThat(result.deletedGeneratedContentCount()).isEqualTo(1);
        assertThat(result.deletedBabyProfileCount()).isEqualTo(1);

        assertThat(count("select count(*) from interaction_events where account_id = 'acct_deleted'"))
                .isZero();
        assertThat(count("select count(*) from mentor_turns where turn_id = 'turn-deleted'"))
                .isZero();
        assertThat(count("select count(*) from mentor_audit_logs where correlation_id = 'corr-audit-deleted'"))
                .isZero();
        assertThat(count("select count(*) from garden_fertilizer_state where user_id = 'acct_deleted'"))
                .isZero();
        assertThat(count("select count(*) from garden_fertilizer_claim_log where user_id = 'acct_deleted'"))
                .isZero();
        assertThat(count("select count(*) from garden_fertilizer_apply_log where user_id = 'acct_deleted'"))
                .isZero();
        assertThat(count("select count(*) from baby_profiles where account_id = 'acct_deleted'"))
                .isZero();
        assertThat(count("select count(*) from practice_generated_content where account_id = 'acct_deleted'"))
                .isZero();
        assertThat(count("select count(*) from sms_challenges where phone_lookup_ref = 'v1:deleted-phone'"))
                .isZero();
        assertThat(jdbcTemplate.queryForObject(
                "select status from account_refresh_tokens where refresh_token_id = 'crt_deleted'",
                String.class
        )).isEqualTo("revoked");
        assertThat(jdbcTemplate.queryForObject(
                "select status from account_refresh_tokens where refresh_token_id = 'crt_other'",
                String.class
        )).isEqualTo("active");

        assertThat(jdbcTemplate.queryForObject(
                "select status from accounts where account_id = 'acct_deleted'",
                String.class
        )).isEqualTo("deleted");
        assertThat(count("select count(*) from consent_audit_logs where account_id = 'acct_deleted'"))
                .isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select installation_id from account_sessions where session_id = 'sess_deleted'",
                String.class
        )).isEqualTo("redacted");
        assertThat(jdbcTemplate.queryForObject(
                "select installation_id from consent_audit_logs where account_id = 'acct_deleted'",
                String.class
        )).isEqualTo("redacted");

        assertThat(jdbcTemplate.queryForObject(
                "select owner_account_id from households where household_id = 'household-shared'",
                String.class
        )).isEqualTo("acct_other");
        assertThat(count("select count(*) from household_members where account_id = 'acct_deleted'"))
                .isZero();
        assertThat(count("select count(*) from household_members where account_id = 'acct_other'"))
                .isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select role from household_members where account_id = 'acct_other'",
                String.class
        )).isEqualTo("primary_caregiver");
        assertThat(count("select count(*) from household_shared_context where household_id = 'household-shared'"))
                .isZero();
        assertThat(count("select count(*) from caregiver_invites where inviter_account_id = 'acct_deleted'"))
                .isZero();
        assertThat(jdbcTemplate.queryForObject(
                "select actor_account_id from caregiver_invite_events where household_id = 'household-shared'",
                String.class
        )).isNull();
        assertThat(jdbcTemplate.queryForObject(
                "select token from caregiver_invite_events where household_id = 'household-shared'",
                String.class
        )).isNull();

        assertThat(count("select count(*) from interaction_events where account_id = 'acct_other'"))
                .isEqualTo(1);
        assertThat(count("select count(*) from mentor_turns where turn_id = 'turn-other'"))
                .isEqualTo(1);
        assertThat(count("select count(*) from garden_fertilizer_state where user_id = 'acct_other'"))
                .isEqualTo(1);
        assertThat(count("select count(*) from baby_profiles where account_id = 'acct_other'"))
                .isEqualTo(1);
        assertThat(count("select count(*) from practice_generated_content where account_id = 'acct_other'"))
                .isEqualTo(1);

        var duplicate = purgeService.purge("acct_deleted", DELETED_AT.plusSeconds(1));
        assertThat(duplicate.applied()).isFalse();
        jdbcTemplate.update(
                "update account_sessions set installation_id = 'legacy-deleted-session' where session_id = 'sess_deleted'"
        );
        jdbcTemplate.update(
                "update consent_audit_logs set installation_id = 'legacy-deleted-audit' where account_id = 'acct_deleted'"
        );
        var duplicateAfterLegacyRows = purgeService.purge("acct_deleted", DELETED_AT.plusSeconds(2));
        assertThat(duplicateAfterLegacyRows.applied()).isFalse();
        assertThat(jdbcTemplate.queryForObject(
                "select installation_id from account_sessions where session_id = 'sess_deleted'",
                String.class
        )).isEqualTo("redacted");
        assertThat(jdbcTemplate.queryForObject(
                "select installation_id from consent_audit_logs where account_id = 'acct_deleted'",
                String.class
        )).isEqualTo("redacted");
        assertThat(count("select count(*) from account_refresh_tokens where account_id = 'acct_other' and status = 'active'"))
                .isEqualTo(1);
    }

    @Test
    void purgeDestroysHouseholdWhenDeletedOwnerHasNoOtherActiveMember() {
        seedAccount("acct_alone", "v1:alone-phone", "alone-phone", "active", "accepted");
        seedSession("sess_alone", "acct_alone", "install-alone");
        jdbcTemplate.update(
                "insert into households (household_id, owner_account_id, status, created_at) values (?, ?, 'active', ?)",
                "household-alone", "acct_alone", timestamp(CREATED_AT)
        );
        jdbcTemplate.update(
                "insert into household_members (household_id, account_id, role, status, joined_at) values (?, ?, 'primary_caregiver', 'active', ?)",
                "household-alone", "acct_alone", timestamp(CREATED_AT)
        );
        jdbcTemplate.update(
                "insert into household_shared_context (household_id, baby_profile_summary, continuity_summary, garden_summary, space_id, activity_id, latest_interaction_at, updated_at) values (?, 'private', 'private', 'private', 'daily_care', 'bath_time', ?, ?)",
                "household-alone", timestamp(CREATED_AT), timestamp(CREATED_AT)
        );
        jdbcTemplate.update(
                "insert into caregiver_invite_events (token, household_id, actor_account_id, entrypoint, result, created_at) values (?, ?, ?, 'create', 'create', ?)",
                "alone-token", "household-alone", "acct_alone", timestamp(CREATED_AT)
        );

        var result = purgeService.purge("acct_alone", DELETED_AT);

        assertThat(result.applied()).isTrue();
        assertThat(count("select count(*) from households where household_id = 'household-alone'"))
                .isZero();
        assertThat(count("select count(*) from household_members where household_id = 'household-alone'"))
                .isZero();
        assertThat(count("select count(*) from household_shared_context where household_id = 'household-alone'"))
                .isZero();
        assertThat(count("select count(*) from caregiver_invite_events where household_id = 'household-alone'"))
                .isZero();
    }

    @Test
    void purgePreservesSharedContextWhenDeletedAccountIsOnlyCaregiver() {
        seedAccount("acct_caregiver_deleted", "v1:caregiver-phone", "caregiver-phone", "active", "accepted");
        seedAccount("acct_household_owner", "v1:owner-phone", "owner-phone", "active", "accepted");
        seedSession("sess_caregiver_deleted", "acct_caregiver_deleted", "install-caregiver");
        jdbcTemplate.update(
                "insert into households (household_id, owner_account_id, status, created_at) values (?, ?, 'active', ?)",
                "household-caregiver",
                "acct_household_owner",
                timestamp(CREATED_AT)
        );
        jdbcTemplate.update(
                "insert into household_members (household_id, account_id, role, status, joined_at) values (?, ?, 'primary_caregiver', 'active', ?)",
                "household-caregiver",
                "acct_household_owner",
                timestamp(CREATED_AT)
        );
        jdbcTemplate.update(
                "insert into household_members (household_id, account_id, role, status, joined_at) values (?, ?, 'caregiver', 'active', ?)",
                "household-caregiver",
                "acct_caregiver_deleted",
                timestamp(CREATED_AT)
        );
        jdbcTemplate.update(
                "insert into household_shared_context (household_id, baby_profile_summary, continuity_summary, garden_summary, space_id, activity_id, latest_interaction_at, updated_at) values (?, 'shared', 'shared', 'shared', 'daily_care', 'bath_time', ?, ?)",
                "household-caregiver",
                timestamp(CREATED_AT),
                timestamp(CREATED_AT)
        );

        var result = purgeService.purge("acct_caregiver_deleted", DELETED_AT);

        assertThat(result.applied()).isTrue();
        assertThat(jdbcTemplate.queryForObject(
                "select owner_account_id from households where household_id = ?",
                String.class,
                "household-caregiver"
        )).isEqualTo("acct_household_owner");
        assertThat(count("select count(*) from household_members where account_id = 'acct_caregiver_deleted'"))
                .isZero();
        assertThat(count("select count(*) from household_shared_context where household_id = 'household-caregiver'"))
                .isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select baby_profile_summary from household_shared_context where household_id = ?",
                String.class,
                "household-caregiver"
        )).isEqualTo("shared");
    }

    private void seedAccount(
            String accountId,
            String phoneLookupRef,
            String phoneMask,
            String status,
            String consentStatus
    ) {
        jdbcTemplate.update(
                "insert into accounts (account_id, phone_lookup_ref, phone_mask, status, latest_consent_status, created_at) values (?, ?, ?, ?, ?, ?)",
                accountId,
                phoneLookupRef,
                phoneMask,
                status,
                consentStatus,
                timestamp(CREATED_AT)
        );
    }

    private void seedSession(String sessionId, String accountId, String installationId) {
        jdbcTemplate.update(
                "insert into account_sessions (session_id, account_id, installation_id, status, created_at) values (?, ?, ?, 'active', ?)",
                sessionId,
                accountId,
                installationId,
                timestamp(CREATED_AT)
        );
    }

    private void seedRefreshToken(String tokenId, String accountId, String sessionId, String status) {
        jdbcTemplate.update(
                "insert into account_refresh_tokens (refresh_token_id, account_id, session_id, status, issued_at, expires_at, updated_at) values (?, ?, ?, ?, ?, ?, ?)",
                tokenId,
                accountId,
                sessionId,
                status,
                timestamp(CREATED_AT),
                timestamp(CREATED_AT.plusSeconds(86400)),
                timestamp(CREATED_AT)
        );
    }

    private void seedSmsChallenge(String accountId) {
        jdbcTemplate.update(
                "insert into sms_challenges (challenge_id, phone_lookup_ref, phone_mask, verification_verifier, status, issued_at, expires_at, verification_attempts) values (?, ?, 'deleted-phone', 'verifier', 'pending', ?, ?, 0)",
                "challenge-deleted",
                "v1:deleted-phone",
                timestamp(CREATED_AT),
                timestamp(CREATED_AT.plusSeconds(300))
        );
    }

    private void seedInteractionEvent(String eventKey, String accountId, String sessionId) {
        jdbcTemplate.update(
                "insert into interaction_events (event_key, account_id, session_id, installation_id, local_event_id, space_id, activity_id, phrase_id, reaction_type, client_timestamp, received_at) values (?, ?, ?, ?, ?, 'daily_care', 'bath_time', 'bath_time_warm_water', 'cooperating', ?, ?)",
                eventKey,
                accountId,
                sessionId,
                "install-" + accountId,
                eventKey,
                timestamp(CREATED_AT),
                timestamp(CREATED_AT)
        );
    }

    private void seedMentorRows(String accountId, String sessionId, String turnId, String auditId) {
        jdbcTemplate.update(
                "insert into mentor_turns (turn_id, correlation_id, installation_id, session_id_hint, account_id_hint, surface, mode, result, phase, request_summary, response_summary, response_text, provider_mode, blocked_fallback, retryable, created_at) values (?, ?, ?, ?, ?, 'care_path', 'guided', 'success', 'complete', 'private request', 'private response', 'private response text', 'fake', false, false, ?)",
                turnId,
                "corr-" + turnId,
                "install-" + accountId,
                sessionId,
                accountId,
                timestamp(CREATED_AT)
        );
        jdbcTemplate.update(
                "insert into mentor_audit_logs (correlation_id, installation_id, session_id_hint, account_id_hint, event_type, phase, result, request_summary, response_summary, reason, failure_code, retryable, rate_limited, created_at) values (?, ?, ?, ?, 'chat', 'complete', 'success', 'private request', 'private response', null, null, false, false, ?)",
                "corr-" + auditId,
                "install-" + accountId,
                sessionId,
                accountId,
                timestamp(CREATED_AT)
        );
    }

    private void seedGardenRows(String accountId) {
        jdbcTemplate.update(
                "insert into garden_fertilizer_state (user_id, applied_count, version, updated_at) values (?, 1, 1, ?)",
                accountId,
                timestamp(CREATED_AT)
        );
        jdbcTemplate.update(
                "insert into garden_fertilizer_claim_log (user_id, event_key, request_id, claimed_at) values (?, ?, ?, ?)",
                accountId,
                "event-" + accountId,
                "request-" + accountId,
                timestamp(CREATED_AT)
        );
        jdbcTemplate.update(
                "insert into garden_fertilizer_apply_log (user_id, request_id, delta, applied_at) values (?, ?, 1, ?)",
                accountId,
                "apply-" + accountId,
                timestamp(CREATED_AT)
        );
    }

    private void seedBabyProfile(String profileId, String accountId) {
        jdbcTemplate.update(
                "insert into baby_profiles (profile_id, account_id, age_range, onboarding_state, version, created_at, updated_at) values (?, ?, 'm0_3', 'draft', 1, ?, ?)",
                profileId,
                accountId,
                timestamp(CREATED_AT),
                timestamp(CREATED_AT)
        );
    }

    private void seedGeneratedContent(String contentId, String accountId, String slugSuffix) {
        jdbcTemplate.update(
                """
                insert into practice_generated_content (
                    generated_content_id, owner_scope, owner_key, owner_key_version, account_id, surface, mode,
                    request_fingerprint, age_range, parent_goal, locale, space_slug, activity_slug, phrase_slug,
                    space_title_zh, activity_title_zh, scene_tag_en, tpr_action_zh, delivery_guidance_zh,
                    english_text, chinese_text, pronunciation_hint,
                    difficulty, generation_source, status, generation_profile_version, generation_profile_hash,
                    rubric_version, rubric_content_hash, evidence_policy_version, evidence_policy_content_hash,
                    provider_routing_policy_version, provider_routing_policy_hash, generation_attempt_limit,
                    content_version, content_refresh_epoch, created_at, updated_at
                ) values (
                    ?, 'account', ?, 'v1', ?, 'onboarding', 'custom_scene', ?, 'm0_3', 'natural_opening', 'zh-CN',
                    ?, ?, ?, '日常照护', '洗澡', 'bath', '指向温水', '慢慢示范',
                    'Warm water', '温水', 'warm water', 'easy', 'fake', 'active',
                    'profile-v1', repeat('0', 64), 'rubric-v1', repeat('0', 64), 'evidence-v1', repeat('0', 64),
                    'routing-v1', repeat('0', 64), 1, 1, 1, ?, ?
                )
                """,
                contentId,
                "owner-" + slugSuffix,
                accountId,
                "fingerprint-" + slugSuffix,
                "space-" + slugSuffix,
                "activity-" + slugSuffix,
                "phrase-" + slugSuffix,
                timestamp(CREATED_AT),
                timestamp(CREATED_AT)
        );
    }

    private void seedConsentAudit(String accountId, String sessionId, String reason) {
        jdbcTemplate.update(
                "insert into consent_audit_logs (account_id, session_id, installation_id, action, result, reason, created_at) values (?, ?, 'install-deleted', 'accept', 'applied', ?, ?)",
                accountId,
                sessionId,
                reason,
                timestamp(CREATED_AT)
        );
    }

    private void seedHouseholdWithOtherMember() {
        jdbcTemplate.update(
                "insert into households (household_id, owner_account_id, status, created_at) values ('household-shared', 'acct_deleted', 'active', ?)",
                timestamp(CREATED_AT)
        );
        jdbcTemplate.update(
                "insert into household_members (household_id, account_id, role, status, joined_at) values ('household-shared', 'acct_deleted', 'primary_caregiver', 'active', ?)",
                timestamp(CREATED_AT)
        );
        jdbcTemplate.update(
                "insert into household_members (household_id, account_id, role, status, invited_by_account_id, joined_at) values ('household-shared', 'acct_other', 'caregiver', 'active', 'acct_deleted', ?)",
                timestamp(CREATED_AT)
        );
        jdbcTemplate.update(
                "insert into caregiver_invites (token, household_id, inviter_account_id, target_role, source, status, created_at, expires_at) values ('invite-deleted', 'household-shared', 'acct_deleted', 'caregiver', 'share', 'pending', ?, ?)",
                timestamp(CREATED_AT),
                timestamp(CREATED_AT.plusSeconds(3600))
        );
        jdbcTemplate.update(
                "insert into caregiver_invite_events (token, household_id, actor_account_id, entrypoint, result, created_at) values ('invite-deleted', 'household-shared', 'acct_deleted', 'create', 'create', ?)",
                timestamp(CREATED_AT)
        );
        jdbcTemplate.update(
                "insert into household_shared_context (household_id, baby_profile_summary, continuity_summary, garden_summary, space_id, activity_id, latest_interaction_at, updated_at) values ('household-shared', 'private', 'private', 'private', 'daily_care', 'bath_time', ?, ?)",
                timestamp(CREATED_AT),
                timestamp(CREATED_AT)
        );
    }

    private int count(String sql) {
        return jdbcTemplate.queryForObject(sql, Integer.class);
    }

    private Timestamp timestamp(Instant instant) {
        return Timestamp.from(instant);
    }
}
