package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGenerationService;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.sql.Connection;
import java.sql.SQLException;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
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

    @Autowired
    private PracticeGeneratedContentService service;

    @Autowired
    private PracticeGeneratedContentKeyFactory keyFactory;

    @Autowired
    private RecordingCustomSceneGenerationService provider;

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

    private String ownerKey(String installationId) {
        return keyFactory.ownerKey("installation", installationId);
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
        RecordingCustomSceneGenerationService recordingCustomSceneGenerationService(DataSource dataSource) {
            return new RecordingCustomSceneGenerationService(dataSource);
        }
    }

    static class RecordingCustomSceneGenerationService implements CustomSceneGenerationService {

        private final DataSource dataSource;
        private final AtomicInteger calls = new AtomicInteger();
        private final AtomicBoolean allRowsVisible = new AtomicBoolean(true);
        private final AtomicBoolean allOwnerLocksAvailable = new AtomicBoolean(true);
        private volatile CountDownLatch entered = new CountDownLatch(1);
        private volatile CountDownLatch release = new CountDownLatch(0);

        RecordingCustomSceneGenerationService(DataSource dataSource) {
            this.dataSource = dataSource;
        }

        void reset(boolean blockProvider) {
            calls.set(0);
            allRowsVisible.set(true);
            allOwnerLocksAvailable.set(true);
            entered = new CountDownLatch(1);
            release = new CountDownLatch(blockProvider ? 1 : 0);
        }

        @Override
        public GeneratedPracticeContentCandidate generateCustomSceneStarter(CustomSceneGenerationRequest request) {
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
            if (request.canonicalSceneText().contains("鞋")) {
                return candidate(
                        "出门穿鞋",
                        "Shoes on",
                        "拿起鞋子，慢慢说一遍。",
                        "Shoes on.",
                        "穿鞋啦。",
                        "shoes on");
            }
            return candidate(
                    "洗澡安抚",
                    "Bath care",
                    "看着宝宝，慢慢说一遍。",
                    "Warm water.",
                    "水暖暖的。",
                    "warm water");
        }

        private GeneratedPracticeContentCandidate candidate(
                String activityTitle,
                String sceneTag,
                String coachTip,
                String englishText,
                String chineseText,
                String pronunciationHint
        ) {
            return new GeneratedPracticeContentCandidate(
                    "日常照护",
                    activityTitle,
                    sceneTag,
                    coachTip,
                    englishText,
                    chineseText,
                    pronunciationHint,
                    "starter",
                    "fake",
                    "test_provider_trace",
                    null,
                    "test-recording-provider");
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
