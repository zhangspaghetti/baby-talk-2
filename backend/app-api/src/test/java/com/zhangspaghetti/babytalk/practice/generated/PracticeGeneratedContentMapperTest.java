package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGeneratedContentValidator;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGenerationService;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryCustomSceneProperties;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyTestFixture;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

class PracticeGeneratedContentMapperTest extends AbstractIntegrationTest {

    private static final Instant NOW = Instant.parse("2026-07-03T04:00:00Z");
    private static final OffsetDateTime NOW_DB = OffsetDateTime.ofInstant(NOW, ZoneOffset.UTC);

    @Autowired
    private PracticeGeneratedContentService repository;

    @Autowired
    private PracticeGeneratedContentMapper mapper;

    @Autowired
    private PracticeGeneratedContentWriteService writeService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

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
                .promoted()
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

        assertThatThrownBy(() -> mapper.insertRow(row))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void activeAndPromotedRowsRequireGeneratedResponseFields() {
        assertRejected(row("pgc_repo_incomplete_active")
                .active()
                .withoutResponseFields()
                .build());
        assertRejected(row("pgc_repo_incomplete_promoted")
                .globalCandidate()
                .promoted()
                .withoutResponseFields()
                .build());
    }

    @Test
    void nullableOwnerIdsAreStillUniqueByNonNullOwnerKey() {
        insert(row("pgc_repo_global_draft_1")
                .globalCandidate()
                .ownerKey("hmac_test_repo_global_live")
                .requestFingerprint("fp_repo_nullable_owner")
                .build());

        assertRejected(row("pgc_repo_global_draft_2")
                .globalCandidate()
                .ownerKey("hmac_test_repo_global_live")
                .requestFingerprint("fp_repo_nullable_owner")
                .build());
    }

    @Test
    void promotedBlocksDuplicateActiveForSameLiveFingerprint() {
        insert(row("pgc_repo_promoted_live")
                .globalCandidate()
                .promoted()
                .ownerKey("hmac_test_repo_promoted_blocks")
                .requestFingerprint("fp_repo_promoted_blocks")
                .build());

        assertRejected(row("pgc_repo_active_live_conflict")
                .globalCandidate()
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
                .globalCandidate()
                .promoted()
                .ownerKey("hmac_test_repo_slug_space")
                .requestFingerprint("fp_repo_slug_space")
                .slugs("space_repo_slug", "activity_repo_slug_2", "phrase_repo_slug_2")
                .build());
        assertRejected(row("pgc_repo_slug_promoted_activity")
                .globalCandidate()
                .promoted()
                .ownerKey("hmac_test_repo_slug_activity")
                .requestFingerprint("fp_repo_slug_activity")
                .slugs("space_repo_slug_2", "activity_repo_slug", "phrase_repo_slug_3")
                .build());
        assertRejected(row("pgc_repo_slug_promoted_phrase")
                .globalCandidate()
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
        insert(row("pgc_repo_lookup_promoted").globalCandidate().promoted().build());

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
                active.promptVersion(),
                active.strategyVersion());

        assertThat(found).isPresent();
        assertThat(found.get().generatedContentId()).isEqualTo(active.generatedContentId());

        var promoted = row("pgc_repo_lookup_promoted_fingerprint")
                .globalCandidate()
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
                promoted.promptVersion(),
                promoted.strategyVersion());

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
        var mapper = org.mockito.Mockito.mock(PracticeGeneratedContentMapper.class);
        var retryingRepository = new PracticeGeneratedContentService(
                mapper,
                new PracticeGeneratedContentWriteService(mapper),
                org.mockito.Mockito.mock(CustomSceneGenerationService.class),
                validator(),
                PracticeDiscoveryCustomSceneProperties.enabledForTest("fake"),
                PracticeDiscoveryPolicyTestFixture.properties(),
                Clock.fixed(NOW, ZoneOffset.UTC),
                new PracticeGeneratedContentOwnerProperties(
                        "v1", "test-owner-key-secret-test-owner-key"));
        org.mockito.Mockito.when(mapper.insertDraftIgnoringLiveConflict(org.mockito.ArgumentMatchers.any()))
                .thenReturn(null);
        org.mockito.Mockito.when(mapper.findLiveByFingerprint(
                org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.any()))
                .thenReturn(null);

