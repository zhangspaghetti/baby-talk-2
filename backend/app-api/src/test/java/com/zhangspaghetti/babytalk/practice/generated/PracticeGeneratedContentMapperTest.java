package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatNoException;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGeneratedContentValidator;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryCustomSceneProperties;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyTestFixture;
import com.zhangspaghetti.babytalk.practice.generated.internal.PracticeGenerationAuditTestAccess;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeAiOperationRunEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeAiProviderCallEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeEvidenceBundleEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGenerationAttemptEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeJudgeResultEntity;
import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.BeanPropertySqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

class PracticeGeneratedContentMapperTest extends AbstractIntegrationTest {

    private static final Instant NOW = Instant.parse("2026-07-03T04:00:00Z");
    private static final OffsetDateTime NOW_DB = OffsetDateTime.ofInstant(NOW, ZoneOffset.UTC);

    @Autowired
    private PracticeGeneratedContentService repository;

    @Autowired
    private PracticeGeneratedContentQueryMapper queries;

    @Autowired
    private PracticeGeneratedContentCommands commands;

    @Autowired
    private PracticeGenerationAuditTestAccess audit;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private static final String HASH = "a".repeat(64);

    @BeforeEach
    void cleanGeneratedContentFixturesBeforeTest() {
        cleanGeneratedContentFixtures();
    }

    @AfterEach
    void cleanGeneratedContentFixturesAfterTest() {
        cleanGeneratedContentFixtures();
    }

    @Test
    void constraintsRejectUnsupportedEnumsAndAllowExpiredStatus() {
        insert(row("pgc_repo_expired").expired().build());

        assertRejected(row("pgc_repo_bad_owner_scope").ownerScope("household").build());
        assertRejected(row("pgc_repo_bad_surface").surface("growth").build());
        assertRejected(row("pgc_repo_bad_mode").mode("catalog_scene").build());
        assertRejected(row("pgc_repo_bad_generation_source")
                .active()
                .generationSource("provider_direct")
                .build());
        assertRejected(row("pgc_repo_bad_status").status("queued").build());
    }

    @Test
    void stateMachineConstraintsRejectInvalidDraftRetentionErrorAndVersionShapes() {
        assertRejected(row("pgc_repo_bad_draft_input")
                .normalizedSceneText(null)
                .generationWindow(NOW_DB, NOW_DB.plusMinutes(5))
                .build());
        assertRejected(row("pgc_repo_bad_draft_start")
                .status("generating")
                .generationWindow(null, NOW_DB.plusMinutes(5))
                .build());
        assertRejected(row("pgc_repo_bad_draft_expiry")
                .generationWindow(NOW_DB, null)
                .build());
        assertRejected(row("pgc_repo_bad_installation_active_retention")
                .active()
                .withoutAutomaticRetention()
                .build());
        assertRejected(row("pgc_repo_bad_installation_promoted")
                .status("promoted")
                .build());
        assertRejected(row("pgc_repo_bad_active_error")
                .active()
                .generationErrorCode("should_not_exist")
                .build());
        assertRejected(row("pgc_repo_bad_content_version")
                .contentVersion(0)
                .generationWindow(NOW_DB, NOW_DB.plusMinutes(5))
                .build());
    }

    @Test
    void dirtyOwnerShapesAreRejected() {
        assertRejected(row("pgc_repo_dirty_installation")
                .ownerScope("installation")
                .installationId("install_pgc_repo_dirty")
                .accountId("acct_pgc_repo_dirty_installation")
                .build());
        assertRejected(row("pgc_repo_dirty_account")
                .account("acct_pgc_repo_dirty_account")
                .installationId("install_pgc_repo_dirty")
                .build());
        assertRejected(row("pgc_repo_dirty_profile")
                .profile("acct_pgc_repo_dirty_profile", "profile_pgc_repo_dirty")
                .installationId("install_pgc_repo_dirty")
                .build());
        assertRejected(row("pgc_repo_dirty_global")
                .globalCandidate()
                .installationId("install_pgc_repo_dirty")
                .build());
    }

    @Test
    void accountAndProfileOwnerShapesPersistWhenReferencesAreValid() {
        insert(row("pgc_repo_valid_account")
                .account("acct_pgc_repo_valid_account")
                .build());
        insert(row("pgc_repo_valid_profile")
                .profile("acct_pgc_repo_valid_profile", "profile_pgc_repo_valid_profile")
                .build());

        Integer count = jdbcTemplate.queryForObject(
                """
                select count(*)
                from practice_generated_content
                where generated_content_id in ('pgc_repo_valid_account', 'pgc_repo_valid_profile')
                """,
                Integer.class);
        assertThat(count).isEqualTo(2);
    }

