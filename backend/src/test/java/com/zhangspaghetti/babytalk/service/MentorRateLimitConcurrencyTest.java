package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.web.ContractException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * 并发测试：验证 MentorService rate limit 的 TOCTOU 竞态修复。
 * 多个线程同时对同一 installationId 发送 chat 请求，
 * insert-first-then-count 原子策略保证不超过 rateLimitMaxRequests 个成功。
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:mentor-rate-limit-concurrency-test;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_UPPER=false",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.provider-mode=dev",
        "app.mentor.rate-limit-max-requests=3"
})
class MentorRateLimitConcurrencyTest {

    private static final int CONCURRENT_THREADS = 6;
    private static final int RATE_LIMIT = 3;
    private static final String DEV_CODE = "246810";
    private static final String PHONE_NUMBER = "13800138001";
    private static final String INSTALLATION_ID = "install-rate-limit-test";

    @Autowired
    private MentorService mentorService;

    @Autowired
    private AuthConsentSyncService authConsentSyncService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void resetTables() {
        jdbcTemplate.execute("delete from mentor_turns");
        jdbcTemplate.execute("delete from mentor_audit_logs");
        jdbcTemplate.execute("delete from interaction_events");
        jdbcTemplate.execute("delete from consent_audit_logs");
        jdbcTemplate.execute("delete from sms_challenges");
        jdbcTemplate.execute("delete from account_sessions");
        jdbcTemplate.execute("delete from accounts");
    }

    @Test
    void atMostRateLimitRequestsSucceedUnderConcurrency() throws Exception {
        // 创建已认证 session
        var challenge = authConsentSyncService.createChallenge(PHONE_NUMBER);
        var session = authConsentSyncService.verifyChallenge(
                challenge.challengeId(), DEV_CODE, INSTALLATION_ID);

        var barrier = new CyclicBarrier(CONCURRENT_THREADS);
        ExecutorService executor = Executors.newFixedThreadPool(CONCURRENT_THREADS);

        List<Future<ChatResult>> futures = new ArrayList<>();
        for (int i = 0; i < CONCURRENT_THREADS; i++) {
            final int index = i;
            futures.add(executor.submit(() -> {
                barrier.await(); // 所有线程同时起跑
                try {
                    var response = mentorService.chat(
                            new MentorService.ChatCommand(
                                    INSTALLATION_ID,
                                    "宝宝哭了我该怎么安抚 第" + index + "次",
                                    "home",
                                    "single_turn",
                                    "corr_concurrent_" + index,
                                    null
                            ),
                            session.sessionId()
                    );
                    return new ChatResult(response, null);
                } catch (ContractException e) {
                    return new ChatResult(null, e);
                }
            }));
        }

        // 收集结果
        List<ChatResult> results = new ArrayList<>();
        for (var future : futures) {
            results.add(future.get());
        }
        executor.shutdown();

        // 最多 RATE_LIMIT 个成功
        List<ChatResult> successes = results.stream()
                .filter(r -> r.response != null)
                .toList();
        assertThat(successes)
                .as("最多 %d 个 chat 请求应成功", RATE_LIMIT)
                .hasSizeLessThanOrEqualTo(RATE_LIMIT);

        // 至少有一些成功
        assertThat(successes)
                .as("至少应有 1 个 chat 请求成功")
                .isNotEmpty();

        // 失败的全部是 rate_limited
        List<ChatResult> failures = results.stream()
                .filter(r -> r.error != null)
                .toList();
        assertThat(failures)
                .as("被拒绝的请求数 = 总数 - 成功数")
                .hasSize(CONCURRENT_THREADS - successes.size());
        for (var failure : failures) {
            assertThat(failure.error.code())
                    .as("被拒绝的请求错误码应为 mentor_rate_limited")
                    .isEqualTo("mentor_rate_limited");
            assertThat(failure.error.status().value())
                    .as("被拒绝的请求 HTTP 状态应为 429")
                    .isEqualTo(429);
        }

        // 审计链校验：每个请求都有 chat_requested，被拒绝的额外有 rate_limited
        int chatRequestedCount = jdbcTemplate.queryForObject(
                "select count(*) from mentor_audit_logs where event_type = 'chat_requested'",
                Integer.class
        );
        int rateLimitedCount = jdbcTemplate.queryForObject(
                "select count(*) from mentor_audit_logs where event_type = 'rate_limited'",
                Integer.class
        );

        // 所有请求（成功 + 失败）都先插入 chat_requested
        assertThat(chatRequestedCount)
                .as("所有 %d 个请求都应有 chat_requested audit 行", CONCURRENT_THREADS)
                .isEqualTo(CONCURRENT_THREADS);

        // rate_limited 行数应等于失败数
        assertThat(rateLimitedCount)
                .as("rate_limited audit 行数应等于被拒绝的请求数")
                .isEqualTo(failures.size());

        // turn 数应等于成功数
        int turnCount = jdbcTemplate.queryForObject(
                "select count(*) from mentor_turns",
                Integer.class
        );
        assertThat(turnCount)
                .as("turn 数应等于成功的请求数")
                .isEqualTo(successes.size());
    }

    @Test
    void sequentialRequestsRespectRateLimit() {
        // 顺序发送 RATE_LIMIT + 1 个请求
        List<ChatResult> results = new ArrayList<>();
        for (int i = 0; i < RATE_LIMIT + 1; i++) {
            try {
                var response = mentorService.chat(
                        new MentorService.ChatCommand(
                                INSTALLATION_ID,
                                "宝宝哭了我该怎么安抚 第" + i + "次",
                                "home",
                                "single_turn",
                                "corr_seq_" + i,
                                null
                        ),
                        null
                );
                results.add(new ChatResult(response, null));
            } catch (ContractException e) {
                results.add(new ChatResult(null, e));
            }
        }

        // 前 RATE_LIMIT 个成功
        for (int i = 0; i < RATE_LIMIT; i++) {
            assertThat(results.get(i).response)
                    .as("第 %d 个请求应成功", i + 1)
                    .isNotNull();
            assertThat(results.get(i).response.code()).isEqualTo("ok");
        }

        // 最后一个被拒绝
        assertThat(results.get(RATE_LIMIT).error)
                .as("第 %d 个请求应被 rate limit 拒绝", RATE_LIMIT + 1)
                .isNotNull();
        assertThat(results.get(RATE_LIMIT).error.code())
                .isEqualTo("mentor_rate_limited");

        // rate_limited 审计行准确反映拒绝原因
        int rateLimitedCount = jdbcTemplate.queryForObject(
                "select count(*) from mentor_audit_logs where event_type = 'rate_limited'",
                Integer.class
        );
        assertThat(rateLimitedCount)
                .as("应恰好有 1 条 rate_limited 审计行")
                .isEqualTo(1);

        // 验证 rate_limited 行的 reason 字段
        String reason = jdbcTemplate.queryForObject(
                "select reason from mentor_audit_logs where event_type = 'rate_limited'",
                String.class
        );
        assertThat(reason).isEqualTo("installation_window_limit_exceeded");
    }

    private record ChatResult(
            MentorService.ChatResponse response,
            ContractException error
    ) {
    }
}