        assertThatThrownBy(() -> retryingRepository.reserveDraft(row))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("practice generated content reservation conflict could not be loaded");
        org.mockito.Mockito.verify(mapper)
                .insertDraftIgnoringLiveConflict(org.mockito.ArgumentMatchers.any());
        org.mockito.Mockito.verify(mapper, org.mockito.Mockito.times(2))
                .findLiveByFingerprint(
                        org.mockito.ArgumentMatchers.any(),
                        org.mockito.ArgumentMatchers.any(),
                        org.mockito.ArgumentMatchers.any(),
                        org.mockito.ArgumentMatchers.any(),
                        org.mockito.ArgumentMatchers.any(),
                        org.mockito.ArgumentMatchers.any(),
                        org.mockito.ArgumentMatchers.any(),
                        org.mockito.ArgumentMatchers.any());
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
                .isInstanceOf(PracticeGeneratedContentService.GeneratedContentIdConflictException.class);
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
                .globalCandidate()
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
    void reservationLazilyExpiresDueInstallationActiveBeforeInsert() {
        var ownerKey = "hmac_test_repo_lazy_active";
        var fingerprint = "fp_repo_lazy_active";
        insert(row("pgc_repo_lazy_active_old")
                .active()
                .ownerKey(ownerKey)
                .requestFingerprint(fingerprint)
                .retentionExpiresAt(NOW_DB.minusMinutes(1))
                .build());
        var draft = row("pgc_repo_lazy_active_new")
                .ownerKey(ownerKey)
                .requestFingerprint(fingerprint)
                .generationWindow(NOW_DB, NOW_DB.plusMinutes(5))
                .build();

        var reservation = writeService.reserveDraft(
                draft,
                new PracticeGeneratedContentWriteService.ReservationPolicy(
                        NOW_DB,
                        NOW_DB.minusMinutes(10),
                        3,
                        NOW_DB.minusDays(1),
                        10,
                        NOW_DB.plusDays(7)));

        assertThat(reservation.inserted()).isTrue();
        assertThat(reservation.row().generatedContentId()).isEqualTo("pgc_repo_lazy_active_new");
        assertThat(jdbcTemplate.queryForObject(
                "select status from practice_generated_content where generated_content_id = 'pgc_repo_lazy_active_old'",
                String.class)).isEqualTo("expired");
        assertThat(jdbcTemplate.queryForObject(
                "select generation_error_code from practice_generated_content where generated_content_id = 'pgc_repo_lazy_active_old'",
                String.class)).isEqualTo("retention_expired");
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

    private void insert(PracticeGeneratedContentEntity row) {
        if (row.accountId() != null) {
            insertAccount(row.accountId());
        }
        if (row.profileId() != null) {
            insertProfile(row.accountId(), row.profileId());
        }
        mapper.insertRow(row);
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
        private String coachTipZh;
        private String englishText;
        private String chineseText;
        private String pronunciationHint;
        private String difficulty;
        private String generationSource;
        private String status = "draft";
        private String providerTraceId;
        private String retrievalTraceId;
        private String modelName;
        private String promptVersion = "practice-gen-v1";
        private String strategyVersion = "retrieval-v1";
        private int contentVersion = 1;
        private String generationErrorCode;
        private OffsetDateTime generationStartedAt = NOW_DB;
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

        RowBuilder active() {
            this.status = "active";
            return this;
        }

        RowBuilder promoted() {
            this.status = "promoted";
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
            this.generationStartedAt = generationStartedAt;
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
                coachTipZh = "慢一点重复说。";
                englishText = "Warm water.";
                chineseText = "水暖暖的。";
                pronunciationHint = "warm water";
                difficulty = "starter";
                generationSource = generationSource == null ? "agentic_search" : generationSource;
            }
            if (!"draft".equals(status)) {
                normalizedSceneText = null;
            }
            if (fillInstallationRetention && "installation".equals(ownerScope) && retentionExpiresAt == null) {
                retentionExpiresAt = NOW_DB.plusDays(
                        "active".equals(status) || "promoted".equals(status) ? 30 : 7);
            }
            var row = new PracticeGeneratedContentEntity(
                    generatedContentId,
                    ownerScope,
                    ownerKey,
                    accountId,
                    installationRefHash,
                    profileId,
                    surface,
                    mode,
                    requestFingerprint,
                    normalizedSceneText,
                    ageRange,
                    parentGoal,
                    locale,
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
                    status,
                    providerTraceId,
                    retrievalTraceId,
                    modelName,
                    promptVersion,
                    strategyVersion,
                    contentVersion,
                    generationErrorCode,
                    generationStartedAt,
                    generationExpiresAt,
                    createdAt,
                    updatedAt);
            row.setOwnerKeyVersion(ownerKeyVersion);
            row.setPolicyVersion("policy-v2");
            row.setRetentionExpiresAt(retentionExpiresAt);
            return row;
        }
    }
}
