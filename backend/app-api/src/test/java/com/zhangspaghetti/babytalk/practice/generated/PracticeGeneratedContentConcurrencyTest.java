package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.sql.Connection;
import java.sql.SQLException;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.locks.LockSupport;
import javax.sql.DataSource;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest(properties = {
        "babytalk.practice.discovery.custom-scene.enabled=true",
        "babytalk.practice.discovery.custom-scene.provider-mode=fake",
        "babytalk.practice.discovery.custom-scene.installation-burst-limit=1",
        "babytalk.practice.discovery.custom-scene.installation-daily-limit=10",
        "babytalk.practice.discovery.custom-scene.burst-window=PT10M",
        "babytalk.practice.discovery.custom-scene.daily-window=P1D",
        "babytalk.practice.discovery.owner.key-version=v1",
        "babytalk.practice.discovery.owner.key-secret=integration-owner-key-secret-at-least-32-bytes"
})
@Import(PracticeGeneratedContentConcurrencyTest.ProviderTestConfiguration.class)
class PracticeGeneratedContentConcurrencyTest extends AbstractIntegrationTest {

    private static final String OWNER_KEY_SECRET = "integration-owner-key-secret-at-least-32-bytes";
    private static final String INSTALLATION_ID = "install_generated_content_concurrency";
    private static final String OTHER_INSTALLATION_ID = "install_generated_content_other_owner";
    private static final String HASH = "a".repeat(64);
    private static final String STALE_CLEANUP_CONTENT_ID = "pgc_concurrent_stale_cleanup";

    @Autowired
    private PracticeGeneratedContentService service;

    @Autowired
    private PracticeGeneratedContentCommands commands;

    @Autowired
    private PracticeGeneratedContentKeyFactory keyFactory;

    @Autowired
    private RecordingCustomSceneGenerator provider;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private DataSource dataSource;

    private final List<ExecutorService> executors = new ArrayList<>();

    @BeforeEach
    void resetProvider() {
        jdbcTemplate.update(
                "delete from practice_generated_content where owner_key = ?",
                ownerKey(INSTALLATION_ID));
        jdbcTemplate.update(
                "delete from practice_generated_content where owner_key = ?",
                ownerKey(OTHER_INSTALLATION_ID));
        provider.reset(false);
    }

    @AfterEach
    void stopExecutorsAndReleaseProvider() {
        provider.release();
        executors.forEach(ExecutorService::shutdownNow);
    }

    @Test
    void sameOwnerDifferentFingerprintsCannotExceedBurstCap() throws Exception {
        var ownerKey = ownerKey(INSTALLATION_ID);
        try (var heldOwnerLock = holdOwnerLock(ownerKey)) {
            var futures = startConcurrentCalls(
                    request("洗澡前宝宝有点紧张"),
                    request("出门前宝宝不想穿鞋"));

            awaitAdvisoryWaiters(heldOwnerLock, 2);
            heldOwnerLock.commit();

            var results = collect(futures);
            assertThat(results).filteredOn(CallResult::succeeded).hasSize(1);
            assertThat(results)
                    .filteredOn(result -> result.error() != null)
                    .extracting(result -> result.error().code())
                    .containsExactly("custom_scene_rate_limited");
            assertThat(provider.callCount()).isEqualTo(1);
            assertThat(countOwnerRows(ownerKey)).isEqualTo(1);
        }
    }

    @Test
    void sameFingerprintConcurrencyReservesOneDraftAndCallsProviderOnce() throws Exception {
        provider.reset(true);
        var ownerKey = ownerKey(INSTALLATION_ID);
        try (var heldOwnerLock = holdOwnerLock(ownerKey)) {
            var request = request("洗澡前宝宝有点紧张");
            var futures = startConcurrentCalls(request, request);

            awaitAdvisoryWaiters(heldOwnerLock, 2);
            heldOwnerLock.commit();
            assertThat(provider.awaitEntered()).isTrue();
            awaitCompletedCalls(futures, 1);

            assertThat(provider.callCount()).isEqualTo(1);
            assertThat(countOwnerRows(ownerKey)).isEqualTo(1);

            provider.release();
            var results = collect(futures);
            assertThat(results)
                    .filteredOn(result -> result.error() != null)
                    .extracting(result -> result.error().code())
                    .containsExactly("generation_in_progress");
            assertThat(results).filteredOn(CallResult::succeeded).hasSize(1);
        }
    }