    @Test
    void profileOwnerShapeRequiresExistingMatchingProfile() {
        var row = row("pgc_repo_missing_profile")
                .profile("acct_pgc_repo_missing_profile", "profile_pgc_repo_missing_profile")
                .build();
        insertAccount(row.accountId());

        assertThatThrownBy(() -> insertRaw(row))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void activeAndPromotedRowsRequireGeneratedResponseFields() {
        assertRejected(row("pgc_repo_incomplete_active")
                .active()
                .withoutResponseFields()
                .build());
        assertRejected(row("pgc_repo_incomplete_promoted")
                .promoted()
                .withoutResponseFields()
                .build());
    }

    @Test
    void carePathActivationFailsClosedWithoutExactApprovedSixUtteranceBundle() {
        var missing = generatingCarePathRow("pgc_repo_care_path_missing");
        insert(missing);

        assertThatThrownBy(() -> transaction().executeWithoutResult(status -> jdbcTemplate.update(
                """
                update practice_generated_content
                set status = 'active', normalized_scene_text = null
                where generated_content_id = ?
                """,
                missing.generatedContentId())))
                .isInstanceOf(RuntimeException.class);

        var complete = generatingCarePathRow("pgc_repo_care_path_complete");
        complete.setOwnerScope("account");
        complete.setAccountId("acct_pgc_repo_care_path_complete");
        complete.setInstallationRefHash(null);
        insert(complete);
        transaction().executeWithoutResult(status -> {
            insertCarePathStarter(complete.generatedContentId(), complete.phraseSlug());
            insertCarePathSupport(complete.generatedContentId(), "cooperating", 2);
            insertCarePathSupport(complete.generatedContentId(), "hesitant", 3);
            insertCarePathSupport(complete.generatedContentId(), "resisting", 4);
            insertCarePathSupport(complete.generatedContentId(), "no_response", 5);
            insertCarePathSupport(complete.generatedContentId(), "other", 6);
            jdbcTemplate.update(
                    """
                    update practice_generated_content
                    set status = 'active', normalized_scene_text = null
                    where generated_content_id = ?
                    """,
                    complete.generatedContentId());
        });

        assertThat(queries.findApprovedUtterances(complete.generatedContentId()))
                .extracting(value -> value.utteranceId())
                .containsExactly(
                        complete.phraseSlug(),
                        "utt_cooperating_" + complete.generatedContentId(),
                        "utt_hesitant_" + complete.generatedContentId(),
                        "utt_resisting_" + complete.generatedContentId(),
                        "utt_no_response_" + complete.generatedContentId(),
                        "utt_other_" + complete.generatedContentId());
        assertThat(queries.findActiveOwnedByAccountId(
                complete.generatedContentId(), complete.accountId())).isNotNull();
        assertThat(queries.findActiveOwnedByAccountId(
                complete.generatedContentId(), "acct_pgc_repo_other")).isNull();
        assertThat(queries.findPlayableApprovedUtterance(
                complete.generatedContentId(), complete.phraseSlug()))
                .extracting(value -> value.englishText())
                .isEqualTo("Warm water.");
        assertThat(queries.findPlayableApprovedUtterance(
                complete.generatedContentId(), "utt_missing")).isNull();

        assertThatThrownBy(() -> transaction().executeWithoutResult(status ->
                insertCarePathSupport(complete.generatedContentId(), "other", 6)))
                .isInstanceOf(RuntimeException.class);
    }

    @Test
    void nullableOwnerIdsAreStillUniqueByNonNullOwnerKey() {
        insert(row("pgc_repo_global_draft_1")
                .ownerKey("hmac_test_repo_global_live")
                .requestFingerprint("fp_repo_nullable_owner")
                .build());

        assertRejected(row("pgc_repo_global_draft_2")
                .ownerKey("hmac_test_repo_global_live")
                .requestFingerprint("fp_repo_nullable_owner")
                .build());
    }

    @Test
    void promotedBlocksDuplicateActiveForSameLiveFingerprint() {
        insert(row("pgc_repo_promoted_live")
                .promoted()
                .ownerKey("hmac_test_repo_promoted_blocks")
                .requestFingerprint("fp_repo_promoted_blocks")
                .build());

        assertRejected(row("pgc_repo_active_live_conflict")
                .active()
                .ownerKey("hmac_test_repo_promoted_blocks")
                .requestFingerprint("fp_repo_promoted_blocks")
                .build());
    }

    @Test
    void differentOwnerKeysMayReuseSameFingerprint() {
        insert(row("pgc_repo_owner_a")
                .ownerKey("hmac_test_repo_owner_a")
                .requestFingerprint("fp_repo_shared")
                .build());
        insert(row("pgc_repo_owner_b")
                .ownerKey("hmac_test_repo_owner_b")
                .requestFingerprint("fp_repo_shared")
                .build());

        Integer count = jdbcTemplate.queryForObject(
                """
                select count(*)
                from practice_generated_content
                where request_fingerprint = 'fp_repo_shared'
                """,
                Integer.class);
        assertThat(count).isEqualTo(2);
    }

    @Test
    void clientRequestIdIsUniquePerOwnerAcrossTerminalRowsAndFindableForReconciliation() {
        var ownerKey = "hmac_test_repo_request_owner";
        var clientRequestId = "request_reconcile_001";
        var terminal = row("pgc_repo_request_terminal")
                .expired()
                .ownerKey(ownerKey)
                .requestFingerprint("fp_repo_request_terminal")
                .clientRequestId(clientRequestId)
                .build();
        insert(terminal);

        assertThat(queries.findByClientRequestId("installation", ownerKey, "v1", clientRequestId))
                .extracting(PracticeGeneratedContentEntity::generatedContentId)
                .isEqualTo(terminal.generatedContentId());
        assertRejected(row("pgc_repo_request_duplicate")
                .ownerKey(ownerKey)
                .requestFingerprint("fp_repo_request_conflict")
                .clientRequestId(clientRequestId)
                .build());

        insert(row("pgc_repo_request_other_owner")
                .ownerKey("hmac_test_repo_request_other_owner")
                .requestFingerprint("fp_repo_request_other_owner")
                .clientRequestId(clientRequestId)
                .build());
    }

    @Test
    void expiredAndRejectedRowsDoNotBlockRetry() {
        insert(row("pgc_repo_retry_expired")
                .expired()
                .ownerKey("hmac_test_repo_retry")
                .requestFingerprint("fp_repo_retry")
                .build());
        insert(row("pgc_repo_retry_rejected")
                .rejected()
                .ownerKey("hmac_test_repo_retry")
                .requestFingerprint("fp_repo_retry")
                .build());
        insert(row("pgc_repo_retry_draft")
                .ownerKey("hmac_test_repo_retry")
                .requestFingerprint("fp_repo_retry")
                .build());

        Integer count = jdbcTemplate.queryForObject(
                """
                select count(*)
                from practice_generated_content
                where owner_key = 'hmac_test_repo_retry'
                  and request_fingerprint = 'fp_repo_retry'
                """,
                Integer.class);
        assertThat(count).isEqualTo(3);
    }

    @Test
    void activeAndPromotedSlugsMustBeIndividuallyUnique() {
        insert(row("pgc_repo_slug_active")
                .active()
                .slugs("space_repo_slug", "activity_repo_slug", "phrase_repo_slug")
                .build());

        assertRejected(row("pgc_repo_slug_promoted_space")
                .promoted()
                .ownerKey("hmac_test_repo_slug_space")
                .requestFingerprint("fp_repo_slug_space")
                .slugs("space_repo_slug", "activity_repo_slug_2", "phrase_repo_slug_2")
                .build());
        assertRejected(row("pgc_repo_slug_promoted_activity")
                .promoted()
                .ownerKey("hmac_test_repo_slug_activity")
                .requestFingerprint("fp_repo_slug_activity")
                .slugs("space_repo_slug_2", "activity_repo_slug", "phrase_repo_slug_3")
                .build());
        assertRejected(row("pgc_repo_slug_promoted_phrase")
                .promoted()
                .ownerKey("hmac_test_repo_slug_phrase")
                .requestFingerprint("fp_repo_slug_phrase")
                .slugs("space_repo_slug_3", "activity_repo_slug_3", "phrase_repo_slug")
                .build());
    }

    @Test
    void findsActiveOrPromotedRowsByGeneratedContentId() {
        insert(row("pgc_repo_lookup_draft").build());
        insert(row("pgc_repo_lookup_active").active().build());
        insert(row("pgc_repo_lookup_promoted").promoted().build());

        var active = repository.findActiveOrPromotedByGeneratedContentId("pgc_repo_lookup_active");
        var promoted = repository.findActiveOrPromotedByGeneratedContentId("pgc_repo_lookup_promoted");

        assertThat(active).isPresent();
        assertThat(active.get().generatedContentId()).isEqualTo("pgc_repo_lookup_active");
        assertThat(promoted).isPresent();
        assertThat(promoted.get().generatedContentId()).isEqualTo("pgc_repo_lookup_promoted");
        assertThat(repository.findActiveOrPromotedByGeneratedContentId("pgc_repo_lookup_draft"))
                .isEmpty();
    }

    @Test
    void findsActiveOrPromotedRowsByOwnerFingerprintAndVersions() {
        var active = row("pgc_repo_lookup_fingerprint")
                .active()
                .ownerKey("hmac_test_repo_lookup_fingerprint")
                .requestFingerprint("fp_repo_lookup_fingerprint")
                .build();
        insert(active);

        var found = repository.findActiveOrPromotedByFingerprint(
                active.ownerKey(),
                active.surface(),
                active.mode(),
                active.requestFingerprint(),
                active.generationProfileVersion(),
                active.evidencePolicyVersion());

        assertThat(found).isPresent();
        assertThat(found.get().generatedContentId()).isEqualTo(active.generatedContentId());

        var promoted = row("pgc_repo_lookup_promoted_fingerprint")
                .promoted()
                .ownerKey("hmac_test_repo_lookup_promoted_fingerprint")
                .requestFingerprint("fp_repo_lookup_promoted_fingerprint")
                .build();
        insert(promoted);

        var promotedFound = repository.findActiveOrPromotedByFingerprint(
                promoted.ownerKey(),
                promoted.surface(),
                promoted.mode(),
                promoted.requestFingerprint(),
                promoted.generationProfileVersion(),
                promoted.evidencePolicyVersion());

        assertThat(promotedFound).isPresent();
        assertThat(promotedFound.get().generatedContentId()).isEqualTo(promoted.generatedContentId());
    }

    @Test
    void draftReservationConflictReturnsExistingRow() {
        var first = row("pgc_repo_reserve_first")
                .ownerKey("hmac_test_repo_reserve")
                .requestFingerprint("fp_repo_reserve")
                .generationWindow(NOW_DB, OffsetDateTime.now(ZoneOffset.UTC).plusHours(1))
                .build();
        var second = row("pgc_repo_reserve_second")
                .ownerKey("hmac_test_repo_reserve")
                .requestFingerprint("fp_repo_reserve")
                .generationWindow(NOW_DB, OffsetDateTime.now(ZoneOffset.UTC).plusHours(1))
                .build();

        var reserved = repository.reserveDraft(first);
        var conflict = repository.reserveDraft(second);

        assertThat(reserved.inserted()).isTrue();
        assertThat(conflict.inserted()).isFalse();
        assertThat(reserved.row().generatedContentId()).isEqualTo("pgc_repo_reserve_first");
        assertThat(conflict.row().generatedContentId()).isEqualTo("pgc_repo_reserve_first");
        Integer count = jdbcTemplate.queryForObject(
                """
                select count(*)
                from practice_generated_content
                where owner_key = 'hmac_test_repo_reserve'
                  and request_fingerprint = 'fp_repo_reserve'
                """,
                Integer.class);
        assertThat(count).isEqualTo(1);
    }

    @Test
    void draftReservationFailsClosedWhenConflictLeavesNoVisibleLiveRow() {
        var row = row("pgc_repo_reserve_retry").build();
        var queryMapper = org.mockito.Mockito.mock(PracticeGeneratedContentQueryMapper.class);
        var commandPort = org.mockito.Mockito.mock(PracticeGeneratedContentCommands.class);
        var retryingRepository = new PracticeGeneratedContentService(
                queryMapper,
                commandPort,
                org.mockito.Mockito.mock(CustomSceneGenerator.class),
                validator(),
                PracticeDiscoveryCustomSceneProperties.enabledForTest("fake"),
                PracticeDiscoveryPolicyTestFixture.properties(),
                Clock.fixed(NOW, ZoneOffset.UTC),
                new PracticeGeneratedContentOwnerProperties(
                        "v1", "test-owner-key-secret-test-owner-key"));
        org.mockito.Mockito.when(commandPort.reserveDraft(
                        org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
                .thenThrow(new IllegalStateException(
                        "practice generated content reservation conflict could not be loaded"));

        assertThatThrownBy(() -> retryingRepository.reserveDraft(row))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("practice generated content reservation conflict could not be loaded");
        org.mockito.Mockito.verify(commandPort).reserveDraft(
                org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());
    }

    @Test
    void inactivePrimaryKeyConflictSignalsCallerToRetryWithNewGeneratedContentId() {
        var inactive = row("pgc_repo_inactive_retry")
                .rejected()
                .ownerKey("hmac_test_repo_inactive_retry")
                .requestFingerprint("fp_repo_inactive_retry")
                .build();
        insert(inactive);
        var retry = row("pgc_repo_inactive_retry")
                .ownerKey("hmac_test_repo_inactive_retry")
                .requestFingerprint("fp_repo_inactive_retry")
                .build();

        assertThatThrownBy(() -> repository.reserveDraft(retry))
                .isInstanceOf(GeneratedContentIdConflictException.class);
    }

    @Test
    void cleanupQueryAndDeleteCoverDueInstallationTerminalRows() {
        insert(row("pgc_repo_cleanup_expired")
                .expired()
                .installationId("install_pgc_repo_cleanup")
                .retentionExpiresAt(NOW_DB.minusSeconds(3600))
                .build());
        insert(row("pgc_repo_cleanup_rejected")
                .rejected()
                .installationId("install_pgc_repo_cleanup")
                .retentionExpiresAt(NOW_DB.minusSeconds(1800))
                .build());
        insert(row("pgc_repo_cleanup_active")
                .active()
                .installationId("install_pgc_repo_cleanup")
                .retentionExpiresAt(NOW_DB.minusSeconds(1200))
                .build());
        insert(row("pgc_repo_cleanup_future")
                .active()
                .installationId("install_pgc_repo_cleanup")
                .retentionExpiresAt(NOW_DB.plusSeconds(1200))
                .build());
        insert(row("pgc_repo_cleanup_other_install")
                .expired()
                .installationId("install_pgc_repo_other")
                .retentionExpiresAt(NOW_DB.minusSeconds(3600))
                .build());

        var candidates = repository.findInstallationCleanupCandidates(
                "install_pgc_repo_cleanup",
                NOW_DB,
                10);

        assertThat(candidates)
                .extracting(PracticeGeneratedContentEntity::generatedContentId)
                .containsExactly(
                        "pgc_repo_cleanup_expired",
                        "pgc_repo_cleanup_rejected",
                        "pgc_repo_cleanup_active");

        assertThat(repository.deleteExpiredInstallationRows(NOW_DB, 10)).isEqualTo(4);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where generated_content_id = 'pgc_repo_cleanup_future'",
                Integer.class)).isEqualTo(1);
    }

    @Test
    void terminalTransitionsClearNormalizedInputAndApplyInstallationRetention() {
        insert(row("pgc_repo_transition_active").build());
        insert(row("pgc_repo_transition_rejected").build());
        insert(row("pgc_repo_transition_expired").build());

        var active = row("pgc_repo_transition_active")
                .active()
                .retentionExpiresAt(NOW_DB.plusDays(30))
                .build();
        assertThat(commands.startGeneration(
                "pgc_repo_transition_active", NOW_DB.minusDays(1), 100, NOW_DB))
                .isEqualTo(GenerationStartDecision.STARTED);
        assertThat(repository.activateDraft(active)).isPresent();
        repository.rejectDraft("pgc_repo_transition_rejected", "unsafe", NOW_DB);
        repository.expireDraft("pgc_repo_transition_expired", "timeout", NOW_DB);

        assertTerminalPrivacyAndRetention("pgc_repo_transition_active", NOW_DB.plusDays(30));
        assertTerminalPrivacyAndRetention("pgc_repo_transition_rejected", NOW_DB.plusDays(7));
        assertTerminalPrivacyAndRetention("pgc_repo_transition_expired", NOW_DB.plusDays(7));
    }

    @Test
    void countsRecentGenerationAttemptsByOwnerSurfaceModeAndWindow() {
        var ownerKey = "hmac_test_repo_rate_count";
        insert(row("pgc_repo_count_draft")
                .ownerKey(ownerKey)
                .requestFingerprint("fp_repo_count_draft")
                .createdAt(NOW_DB.minusSeconds(60))
                .build());
        insert(row("pgc_repo_count_rejected")
                .rejected()
                .ownerKey(ownerKey)
                .requestFingerprint("fp_repo_count_rejected")
                .createdAt(NOW_DB.minusSeconds(120))
                .build());
        insert(row("pgc_repo_count_expired")
                .expired()
                .ownerKey(ownerKey)
                .requestFingerprint("fp_repo_count_expired")
                .createdAt(NOW_DB.minusSeconds(180))
                .build());
        insert(row("pgc_repo_count_active")
                .active()
                .ownerKey(ownerKey)
                .requestFingerprint("fp_repo_count_active")
                .createdAt(NOW_DB.minusSeconds(240))
                .build());
        insert(row("pgc_repo_count_promoted")
                .promoted()
                .ownerKey(ownerKey)
                .requestFingerprint("fp_repo_count_promoted")
                .createdAt(NOW_DB.minusSeconds(300))
                .build());
        insert(row("pgc_repo_count_old")
                .ownerKey(ownerKey)
                .requestFingerprint("fp_repo_count_old")
                .createdAt(NOW_DB.minusSeconds(7200))
                .build());
        insert(row("pgc_repo_count_other_surface")
                .ownerKey(ownerKey)
                .surface("scene_search")
                .requestFingerprint("fp_repo_count_other_surface")
                .createdAt(NOW_DB.minusSeconds(60))
                .build());

        var count = repository.countRecentGenerationAttempts(
                ownerKey,
                "onboarding",
                "custom_scene",
                NOW_DB.minusSeconds(600));

        assertThat(count).isEqualTo(5);
    }

    @Test
    void accountDeletionCleanupDeletesAccountAndProfileRowsButKeepsInstallationRows() {
        var accountId = "acct_pgc_repo_delete";
        insert(row("pgc_repo_delete_account").account(accountId).build());
        insert(row("pgc_repo_delete_profile")
                .profile(accountId, "profile_pgc_repo_delete")
                .build());
        insert(row("pgc_repo_delete_installation")
                .installationId("install_pgc_repo_delete")
                .build());

        var deleted = repository.deleteAccountOwned(accountId);

        assertThat(deleted).isEqualTo(2);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where account_id = ?",
                Integer.class,
                accountId)).isZero();
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where generated_content_id = ?",
                Integer.class,
                "pgc_repo_delete_installation")).isEqualTo(1);
    }

    @Test
    void staleDraftBatchCleanupClearsPrivateInputAndAppliesInstallationRetention() {
        insert(row("pgc_repo_stale_installation")
                .generationWindow(NOW_DB.minusMinutes(10), NOW_DB.minusMinutes(5))
                .build());
        insert(row("pgc_repo_stale_account")
                .account("acct_pgc_repo_stale")
                .generationWindow(NOW_DB.minusMinutes(10), NOW_DB.minusMinutes(1))
                .build());
        insert(row("pgc_repo_fresh_draft")
                .generationWindow(NOW_DB.minusMinutes(1), NOW_DB.plusMinutes(4))
                .build());
        insert(row("pgc_repo_v2_stale_draft")
                .ownerKeyVersion("v2")
                .generationWindow(NOW_DB.minusMinutes(10), NOW_DB.minusMinutes(1))
                .build());

        assertThat(repository.expireStaleDrafts(NOW_DB, 10)).isEqualTo(3);

        assertThat(jdbcTemplate.queryForObject(
                "select status from practice_generated_content where generated_content_id = 'pgc_repo_stale_installation'",
                String.class)).isEqualTo("expired");
        assertThat(jdbcTemplate.queryForObject(
                "select normalized_scene_text from practice_generated_content where generated_content_id = 'pgc_repo_stale_installation'",
                String.class)).isNull();
        assertThat(jdbcTemplate.queryForObject(
                "select retention_expires_at from practice_generated_content where generated_content_id = 'pgc_repo_stale_installation'",
                OffsetDateTime.class)).isEqualTo(NOW_DB.plusDays(7));
        assertThat(jdbcTemplate.queryForObject(
                "select normalized_scene_text from practice_generated_content where generated_content_id = 'pgc_repo_stale_account'",
                String.class)).isNull();
        assertThat(jdbcTemplate.queryForObject(
                "select retention_expires_at from practice_generated_content where generated_content_id = 'pgc_repo_stale_account'",
                OffsetDateTime.class)).isNull();
        assertThat(jdbcTemplate.queryForObject(
                "select status from practice_generated_content where generated_content_id = 'pgc_repo_fresh_draft'",
                String.class)).isEqualTo("draft");
        assertExpiredAndInputCleared("pgc_repo_v2_stale_draft");
    }

    @Test
    void staleDraftCleanupClearsInputAcrossHistoricalOwnerKeyVersions() {
        insert(row("pgc_repo_stale_draft_v1")
                .ownerKeyVersion("v1")
                .generationWindow(NOW_DB.minusMinutes(10), NOW_DB.minusMinutes(1))
                .normalizedSceneText("宝宝不肯穿鞋")
                .build());
        insert(row("pgc_repo_stale_draft_v2")
                .ownerKeyVersion("v2")
                .generationWindow(NOW_DB.minusMinutes(10), NOW_DB.minusMinutes(1))
                .normalizedSceneText("宝宝不肯洗手")
                .build());

        assertThat(repository.expireStaleDrafts(NOW_DB, 100)).isEqualTo(2);

        assertExpiredAndInputCleared("pgc_repo_stale_draft_v1");
        assertExpiredAndInputCleared("pgc_repo_stale_draft_v2");
    }

    @Test
    void expiredInstallationCleanupDeletesRowsAcrossHistoricalOwnerKeyVersions() {
        insert(row("pgc_repo_expired_installation_v1")
                .expired()
                .ownerKeyVersion("v1")
                .retentionExpiresAt(NOW_DB.minusDays(1))
                .build());
        insert(row("pgc_repo_expired_installation_v2")
                .expired()
                .ownerKeyVersion("v2")
                .retentionExpiresAt(NOW_DB.minusDays(1))
                .build());

        assertThat(repository.deleteExpiredInstallationRows(NOW_DB, 100)).isEqualTo(2);

        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where generated_content_id in (?, ?)",
                Integer.class,
                "pgc_repo_expired_installation_v1",
                "pgc_repo_expired_installation_v2"))
                .isZero();
    }

    @Test
    void expiredInstallationActiveIsNotReusableByIdOrFingerprint() {
        var ownerKey = "hmac_test_repo_expired_active";
        insert(row("pgc_repo_expired_active")
                .active()
                .ownerKey(ownerKey)
                .requestFingerprint("fp_repo_expired_active")
                .retentionExpiresAt(OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(1))
                .build());

        assertThat(repository.findActiveOrPromotedByGeneratedContentId("pgc_repo_expired_active")).isEmpty();
        assertThat(repository.findActiveOrPromotedByFingerprint(
                ownerKey,
                "onboarding",
                "custom_scene",
                "fp_repo_expired_active",
                "practice-gen-v1",
                "retrieval-v1")).isEmpty();
    }

    @Test
    void reservationDeletesDueInstallationActiveAfterBurstCheckAndCreatesCurrentEpochDraft() {
        var ownerKey = "hmac_test_repo_lazy_active";
        var fingerprint = "fp_repo_lazy_active";
        insert(row("pgc_repo_lazy_active_old")
                .active()
                .ownerKey(ownerKey)
                .requestFingerprint(fingerprint)
                .createdAt(NOW_DB.minusHours(1))
                .retentionExpiresAt(NOW_DB.minusMinutes(1))
                .build());
        var draft = row("pgc_repo_lazy_active_new")
                .ownerKey(ownerKey)
                .requestFingerprint(fingerprint)
                .generationWindow(NOW_DB, NOW_DB.plusMinutes(5))
                .build();

        var reservation = commands.reserveDraft(
                draft,
                new ReservationPolicy(
                        NOW_DB,
                        NOW_DB.minusMinutes(10),
                        3,
                        NOW_DB.plusDays(7)));

        assertThat(reservation.inserted()).isTrue();
        assertThat(reservation.row().generatedContentId()).isEqualTo("pgc_repo_lazy_active_new");
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where generated_content_id = 'pgc_repo_lazy_active_old'",
                Integer.class)).isZero();
        assertThat(reservation.row().contentRefreshEpoch()).isEqualTo(1);
        assertThat(reservation.row().requestFingerprint()).isEqualTo(fingerprint);
    }

    @Test
    void dueInstallationActiveIsNotDeletedWhenBurstLimitRejectsReservation() {
        var ownerKey = "hmac_test_repo_due_active_limit";
        var fingerprint = "fp_repo_due_active_limit";
        insert(row("pgc_repo_due_active_limit_old")
                .active()
                .ownerKey(ownerKey)
                .requestFingerprint(fingerprint)
                .createdAt(NOW_DB.minusMinutes(1))
                .retentionExpiresAt(NOW_DB.minusMinutes(1))
                .build());
        var draft = row("pgc_repo_due_active_limit_new")
                .ownerKey(ownerKey)
                .requestFingerprint(fingerprint)
                .generationWindow(NOW_DB, NOW_DB.plusMinutes(5))
                .build();

        assertThatThrownBy(() -> commands.reserveDraft(
                draft,
                new ReservationPolicy(NOW_DB, NOW_DB.minusMinutes(10), 1, NOW_DB.plusDays(7))))
                .isInstanceOf(PracticeGenerationRateLimitExceededException.class);

        assertThat(jdbcTemplate.queryForMap("""
                select generated_content_id, status
                from practice_generated_content
                where owner_key = ?
                """, ownerKey))
                .containsEntry("generated_content_id", "pgc_repo_due_active_limit_old")
                .containsEntry("status", "active");
    }

    @Test
    void dueInstallationActiveSameIdRequiresSuffixRetryBeforeDeletion() {
        var ownerKey = "hmac_test_repo_due_same_id";
        var fingerprint = "fp_repo_due_same_id";
        insert(row("pgc_repo_due_same_id")
                .active()
                .ownerKey(ownerKey)
                .requestFingerprint(fingerprint)
                .createdAt(NOW_DB.minusHours(1))
                .retentionExpiresAt(NOW_DB.minusMinutes(1))
                .build());
        var sameIdDraft = row("pgc_repo_due_same_id")
                .ownerKey(ownerKey)
                .requestFingerprint(fingerprint)
                .generationWindow(NOW_DB, NOW_DB.plusMinutes(5))
                .build();
        var policy = new ReservationPolicy(NOW_DB, NOW_DB.minusMinutes(10), 1, NOW_DB.plusDays(7));

        assertThatThrownBy(() -> commands.reserveDraft(sameIdDraft, policy))
                .isInstanceOf(GeneratedContentIdConflictException.class);
        assertThat(jdbcTemplate.queryForObject(
                "select status from practice_generated_content where generated_content_id = 'pgc_repo_due_same_id'",
                String.class)).isEqualTo("active");

        sameIdDraft.setGeneratedContentId("pgc_repo_due_same_id_suffix");
        var replacement = commands.reserveDraft(sameIdDraft, policy);
        assertThat(replacement.created()).isTrue();
        assertThat(replacement.content().generatedContentId()).isEqualTo("pgc_repo_due_same_id_suffix");
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where generated_content_id = 'pgc_repo_due_same_id'",
                Integer.class)).isZero();
    }

    @Test
    void reservationExpiresStaleDraftAfterBurstCheckAndCreatesReplacement() {
        var ownerKey = "hmac_test_repo_stale_allowed";
        var fingerprint = "fp_repo_stale_allowed";
        insert(row("pgc_repo_stale_allowed_old")
                .ownerKey(ownerKey)
                .requestFingerprint(fingerprint)
                .createdAt(NOW_DB.minusHours(1))
                .generationWindow(NOW_DB.minusHours(1), NOW_DB.minusMinutes(1))
                .build());
        var draft = row("pgc_repo_stale_allowed_new")
                .ownerKey(ownerKey)
                .requestFingerprint(fingerprint)
                .generationWindow(NOW_DB, NOW_DB.plusMinutes(5))
                .build();

        var reservation = commands.reserveDraft(
                draft,
                new ReservationPolicy(NOW_DB, NOW_DB.minusMinutes(10), 1, NOW_DB.plusDays(7)));

        assertThat(reservation.created()).isTrue();
        assertThat(reservation.content().generatedContentId()).isEqualTo("pgc_repo_stale_allowed_new");
        assertThat(jdbcTemplate.queryForObject(
                "select status from practice_generated_content where generated_content_id = 'pgc_repo_stale_allowed_old'",
                String.class)).isEqualTo("expired");
    }

    @Test
    void staleDraftIsNotExpiredWhenBurstLimitRejectsReservation() {
        var ownerKey = "hmac_test_repo_stale_limit";
        var fingerprint = "fp_repo_stale_limit";
        insert(row("pgc_repo_stale_limit_old")
                .ownerKey(ownerKey)
                .requestFingerprint(fingerprint)
                .createdAt(NOW_DB.minusMinutes(1))
                .generationWindow(NOW_DB.minusMinutes(6), NOW_DB.minusMinutes(1))
                .build());
        var draft = row("pgc_repo_stale_limit_new")
                .ownerKey(ownerKey)
                .requestFingerprint(fingerprint)
                .generationWindow(NOW_DB, NOW_DB.plusMinutes(5))
                .build();

        assertThatThrownBy(() -> commands.reserveDraft(
                draft,
                new ReservationPolicy(NOW_DB, NOW_DB.minusMinutes(10), 1, NOW_DB.plusDays(7))))
                .isInstanceOf(PracticeGenerationRateLimitExceededException.class);

        assertThat(jdbcTemplate.queryForMap("""
                select generated_content_id, status
                from practice_generated_content
                where owner_key = ?
                """, ownerKey))
                .containsEntry("generated_content_id", "pgc_repo_stale_limit_old")
                .containsEntry("status", "draft");
    }

    @Test
    void runtimeLookupsAndCurrentInstallationCandidatesBindCurrentVersionButPrivacyDeletionSpansVersions() {
        insert(row("pgc_repo_v2_active")
                .active()
                .ownerKeyVersion("v2")
                .build());
        assertThat(repository.findActiveOrPromotedByGeneratedContentId("pgc_repo_v2_active")).isEmpty();

        var lookupOwner = "hmac_test_repo_version_lookup";
        insert(row("pgc_repo_v1_lookup")
                .active()
                .ownerKey(lookupOwner)
                .ownerKeyVersion("v1")
                .requestFingerprint("fp_repo_version_lookup")
                .build());
        insert(row("pgc_repo_v2_lookup")
                .active()
                .ownerKey(lookupOwner)
                .ownerKeyVersion("v2")
                .requestFingerprint("fp_repo_version_lookup")
                .build());
        assertThat(repository.findActiveOrPromotedByFingerprint(
                lookupOwner,
                "onboarding",
                "custom_scene",
                "fp_repo_version_lookup",
                "practice-gen-v1",
                "retrieval-v1"))
                .get()
                .extracting(PracticeGeneratedContentEntity::generatedContentId)
                .isEqualTo("pgc_repo_v1_lookup");

        var ownerKey = "hmac_test_repo_version_count";
        insert(row("pgc_repo_v1_count")
                .ownerKey(ownerKey)
                .ownerKeyVersion("v1")
                .requestFingerprint("fp_repo_v1_count")
                .createdAt(NOW_DB.minusMinutes(1))
                .build());
        insert(row("pgc_repo_v2_count")
                .ownerKey(ownerKey)
                .ownerKeyVersion("v2")
                .requestFingerprint("fp_repo_v2_count")
                .createdAt(NOW_DB.minusMinutes(1))
                .build());
        assertThat(repository.countRecentGenerationAttempts(
                ownerKey, "onboarding", "custom_scene", NOW_DB.minusMinutes(10)))
                .isEqualTo(1);

        insert(row("pgc_repo_v2_cleanup")
                .expired()
                .ownerKeyVersion("v2")
                .retentionExpiresAt(NOW_DB.minusMinutes(1))
                .build());
        assertThat(repository.findInstallationCleanupCandidates(
                "install_pgc_repo_default", NOW_DB, 10)).isEmpty();
        assertThat(repository.deleteExpiredInstallationRows(NOW_DB, 10)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where generated_content_id = 'pgc_repo_v2_cleanup'",
                Integer.class)).isZero();

        var accountId = "acct_pgc_repo_version_delete";
        insert(row("pgc_repo_v1_account_delete").account(accountId).ownerKeyVersion("v1").build());
        insert(row("pgc_repo_v2_profile_delete").profile(accountId, "profile_pgc_repo_v2_delete").ownerKeyVersion("v2").build());
        insert(row("pgc_repo_v2_installation_keep").installationId("install_pgc_repo_v2_keep").ownerKeyVersion("v2").build());
        assertThat(repository.deleteAccountOwned(accountId)).isEqualTo(2);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where account_id = ?",
                Integer.class,
                accountId)).isZero();
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where generated_content_id = 'pgc_repo_v2_installation_keep'",
                Integer.class)).isEqualTo(1);
    }

    @Test
    void auditEvidenceBundleCannotBeAttachedToAnotherContentAttempt() {
        insert(row("pgc_repo_audit_a").active().build());
        insert(row("pgc_repo_audit_b").active().build());
        var attemptA = UUID.randomUUID();
        var attemptB = UUID.randomUUID();
        audit.insertAttempt(attempt(attemptA, "pgc_repo_audit_a", 1));
        audit.insertAttempt(attempt(attemptB, "pgc_repo_audit_b", 1));

        var bundleId = UUID.randomUUID();
        audit.insertEvidenceBundle(new PracticeEvidenceBundleEntity(
                bundleId, "pgc_repo_audit_a", 1, null, "initial", UUID.randomUUID(),
                "evidence-v1", HASH, "sanitizer-v1", HASH, 0, NOW_DB));

        assertThatThrownBy(() -> audit.insertOperationRun(operation(
                UUID.randomUUID(), "generator", "pgc_repo_audit_b", 1, bundleId)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void auditCompletionIsGuardedAndListValuesAreStable() {
        insert(row("pgc_repo_audit_completion").active().build());
        var attemptId = UUID.randomUUID();
        var operationId = UUID.randomUUID();
        var providerCallId = UUID.randomUUID();
        audit.insertAttempt(attempt(attemptId, "pgc_repo_audit_completion", 1));
        audit.insertOperationRun(operation(
                operationId, "generator", "pgc_repo_audit_completion", 1, null));
        audit.insertProviderCall(providerCall(providerCallId, operationId, "provider-a"));

        audit.completeAttempt(attemptId, "first", List.of("z", "a", "z"), NOW_DB.plusSeconds(1));
        audit.completeAttempt(attemptId, "second", List.of("b"), NOW_DB.plusSeconds(2));
        audit.completeOperationRun(operationId, "first", NOW_DB.plusSeconds(1));
        audit.completeOperationRun(operationId, "second", NOW_DB.plusSeconds(2));
        audit.completeProviderCall(providerCallId, "first", "trace-first", 10L, NOW_DB.plusSeconds(1));
        audit.completeProviderCall(providerCallId, "second", "trace-second", 20L, NOW_DB.plusSeconds(2));

        assertThat(jdbcTemplate.queryForMap("""
                select outcome, array_to_string(violation_codes, ',') as violations
                from practice_generated_content_attempts where attempt_id = ?
                """, attemptId))
                .containsEntry("outcome", "first")
                .containsEntry("violations", "a,z");
        assertThat(jdbcTemplate.queryForObject(
                "select outcome from practice_ai_operation_runs where operation_run_id = ?",
                String.class, operationId)).isEqualTo("first");
        assertThat(jdbcTemplate.queryForMap("""
                select outcome, provider_trace_id, latency_ms
                from practice_ai_provider_calls where provider_call_id = ?
                """, providerCallId))
                .containsEntry("outcome", "first")
                .containsEntry("provider_trace_id", "trace-first")
                .containsEntry("latency_ms", 10L);
    }

    @Test
    void auditEmptyEvidenceItemsAreANoOp() {
        assertThatNoException().isThrownBy(() -> audit.insertEvidenceItems(List.of()));
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content_evidence_items",
                Integer.class)).isZero();
    }

    @Test
    void judgeResultOnlyAcceptsQualityJudgeProviderCallsAndNormalizesLists() {
        insert(row("pgc_repo_audit_judge").active().build());
        var attemptId = UUID.randomUUID();
        audit.insertAttempt(attempt(attemptId, "pgc_repo_audit_judge", 1));
        var generatorOperation = UUID.randomUUID();
        var judgeOperation = UUID.randomUUID();
        audit.insertOperationRun(operation(
                generatorOperation, "generator", "pgc_repo_audit_judge", 1, null));
        audit.insertOperationRun(operation(
                judgeOperation, "quality_judge", "pgc_repo_audit_judge", 1, null));
        var generatorCall = UUID.randomUUID();
        var judgeCall = UUID.randomUUID();
        audit.insertProviderCall(providerCall(generatorCall, generatorOperation, "provider-generator"));
        audit.insertProviderCall(providerCall(judgeCall, judgeOperation, "provider-judge"));

        audit.insertJudgeResult(judgeResult(UUID.randomUUID(), generatorCall));
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content_judge_results",
                Integer.class)).isZero();

        audit.insertJudgeResult(judgeResult(UUID.randomUUID(), judgeCall));
        assertThat(jdbcTemplate.queryForMap("""
                select array_to_string(violation_codes, ',') as violations,
                       array_to_string(repair_directives, ',') as repairs,
                       array_to_string(evidence_gap_codes, ',') as gaps
                from practice_generated_content_judge_results where provider_call_id = ?
                """, judgeCall))
                .containsEntry("violations", "a,z")
                .containsEntry("repairs", "fix-a,fix-z")
                .containsEntry("gaps", "gap-a,gap-z");
    }

    private PracticeGenerationAttemptEntity attempt(UUID id, String contentId, int number) {
        return new PracticeGenerationAttemptEntity(
                id, contentId, number, "generator", "started", null, List.of("initial"), NOW_DB, null);
    }

    private PracticeAiOperationRunEntity operation(
            UUID id, String type, String contentId, int attemptNumber, UUID evidenceBundleId
    ) {
        return new PracticeAiOperationRunEntity(
                id, type, "generated_content", contentId, contentId, attemptNumber, evidenceBundleId,
                "practice-generate", "prompt-v1", HASH, "policy-v1", HASH,
                "started", null, NOW_DB, null);
    }

    private PracticeAiProviderCallEntity providerCall(UUID id, UUID operationId, String providerName) {
        return new PracticeAiProviderCallEntity(
                id, operationId, providerName, "chat", "model-v1", 0, UUID.randomUUID(),
                null, "routing-v1", HASH, "started", null, NOW_DB, null);
    }

    private PracticeJudgeResultEntity judgeResult(UUID id, UUID providerCallId) {
        return new PracticeJudgeResultEntity(
                id, providerCallId, "repair", "repair", "consistent", "{}",
                List.of("z", "a", "z"), List.of("fix-z", "fix-a", "fix-z"),
                List.of("gap-z", "gap-a", "gap-z"), BigDecimal.valueOf(0.75),
                "rubric-v1", HASH, NOW_DB);
    }

    private PracticeGeneratedContentEntity generatingCarePathRow(String generatedContentId) {
        var row = row(generatedContentId).surface("care_path").active().build();
        row.setStatus("generating");
        row.setNormalizedSceneText("洗澡前宝宝有点紧张");
        row.setGenerationStartedAt(NOW_DB);
        row.setGenerationExpiresAt(NOW_DB.plusMinutes(5));
        return row;
    }

    private TransactionTemplate transaction() {
        return new TransactionTemplate(transactionManager);
    }

    private void insertCarePathStarter(String generatedContentId, String utteranceId) {
        insertCarePathUtterance(generatedContentId, utteranceId, "starter", null, 1);
    }

    private void insertCarePathSupport(String generatedContentId, String reactionType, int displayOrder) {
        insertCarePathUtterance(
                generatedContentId,
                "utt_" + reactionType + "_" + generatedContentId,
                "reaction_support",
                reactionType,
                displayOrder);
    }

    private void insertCarePathUtterance(
            String generatedContentId,
            String utteranceId,
            String role,
            String reactionType,
            int displayOrder
    ) {
        jdbcTemplate.update(
                """
                insert into practice_generated_content_utterances (
                    utterance_id, generated_content_id, role, reaction_type, english_text, chinese_text,
                    pronunciation_hint, tpr_action_zh, delivery_guidance_zh, difficulty, display_order,
                    approval_status, approved_content_version, created_at
                ) values (?, ?, ?, ?, 'Warm water.', '水暖暖的。', 'warm water', '指向水。', '慢一点说。',
                          'starter', ?, 'approved', 1, ?)
                """,
                utteranceId,
                generatedContentId,
                role,
                reactionType,
                displayOrder,
                Timestamp.from(NOW));
    }

    private void insert(PracticeGeneratedContentEntity row) {
        if (row.accountId() != null) {
            insertAccount(row.accountId());
        }
        if (row.profileId() != null) {
            insertProfile(row.accountId(), row.profileId());
        }
        insertRaw(row);
    }

    private void insertRaw(PracticeGeneratedContentEntity row) {
        new NamedParameterJdbcTemplate(jdbcTemplate).update(
                """
                insert into practice_generated_content (
                    generated_content_id, owner_scope, owner_key, owner_key_version,
                    account_id, installation_ref_hash, profile_id, surface, mode,
                    request_fingerprint, client_request_id, client_request_fingerprint,
                    normalized_scene_text, age_range, parent_goal, locale,
                    space_slug, activity_slug, phrase_slug, space_title_zh, activity_title_zh,
                    scene_tag_en, tpr_action_zh, delivery_guidance_zh, english_text, chinese_text,
                    pronunciation_hint, difficulty, generation_source, status,
                    generation_profile_version, generation_profile_hash, rubric_version,
                    rubric_content_hash, evidence_policy_version, evidence_policy_content_hash,
                    provider_routing_policy_version, provider_routing_policy_hash,
                    generation_attempt_limit, content_refresh_epoch, content_version,
                    generation_error_code, generation_error_retryable, generation_started_at,
                    generation_expires_at, retention_expires_at, created_at, updated_at
                ) values (
                    :generatedContentId, :ownerScope, :ownerKey, :ownerKeyVersion,
                    :accountId, :installationRefHash, :profileId, :surface, :mode,
                    :requestFingerprint, :clientRequestId, :clientRequestFingerprint,
                    :normalizedSceneText, :ageRange, :parentGoal, :locale,
                    :spaceSlug, :activitySlug, :phraseSlug, :spaceTitleZh, :activityTitleZh,
                    :sceneTagEn, :tprActionZh, :deliveryGuidanceZh, :englishText, :chineseText,
                    :pronunciationHint, :difficulty, :generationSource, :status,
                    :generationProfileVersion, :generationProfileHash, :rubricVersion,
                    :rubricContentHash, :evidencePolicyVersion, :evidencePolicyContentHash,
                    :providerRoutingPolicyVersion, :providerRoutingPolicyHash,
                    :generationAttemptLimit, :contentRefreshEpoch, :contentVersion,
                    :generationErrorCode, :generationErrorRetryable, :generationStartedAt,
                    :generationExpiresAt, :retentionExpiresAt, :createdAt, :updatedAt
                )
                """,
                new BeanPropertySqlParameterSource(row));
    }

    private CustomSceneGeneratedContentValidator validator() {
        var policy = PracticeDiscoveryPolicyTestFixture.properties();
        return new CustomSceneGeneratedContentValidator(
                policy,
                new com.zhangspaghetti.babytalk.practice.discovery.CustomSceneIntentClassifier(policy));
    }

    private void assertTerminalPrivacyAndRetention(String generatedContentId, OffsetDateTime expectedRetention) {
        var normalized = jdbcTemplate.queryForObject(
                "select normalized_scene_text from practice_generated_content where generated_content_id = ?",
                String.class,
                generatedContentId);
        var retention = jdbcTemplate.queryForObject(
                "select retention_expires_at from practice_generated_content where generated_content_id = ?",
                OffsetDateTime.class,
                generatedContentId);
        assertThat(normalized).isNull();
        assertThat(retention).isEqualTo(expectedRetention);
    }

    private void assertExpiredAndInputCleared(String generatedContentId) {
        var status = jdbcTemplate.queryForObject(
                "select status from practice_generated_content where generated_content_id = ?",
                String.class,
                generatedContentId);
        var normalized = jdbcTemplate.queryForObject(
                "select normalized_scene_text from practice_generated_content where generated_content_id = ?",
                String.class,
                generatedContentId);
        assertThat(status).isEqualTo("expired");
        assertThat(normalized).isNull();
    }

    private void assertRejected(PracticeGeneratedContentEntity row) {
        assertThatThrownBy(() -> insert(row))
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
                on conflict (account_id) do nothing
                """,
                accountId,
                accountId + "_phone",
                Timestamp.from(NOW));
    }

    private void insertProfile(String accountId, String profileId) {
        jdbcTemplate.update(
                """
                insert into baby_profiles (
                    profile_id,
                    account_id,
                    baby_name,
                    age_range,
                    parent_goal,
                    onboarding_state,
                    version,
                    created_at,
                    updated_at
                ) values (?, ?, null, 'm7_11', 'calmer_care', 'draft', 1, ?, ?)
                on conflict (profile_id) do nothing
                """,
                profileId,
                accountId,
                Timestamp.from(NOW),
                Timestamp.from(NOW));
    }

    private void cleanGeneratedContentFixtures() {
        jdbcTemplate.update(
                """
                delete from practice_generated_content
                where generated_content_id like 'pgc_repo_%'
                   or owner_key like 'hmac_test_repo_%'
                   or installation_ref_hash like 'install_pgc_repo_%'
                """);
    }

    private RowBuilder row(String generatedContentId) {
        return new RowBuilder(generatedContentId);
    }

    private static class RowBuilder {
        private final String generatedContentId;
        private String ownerScope = "installation";
        private String ownerKey;
        private String ownerKeyVersion = "v1";
        private String accountId;
        private String installationRefHash = "install_pgc_repo_default";
        private String profileId;
        private String surface = "onboarding";
        private String mode = "custom_scene";
        private String requestFingerprint;
        private String clientRequestId;
        private String clientRequestFingerprint;
        private String normalizedSceneText = "洗澡前宝宝有点紧张";
        private String ageRange = "m7_11";
        private String parentGoal = "calmer_care";
        private String locale = "zh-CN";
        private String spaceSlug;
        private String activitySlug;
        private String phraseSlug;
        private String spaceTitleZh;
        private String activityTitleZh;
        private String sceneTagEn;
        private String tprActionZh;
        private String deliveryGuidanceZh;
        private String englishText;
        private String chineseText;
        private String pronunciationHint;
        private String difficulty;
        private String generationSource;
        private String status = "draft";
        private String generationProfileVersion = "practice-gen-v1";
        private int contentVersion = 1;
        private String generationErrorCode;
        private OffsetDateTime generationStartedAt;
        private OffsetDateTime generationExpiresAt = NOW_DB.plusMinutes(5);
        private OffsetDateTime retentionExpiresAt;
        private OffsetDateTime createdAt = NOW_DB;
        private OffsetDateTime updatedAt = NOW_DB;
        private boolean fillResponseFields = true;
        private boolean fillInstallationRetention = true;

        RowBuilder(String generatedContentId) {
            this.generatedContentId = generatedContentId;
            this.ownerKey = "hmac_test_repo_" + generatedContentId;
            this.requestFingerprint = "fp_" + generatedContentId;
        }

        RowBuilder ownerScope(String ownerScope) {
            this.ownerScope = ownerScope;
            return this;
        }

        RowBuilder ownerKey(String ownerKey) {
            this.ownerKey = ownerKey;
            return this;
        }

        RowBuilder ownerKeyVersion(String ownerKeyVersion) {
            this.ownerKeyVersion = ownerKeyVersion;
            return this;
        }

        RowBuilder account(String accountId) {
            this.ownerScope = "account";
            this.accountId = accountId;
            this.installationRefHash = null;
            this.profileId = null;
            return this;
        }

        RowBuilder accountId(String accountId) {
            this.accountId = accountId;
            return this;
        }

        RowBuilder profile(String accountId, String profileId) {
            this.ownerScope = "profile";
            this.accountId = accountId;
            this.profileId = profileId;
            this.installationRefHash = null;
            return this;
        }

        RowBuilder globalCandidate() {
            this.ownerScope = "global_candidate";
            this.accountId = null;
            this.installationRefHash = null;
            this.profileId = null;
            return this;
        }

        RowBuilder installationId(String installationId) {
            this.installationRefHash = installationId;
            return this;
        }

        RowBuilder surface(String surface) {
            this.surface = surface;
            return this;
        }

        RowBuilder mode(String mode) {
            this.mode = mode;
            return this;
        }

        RowBuilder requestFingerprint(String requestFingerprint) {
            this.requestFingerprint = requestFingerprint;
            return this;
        }

        RowBuilder clientRequestId(String clientRequestId) {
            this.clientRequestId = clientRequestId;
            this.clientRequestFingerprint = clientRequestId == null ? null : "crf_" + "a".repeat(64);
            return this;
        }

        RowBuilder active() {
            this.status = "active";
            return this;
        }

        RowBuilder promoted() {
            this.status = "active";
            return this;
        }

        RowBuilder rejected() {
            this.status = "rejected";
            return this;
        }

        RowBuilder expired() {
            this.status = "expired";
            return this;
        }

        RowBuilder status(String status) {
            this.status = status;
            return this;
        }

        RowBuilder generationSource(String generationSource) {
            this.generationSource = generationSource;
            return this;
        }

        RowBuilder slugs(String spaceSlug, String activitySlug, String phraseSlug) {
            this.spaceSlug = spaceSlug;
            this.activitySlug = activitySlug;
            this.phraseSlug = phraseSlug;
            return this;
        }

        RowBuilder createdAt(OffsetDateTime createdAt) {
            this.createdAt = createdAt;
            this.updatedAt = createdAt;
            return this;
        }

        RowBuilder retentionExpiresAt(OffsetDateTime retentionExpiresAt) {
            this.retentionExpiresAt = retentionExpiresAt;
            return this;
        }

        RowBuilder generationWindow(OffsetDateTime generationStartedAt, OffsetDateTime generationExpiresAt) {
            this.generationStartedAt = "generating".equals(status) ? generationStartedAt : null;
            this.generationExpiresAt = generationExpiresAt;
            return this;
        }

        RowBuilder normalizedSceneText(String normalizedSceneText) {
            this.normalizedSceneText = normalizedSceneText;
            return this;
        }

        RowBuilder withoutAutomaticRetention() {
            this.fillInstallationRetention = false;
            this.retentionExpiresAt = null;
            return this;
        }

        RowBuilder generationErrorCode(String generationErrorCode) {
            this.generationErrorCode = generationErrorCode;
            return this;
        }

        RowBuilder contentVersion(int contentVersion) {
            this.contentVersion = contentVersion;
            return this;
        }

        RowBuilder withoutResponseFields() {
            this.fillResponseFields = false;
            return this;
        }

        PracticeGeneratedContentEntity build() {
            if (fillResponseFields && ("active".equals(status) || "promoted".equals(status))) {
                spaceSlug = spaceSlug == null ? "space_" + generatedContentId : spaceSlug;
                activitySlug = activitySlug == null ? "activity_" + generatedContentId : activitySlug;
                phraseSlug = phraseSlug == null ? "phrase_" + generatedContentId : phraseSlug;
                spaceTitleZh = "日常照护";
                activityTitleZh = "洗澡时间";
                sceneTagEn = "Bath time";
                tprActionZh = "指向物品。";
                deliveryGuidanceZh = "慢一点重复说。";
                englishText = "Warm water.";
                chineseText = "水暖暖的。";
                pronunciationHint = "warm water";
                difficulty = "starter";
                generationSource = generationSource == null ? "agentic_search" : generationSource;
            }
            if (!"draft".equals(status)) {
                normalizedSceneText = null;
            }
            if (("rejected".equals(status) || "expired".equals(status))
                    && generationErrorCode == null) {
                generationErrorCode = "test_terminal";
            }
            if (fillInstallationRetention && "installation".equals(ownerScope) && retentionExpiresAt == null) {
                retentionExpiresAt = NOW_DB.plusDays(
                        "active".equals(status) || "promoted".equals(status) ? 30 : 7);
            }
            if ("generating".equals(status) && generationStartedAt == null) {
                generationStartedAt = NOW_DB;
            }
            if ("active".equals(status) && generationStartedAt == null) {
                generationStartedAt = NOW_DB;
            }
            var row = new PracticeGeneratedContentEntity();
            row.setGeneratedContentId(generatedContentId);
            row.setOwnerScope(ownerScope);
            row.setOwnerKey(ownerKey);
            row.setOwnerKeyVersion(ownerKeyVersion);
            row.setAccountId(accountId);
            row.setInstallationRefHash(installationRefHash);
            row.setProfileId(profileId);
            row.setSurface(surface);
            row.setMode(mode);
            row.setRequestFingerprint(requestFingerprint);
            row.setClientRequestId(clientRequestId);
            row.setClientRequestFingerprint(clientRequestFingerprint);
            row.setNormalizedSceneText(normalizedSceneText);
            row.setAgeRange(ageRange);
            row.setParentGoal(parentGoal);
            row.setLocale(locale);
            row.setSpaceSlug(spaceSlug);
            row.setActivitySlug(activitySlug);
            row.setPhraseSlug(phraseSlug);
            row.setSpaceTitleZh(spaceTitleZh);
            row.setActivityTitleZh(activityTitleZh);
            row.setSceneTagEn(sceneTagEn);
            row.setTprActionZh(tprActionZh);
            row.setDeliveryGuidanceZh(deliveryGuidanceZh);
            row.setEnglishText(englishText);
            row.setChineseText(chineseText);
            row.setPronunciationHint(pronunciationHint);
            row.setDifficulty(difficulty);
            row.setGenerationSource(generationSource);
            row.setStatus(status);
            row.setGenerationProfileVersion(generationProfileVersion);
            row.setGenerationProfileHash("a".repeat(64));
            row.setRubricVersion("rubric-v1");
            row.setRubricContentHash("b".repeat(64));
            row.setEvidencePolicyVersion("evidence-v1");
            row.setEvidencePolicyContentHash("c".repeat(64));
            row.setProviderRoutingPolicyVersion("routing-v1");
            row.setProviderRoutingPolicyHash("d".repeat(64));
            row.setGenerationAttemptLimit(3);
            row.setContentRefreshEpoch(1);
            row.setContentVersion(contentVersion);
            row.setGenerationErrorCode(generationErrorCode);
            row.setGenerationErrorRetryable(
                    "rejected".equals(status) || "expired".equals(status) ? Boolean.TRUE : null);
            row.setGenerationStartedAt(generationStartedAt);
            row.setGenerationExpiresAt(generationExpiresAt);
            row.setRetentionExpiresAt(retentionExpiresAt);
            row.setCreatedAt(createdAt);
            row.setUpdatedAt(updatedAt);
            return row;
        }
    }
}
