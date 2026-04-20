package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.web.ContractException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * 并发测试：验证 verifyChallenge 的 TOCTOU 竞态修复。
 * 多个线程同时对同一个 pending challenge 调用 verifyChallenge，
 * 数据库原子 UPDATE（AND status='pending'）保证恰好 1 个成功，其余收到 CONFLICT。
 */
@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810"
})
class VerifyChallengeConcurrencyTest extends AbstractIntegrationTest {

    private static final int CONCURRENT_THREADS = 8;
    private static final String DEV_CODE = "246810";
    private static final String PHONE_NUMBER = "13900139000";

    @Autowired
    private AuthConsentSyncService service;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void resetTables() {
        jdbcTemplate.execute("delete from interaction_events");
        jdbcTemplate.execute("delete from consent_audit_logs");
        jdbcTemplate.execute("delete from sms_challenges");
        jdbcTemplate.execute("delete from account_sessions");
        jdbcTemplate.execute("delete from accounts");
    }

    @Test
    void exactlyOneVerifySucceedsUnderConcurrentRequests() throws Exception {
        // 创建一个 pending challenge
        var challenge = service.createChallenge(PHONE_NUMBER);
        var challengeId = challenge.challengeId();

        var barrier = new CyclicBarrier(CONCURRENT_THREADS);
        ExecutorService executor = Executors.newFixedThreadPool(CONCURRENT_THREADS);

        List<Future<VerifyResult>> futures = new ArrayList<>();
        for (int i = 0; i < CONCURRENT_THREADS; i++) {
            final String installationId = "install-concurrent-" + i;
            futures.add(executor.submit(() -> {
                barrier.await(); // 所有线程同时起跑
                try {
                    var session = service.verifyChallenge(challengeId, DEV_CODE, installationId);
                    return new VerifyResult(session, null);
                } catch (ContractException e) {
                    return new VerifyResult(null, e);
                }
            }));
        }

        // 收集结果
        List<VerifyResult> results = new ArrayList<>();
        for (var future : futures) {
            results.add(future.get());
        }
        executor.shutdown();

        // 恰好 1 个成功
        List<VerifyResult> successes = results.stream().filter(r -> r.session != null).toList();
        assertThat(successes)
                .as("恰好 1 个 verifyChallenge 调用应成功")
                .hasSize(1);

        // 其余全部失败，错误码为 challenge_already_verified
        List<VerifyResult> failures = results.stream().filter(r -> r.error != null).toList();
        assertThat(failures)
                .as("其余 %d 个调用应全部失败", CONCURRENT_THREADS - 1)
                .hasSize(CONCURRENT_THREADS - 1);
        for (var failure : failures) {
            assertThat(failure.error.code()).isEqualTo("challenge_already_verified");
        }

        // 数据库中只创建了 1 个 session
        int sessionCount = jdbcTemplate.queryForObject(
                "select count(*) from account_sessions",
                Integer.class
        );
        assertThat(sessionCount)
                .as("数据库中应恰好有 1 个 session")
                .isEqualTo(1);

        // challenge 状态为 verified
        String challengeStatus = jdbcTemplate.queryForObject(
                "select status from sms_challenges where challenge_id = ?",
                String.class,
                challengeId
        );
        assertThat(challengeStatus).isEqualTo("verified");
    }

    @Test
    void sequentialDoubleVerifyIsRejected() {
        // 创建并首次验证
        var challenge = service.createChallenge(PHONE_NUMBER);
        service.verifyChallenge(challenge.challengeId(), DEV_CODE, "install-first");

        // 第二次验证应被 CONFLICT 拒绝
        try {
            service.verifyChallenge(challenge.challengeId(), DEV_CODE, "install-second");
            assertThat(false).as("第二次 verifyChallenge 应抛出 ContractException").isTrue();
        } catch (ContractException e) {
            assertThat(e.code()).isEqualTo("challenge_already_verified");
            assertThat(e.status().value()).isEqualTo(409);
        }

        // 仍然只有 1 个 session
        int sessionCount = jdbcTemplate.queryForObject(
                "select count(*) from account_sessions",
                Integer.class
        );
        assertThat(sessionCount).isEqualTo(1);
    }

    private record VerifyResult(
            AuthConsentSyncService.SessionResponse session,
            ContractException error
    ) {
    }
}