    @Test
    void sameClientRequestIdConcurrentCallsRunProviderOnceAndReconcilePersistedActiveContent() throws Exception {
        provider.reset(true);
        var request = carePathRequest(INSTALLATION_ID, "request_concurrent_001", "洗澡前宝宝有点紧张");
        var futures = startConcurrentCalls(request, request);

        assertThat(provider.awaitEntered()).isTrue();
        awaitCompletedCalls(futures, 1);
        assertThat(provider.callCount()).isEqualTo(1);

        provider.release();
        var results = collect(futures);
        var active = results.stream().filter(CallResult::succeeded).findFirst().orElseThrow().row();
        assertThat(results)
                .filteredOn(result -> result.error() != null)
                .extracting(result -> result.error().code())
                .containsExactly("generation_in_progress");
        assertThat(service.generateCustomScene(request).generatedContentId()).isEqualTo(active.generatedContentId());
        assertThat(provider.callCount()).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where client_request_id = ?",
                Integer.class,
                "request_concurrent_001")).isEqualTo(1);
    }

    @Test
    void clientRequestIdConflictsOnChangedFactsButIsolatedOwnersMayReuseIt() {
        var clientRequestId = "request_owner_scope_001";
        var first = service.generateCustomScene(
                carePathRequest(INSTALLATION_ID, clientRequestId, "洗澡前宝宝有点紧张"));

        assertThatThrownBy(() -> service.generateCustomScene(
                carePathRequest(INSTALLATION_ID, clientRequestId, "出门前宝宝不想穿鞋")))
                .isInstanceOfSatisfying(ContractException.class, error -> {
                    assertThat(error.status()).isEqualTo(org.springframework.http.HttpStatus.CONFLICT);
                    assertThat(error.code()).isEqualTo("client_request_id_conflict");
                });
        assertThat(provider.callCount()).isEqualTo(1);

        var otherOwner = service.generateCustomScene(
                carePathRequest(OTHER_INSTALLATION_ID, clientRequestId, "出门前宝宝不想穿鞋"));
        assertThat(otherOwner.generatedContentId()).isNotEqualTo(first.generatedContentId());
        assertThat(provider.callCount()).isEqualTo(2);
    }

    @Test
    void terminalClientRequestRequiresNewIdBeforeRetryingGeneration() {
        var firstRequest = carePathRequest(INSTALLATION_ID, "request_terminal_001", "洗澡前宝宝有点紧张");
        provider.failNext();

        assertThatThrownBy(() -> service.generateCustomScene(firstRequest))
                .isInstanceOfSatisfying(ContractException.class, error ->
                        assertThat(error.code()).isEqualTo("generation_unavailable"));
        assertThat(provider.callCount()).isEqualTo(1);

        assertThatThrownBy(() -> service.generateCustomScene(firstRequest))
                .isInstanceOfSatisfying(ContractException.class, error -> {
                    assertThat(error.status()).isEqualTo(org.springframework.http.HttpStatus.CONFLICT);
                    assertThat(error.code()).isEqualTo("client_request_terminal");
                    assertThat(error.details()).containsEntry("requiresNewClientRequestId", true);
                });
        assertThat(provider.callCount()).isEqualTo(1);

        var terminalId = jdbcTemplate.queryForObject(
                "select generated_content_id from practice_generated_content where client_request_id = ?",
                String.class,
                "request_terminal_001");
        moveTerminalOutsideBurstWindow(terminalId);
        var retry = service.generateCustomScene(
                carePathRequest(INSTALLATION_ID, "request_terminal_002", "洗澡前宝宝有点紧张"));
        assertThat(retry.status()).isEqualTo("active");
        assertThat(provider.callCount()).isEqualTo(2);
    }

    @Test
    void expiredActiveSameFingerprintConcurrencyReservesOneReplacementAndCallsProviderOnce() throws Exception {
        var request = request("洗澡前宝宝有点紧张");
        var expired = service.generateCustomScene(request);
        var ownerKey = ownerKey(INSTALLATION_ID);
        jdbcTemplate.update(
                """
                update practice_generated_content
                set retention_expires_at = now() - interval '1 minute',
                    created_at = now() - interval '2 days',
                    updated_at = now() - interval '2 days'
                where generated_content_id = ?
                """,
                expired.generatedContentId());
        provider.reset(true);

        try (var heldOwnerLock = holdOwnerLock(ownerKey)) {
            var futures = startConcurrentCalls(request, request);
            awaitAdvisoryWaiters(heldOwnerLock, 2);
            heldOwnerLock.commit();

            assertThat(provider.awaitEntered()).isTrue();
            awaitCompletedCalls(futures, 1);
            assertThat(provider.callCount()).isEqualTo(1);
            assertThat(countOwnerRows(ownerKey)).isEqualTo(1);

            provider.release();
            var results = collect(futures);
            assertThat(results)
                    .filteredOn(result -> result.error() != null)
                    .extracting(result -> result.error().code())
                    .containsExactly("generation_in_progress");
            assertThat(results).filteredOn(CallResult::succeeded).hasSize(1);
            var replacementId = results.stream()
                    .filter(CallResult::succeeded)
                    .findFirst()
                    .orElseThrow()
                    .row()
                    .generatedContentId();
            assertThat(replacementId).isNotEqualTo(expired.generatedContentId());
            assertThat(jdbcTemplate.query(
                    """
                    select generated_content_id, status
                    from practice_generated_content
                    where owner_key = ?
                    order by generated_content_id
                    """,
                    (rows, rowNumber) -> new PersistedContentRow(rows.getString(1), rows.getString(2)),
                    ownerKey))
                    .containsExactly(new PersistedContentRow(replacementId, "active"));
            assertThat(jdbcTemplate.queryForObject(
                    "select count(*) from practice_generated_content where generated_content_id = ?",
                    Integer.class,
                    expired.generatedContentId())).isZero();
        }
    }

    @Test
    void terminalRowIsNeverReusedAndSameFingerprintCreatesFreshActiveContent() {
        var request = request("洗澡前宝宝有点紧张");
        var terminalId = createExpiredTerminal(request);
        moveTerminalOutsideBurstWindow(terminalId);
        provider.reset(false);

        var replacement = service.generateCustomScene(request);

        assertThat(replacement.generatedContentId()).isNotEqualTo(terminalId);
        assertThat(replacement.status()).isEqualTo("active");
        assertThat(provider.callCount()).isEqualTo(1);
        assertThat(jdbcTemplate.query(
                "select status from practice_generated_content where owner_key = ? order by created_at",
                (rows, rowNumber) -> rows.getString(1),
                ownerKey(INSTALLATION_ID)))
                .containsExactly("expired", "active");
    }

    @Test
    void concurrentInstallationCleanupDeletesExpiredTerminalRowOnce() throws Exception {
        var terminalId = createExpiredTerminal(request("洗澡前宝宝有点紧张"));
        expireTerminalForCleanup(terminalId);
        var barrier = new CyclicBarrier(2);
        var executor = Executors.newFixedThreadPool(2);
        executors.add(executor);

        var first = executor.submit(() -> cleanupAfterBarrier(barrier));
        var second = executor.submit(() -> cleanupAfterBarrier(barrier));

        assertThat(first.get(5, TimeUnit.SECONDS) + second.get(5, TimeUnit.SECONDS)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where generated_content_id = ?",
                Integer.class,
                terminalId)).isZero();
    }

    @Test
    void concurrentStaleCleanupCompletesStartedProviderCallOnce() throws Exception {
        var cleanupAt = OffsetDateTime.now(ZoneOffset.UTC);
        var stale = reserveStaleGeneratingContent(cleanupAt);
        var attemptId = UUID.randomUUID();
        var operationId = UUID.randomUUID();
        var providerCallId = UUID.randomUUID();
        insertStartedAttempt(attemptId, stale.generatedContentId(), cleanupAt.minusMinutes(2));
        insertStartedOperation(operationId, stale.generatedContentId(), cleanupAt.minusMinutes(2));
        insertStartedProviderCall(providerCallId, operationId, cleanupAt.minusMinutes(2));
        var barrier = new CyclicBarrier(2);
        var executor = Executors.newFixedThreadPool(2);
        executors.add(executor);

        var first = executor.submit(() -> expireStaleAfterBarrier(barrier, cleanupAt));
        var second = executor.submit(() -> expireStaleAfterBarrier(barrier, cleanupAt));

        assertThat(first.get(5, TimeUnit.SECONDS) + second.get(5, TimeUnit.SECONDS)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForMap("""
                select status, normalized_scene_text
                from practice_generated_content where generated_content_id = ?
                """, stale.generatedContentId()))
                .containsEntry("status", "expired")
                .containsEntry("normalized_scene_text", null);
        assertThat(jdbcTemplate.queryForMap("""
                select status, outcome from practice_generated_content_attempts where attempt_id = ?
                """, attemptId))
                .containsEntry("status", "interrupted")
                .containsEntry("outcome", "interrupted");
        assertThat(jdbcTemplate.queryForMap("""
                select status, outcome from practice_ai_operation_runs where operation_run_id = ?
                """, operationId))
                .containsEntry("status", "interrupted")
                .containsEntry("outcome", "interrupted");
        assertThat(jdbcTemplate.queryForMap("""
                select outcome from practice_ai_provider_calls where provider_call_id = ?
                """, providerCallId))
                .containsEntry("outcome", "interrupted");
        assertThat(jdbcTemplate.queryForObject("""
                select count(*) from practice_ai_provider_calls
                where provider_call_id = ? and outcome = 'interrupted' and completed_at is not null
                """, Integer.class, providerCallId)).isEqualTo(1);
    }

    @Test
    void providerRunsOnlyAfterReservationTransactionCommitsAndUnlocksOwner() {
        var result = service.generateCustomScene(request("洗澡前宝宝有点紧张"));

        assertThat(result.status()).isEqualTo("active");
        assertThat(provider.callCount()).isEqualTo(1);
        assertThat(provider.allReservedRowsWereVisible()).isTrue();
        assertThat(provider.ownerLockWasAvailableForEveryCall()).isTrue();
    }

    private List<Future<CallResult>> startConcurrentCalls(
            PracticeGeneratedContentService.CustomSceneDiscoveryRequest first,
            PracticeGeneratedContentService.CustomSceneDiscoveryRequest second
    ) {
        var barrier = new CyclicBarrier(2);
        var executor = Executors.newFixedThreadPool(2);
        executors.add(executor);
        return List.of(
                executor.submit(() -> callAfterBarrier(barrier, first)),
                executor.submit(() -> callAfterBarrier(barrier, second)));
    }

    private CallResult callAfterBarrier(
            CyclicBarrier barrier,
            PracticeGeneratedContentService.CustomSceneDiscoveryRequest request
    ) throws Exception {
        barrier.await(5, TimeUnit.SECONDS);
        try {
            return new CallResult(service.generateCustomScene(request), null);
        } catch (ContractException error) {
            return new CallResult(null, error);
        }
    }

    private List<CallResult> collect(List<Future<CallResult>> futures) throws Exception {
        var results = new ArrayList<CallResult>();
        for (var future : futures) {
            results.add(future.get(10, TimeUnit.SECONDS));
        }
        return results;
    }

    private Connection holdOwnerLock(String ownerKey) throws SQLException {
        var connection = dataSource.getConnection();
        connection.setAutoCommit(false);
        try (var statement = connection.prepareStatement(
                "select pg_advisory_xact_lock(hashtextextended(?, 0))")) {
            statement.setString(1, "v1:" + ownerKey);
            statement.execute();
        }
        return connection;
    }

    private void awaitAdvisoryWaiters(Connection heldOwnerLock, int expected) {
        awaitCondition(() -> {
            try (var statement = heldOwnerLock.prepareStatement(
                    "select count(*) from pg_locks where locktype = 'advisory' and not granted")) {
                try (var rows = statement.executeQuery()) {
                    rows.next();
                    return rows.getInt(1) >= expected;
                }
            } catch (SQLException exception) {
                throw new IllegalStateException("test could not inspect advisory waiters", exception);
            }
        });
    }

    private void awaitCompletedCalls(List<Future<CallResult>> futures, int expected) {
        awaitCondition(() -> futures.stream().filter(Future::isDone).count() >= expected);
    }

    private void awaitCondition(java.util.function.BooleanSupplier condition) {
        var deadline = System.nanoTime() + Duration.ofSeconds(5).toNanos();
        while (!condition.getAsBoolean() && System.nanoTime() < deadline) {
            LockSupport.parkNanos(Duration.ofMillis(10).toNanos());
        }
        assertThat(condition.getAsBoolean()).isTrue();
    }

    private int countOwnerRows(String ownerKey) {
        return jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where owner_key = ?",
                Integer.class,
                ownerKey);
    }

    private PracticeGeneratedContentService.CustomSceneDiscoveryRequest request(String sceneText) {
        return new PracticeGeneratedContentService.CustomSceneDiscoveryRequest(
                "onboarding",
                "custom_scene",
                INSTALLATION_ID,
                null,
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                sceneText);
    }

    private PracticeGeneratedContentService.CustomSceneDiscoveryRequest carePathRequest(
            String installationId,
            String clientRequestId,
            String sceneText
    ) {
        return new PracticeGeneratedContentService.CustomSceneDiscoveryRequest(
                "care_path",
                "custom_scene",
                installationId,
                null,
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                sceneText,
                clientRequestId);
    }

    private String ownerKey(String installationId) {
        return keyFactory.ownerKey("installation", installationId);
    }

    private String createExpiredTerminal(PracticeGeneratedContentService.CustomSceneDiscoveryRequest request) {
        provider.failNext();
        assertThatThrownBy(() -> service.generateCustomScene(request))
                .isInstanceOf(ContractException.class);
        return jdbcTemplate.queryForObject(
                "select generated_content_id from practice_generated_content where owner_key = ? and status = 'expired'",
                String.class,
                ownerKey(INSTALLATION_ID));
    }

    private void expireTerminalForCleanup(String generatedContentId) {
        jdbcTemplate.update(
                """
                update practice_generated_content
                set retention_expires_at = now() - interval '1 minute',
                    updated_at = now()
                where generated_content_id = ?
                """,
                generatedContentId);
    }

    private void moveTerminalOutsideBurstWindow(String generatedContentId) {
        jdbcTemplate.update(
                """
                update practice_generated_content
                set created_at = now() - interval '11 minutes',
                    updated_at = now()
                where generated_content_id = ?
                """,
                generatedContentId);
    }

    private int cleanupAfterBarrier(CyclicBarrier barrier) throws Exception {
        barrier.await(5, TimeUnit.SECONDS);
        return service.deleteExpiredInstallationRows(java.time.OffsetDateTime.now(java.time.ZoneOffset.UTC), 10);
    }

    private int expireStaleAfterBarrier(CyclicBarrier barrier, OffsetDateTime cleanupAt) throws Exception {
        barrier.await(5, TimeUnit.SECONDS);
        return service.expireStaleDrafts(cleanupAt, 10);
    }

    private PracticeGeneratedContentEntity reserveStaleGeneratingContent(OffsetDateTime cleanupAt) {
        var draft = new PracticeGeneratedContentEntity();
        draft.setGeneratedContentId(STALE_CLEANUP_CONTENT_ID);
        draft.setOwnerScope("installation");
        draft.setOwnerKey(ownerKey(INSTALLATION_ID));
        draft.setOwnerKeyVersion("v1");
        draft.setInstallationRefHash("installation-concurrent-cleanup");
        draft.setSurface("onboarding");
        draft.setMode("custom_scene");
        draft.setRequestFingerprint("fingerprint-concurrent-stale-cleanup");
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
        draft.setGenerationExpiresAt(cleanupAt.minusMinutes(1));
        draft.setCreatedAt(cleanupAt.minusMinutes(10));
        draft.setUpdatedAt(cleanupAt.minusMinutes(10));
        var reserved = commands.reserveDraft(
                draft,
                new ReservationPolicy(cleanupAt, cleanupAt.minusMinutes(20), 10, cleanupAt.plusDays(7)));
        assertThat(commands.startGeneration(
                STALE_CLEANUP_CONTENT_ID, cleanupAt.minusDays(1), 10, cleanupAt.minusMinutes(2)))
                .isEqualTo(GenerationStartDecision.STARTED);
        return reserved.content();
    }

    private void insertStartedAttempt(UUID attemptId, String generatedContentId, OffsetDateTime startedAt) {
        jdbcTemplate.update("""
                insert into practice_generated_content_attempts (
                    attempt_id, generated_content_id, attempt_number, attempt_type, status, outcome,
                    violation_codes, started_at, completed_at
                ) values (?, ?, 1, 'generator', 'started', null, '{}', ?, null)
                """, attemptId, generatedContentId, startedAt);
    }

    private void insertStartedOperation(UUID operationId, String generatedContentId, OffsetDateTime startedAt) {
        jdbcTemplate.update("""
                insert into practice_ai_operation_runs (
                    operation_run_id, operation_type, subject_type, subject_id, generated_content_id,
                    attempt_number, evidence_bundle_id, capability_name, prompt_version, prompt_content_hash,
                    policy_version, policy_content_hash, status, outcome, started_at, completed_at
                ) values (?, 'generator', 'generated_content', ?, ?, 1, null, 'generation', 'profile-v1', ?,
                    null, null, 'started', null, ?, null)
                """, operationId, generatedContentId, generatedContentId, HASH, startedAt);
    }

    private void insertStartedProviderCall(UUID providerCallId, UUID operationId, OffsetDateTime startedAt) {
        jdbcTemplate.update("""
                insert into practice_ai_provider_calls (
                    provider_call_id, operation_run_id, provider_name, provider_type, model_name,
                    fallback_index, attempt_trace_id, provider_trace_id, routing_policy_version,
                    routing_policy_hash, outcome, latency_ms, started_at, completed_at
                ) values (?, ?, 'fake', 'fake', 'fake-model', 0, ?, null, 'routing-v1', ?,
                    'started', null, ?, null)
                """, providerCallId, operationId, UUID.randomUUID(), HASH, startedAt);
    }

    private record CallResult(
            com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity row,
            ContractException error
    ) {
        boolean succeeded() {
            return row != null;
        }
    }

    private record PersistedContentRow(String generatedContentId, String status) {
    }

    @TestConfiguration
    static class ProviderTestConfiguration {

        @Bean
        @Primary
        RecordingCustomSceneGenerator recordingCustomSceneGenerator(DataSource dataSource) {
            return new RecordingCustomSceneGenerator(dataSource);
        }
    }

    static class RecordingCustomSceneGenerator implements CustomSceneGenerator {

        private final DataSource dataSource;
        private final AtomicInteger calls = new AtomicInteger();
        private final AtomicBoolean allRowsVisible = new AtomicBoolean(true);
        private final AtomicBoolean allOwnerLocksAvailable = new AtomicBoolean(true);
        private final AtomicBoolean failNext = new AtomicBoolean();
        private volatile CountDownLatch entered = new CountDownLatch(1);
        private volatile CountDownLatch release = new CountDownLatch(0);

        RecordingCustomSceneGenerator(DataSource dataSource) {
            this.dataSource = dataSource;
        }

        void reset(boolean blockProvider) {
            calls.set(0);
            allRowsVisible.set(true);
            allOwnerLocksAvailable.set(true);
            failNext.set(false);
            entered = new CountDownLatch(1);
            release = new CountDownLatch(blockProvider ? 1 : 0);
        }

        @Override
        public GeneratedPracticeContentCandidate generate(GeneratorRequest request) {
            calls.incrementAndGet();
            verifyReservationCommittedAndUnlocked(request.generatedContentId());
            entered.countDown();
            try {
                if (!release.await(5, TimeUnit.SECONDS)) {
                    throw new IllegalStateException("test provider release timed out");
                }
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                throw new IllegalStateException("test provider interrupted", exception);
            }
            if (failNext.getAndSet(false)) {
                throw new CustomSceneGenerator.GenerationUnavailableException(
                        CustomSceneGenerator.GenerationUnavailableReason.PROVIDER_UNAVAILABLE);
            }
            if (request.displayText().contains("鞋")) {
                return candidate(
                        "出门穿鞋",
                        "Shoes on",
                        "拿起鞋子。",
                        "慢慢说一遍。",
                        "Shoes on.",
                        "穿鞋啦。",
                        "shoes on");
            }
            return candidate(
                    "洗澡安抚",
                    "Bath care",
                    "看着宝宝。",
                    "慢慢说一遍。",
                    "Warm water.",
                    "水暖暖的。",
                    "warm water");
        }

        private GeneratedPracticeContentCandidate candidate(
                String activityTitle,
                String sceneTag,
                String tprAction,
                String deliveryGuidance,
                String englishText,
                String chineseText,
                String pronunciationHint
        ) {
            return new GeneratedPracticeContentCandidate(
                    "日常照护",
                    activityTitle,
                    sceneTag,
                    tprAction,
                    deliveryGuidance,
                    englishText,
                    chineseText,
                    pronunciationHint,
                    "starter",
                    "fake");
        }

        private void verifyReservationCommittedAndUnlocked(String generatedContentId) {
            try (var connection = dataSource.getConnection()) {
                connection.setAutoCommit(false);
                String ownerLockKey;
                try (var statement = connection.prepareStatement(
                        "select owner_key_version, owner_key from practice_generated_content where generated_content_id = ?")) {
                    statement.setString(1, generatedContentId);
                    try (var rows = statement.executeQuery()) {
                        if (!rows.next()) {
                            allRowsVisible.set(false);
                            connection.rollback();
                            return;
                        }
                        ownerLockKey = rows.getString(1) + ":" + rows.getString(2);
                    }
                }
                try (var statement = connection.prepareStatement(
                        "select pg_try_advisory_xact_lock(hashtextextended(?, 0))")) {
                    statement.setString(1, ownerLockKey);
                    try (var rows = statement.executeQuery()) {
                        rows.next();
                        if (!rows.getBoolean(1)) {
                            allOwnerLocksAvailable.set(false);
                        }
                    }
                }
                connection.rollback();
            } catch (SQLException exception) {
                throw new IllegalStateException("test provider could not inspect reservation transaction", exception);
            }
        }

        boolean awaitEntered() throws InterruptedException {
            return entered.await(5, TimeUnit.SECONDS);
        }

        void failNext() {
            failNext.set(true);
        }

        void release() {
            release.countDown();
        }

        int callCount() {
            return calls.get();
        }

        boolean allReservedRowsWereVisible() {
            return allRowsVisible.get();
        }

        boolean ownerLockWasAvailableForEveryCall() {
            return allOwnerLocksAvailable.get();
        }
    }
}
