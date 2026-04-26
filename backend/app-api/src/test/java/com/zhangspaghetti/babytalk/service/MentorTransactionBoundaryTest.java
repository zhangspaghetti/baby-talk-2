package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.web.ContractException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * 验证 MentorService.chat() 三阶段事务拆分后的行为：
 * <ul>
 *   <li>provider timeout/malformed/unavailable 场景下，阶段 1 的 chat_requested audit 已提交不会回滚</li>
 *   <li>正常成功场景下，turn 和 audit 全部正确写入</li>
 *   <li>ContractException（校验/session/rate limit）不回滚已写入的 audit 行</li>
 * </ul>
 */
@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.provider-mode=dev",
        "app.mentor.rate-limit-max-requests=5"
})
class MentorTransactionBoundaryTest extends AbstractIntegrationTest {

    @Autowired
    private MentorService mentorService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void resetTables() {
                resetDatabase(jdbcTemplate);
        jdbcTemplate.execute("delete from mentor_turns");
        jdbcTemplate.execute("delete from mentor_audit_logs");
        jdbcTemplate.execute("delete from interaction_events");
        jdbcTemplate.execute("delete from consent_audit_logs");
        jdbcTemplate.execute("delete from sms_challenges");
        jdbcTemplate.execute("delete from account_sessions");
        jdbcTemplate.execute("delete from accounts");
    }

    @Test
    void providerTimeoutDoesNotRollBackPhase1ChatRequestedAudit() {
        // provider timeout 时 chat_requested audit 行应已在阶段 1 提交，不会回滚
        assertThatThrownBy(() -> mentorService.chat(
                new MentorService.ChatCommand(
                        "install-tx-test",
                        "请给我一个建议 [timeout]",
                        "discover",
                        "single_turn",
                        "corr_tx_timeout",
                        null,
                        null
                ),
                null
        ))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.GATEWAY_TIMEOUT);
                    assertThat(contract.code()).isEqualTo("provider_timeout");
                });

        // 验证 chat_requested audit 仍然存在（阶段 1 已提交，不受 provider 异常影响）
        var audits = mentorService.listAuditRowsByCorrelationId("corr_tx_timeout");
        assertThat(audits)
                .extracting(MentorRepository.AuditRow::eventType)
                .containsExactly("chat_requested", "provider_timeout");

        // 验证没有 turn 写入（provider 失败，阶段 3 写的是 error audit 而非 turn）
        assertThat(mentorService.countTurns()).isZero();
    }

    @Test
    void providerMalformedDoesNotRollBackPhase1ChatRequestedAudit() {
        // provider malformed response 时 chat_requested audit 行应已在阶段 1 提交
        assertThatThrownBy(() -> mentorService.chat(
                new MentorService.ChatCommand(
                        "install-tx-test",
                        "请给我一个建议 [malformed]",
                        "growth",
                        "single_turn",
                        "corr_tx_malformed",
                        null,
                        null
                ),
                null
        ))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_GATEWAY);
                    assertThat(contract.code()).isEqualTo("provider_malformed_response");
                });

        var audits = mentorService.listAuditRowsByCorrelationId("corr_tx_malformed");
        assertThat(audits)
                .extracting(MentorRepository.AuditRow::eventType)
                .containsExactly("chat_requested", "provider_malformed_response");
        assertThat(mentorService.countTurns()).isZero();
    }

    @Test
    void successScenarioWritesTurnAndAllAuditsAcrossPhases() {
        // 正常成功场景：阶段 1 写 chat_requested，阶段 3 写 turn + response_delivered
        var response = mentorService.chat(
                new MentorService.ChatCommand(
                        "install-tx-test",
                        "宝宝刚学走路经常摔倒，我该怎么鼓励他？",
                        "home",
                        "single_turn",
                        "corr_tx_success",
                        "baby 14 months",
                        null
                ),
                null
        );

        assertThat(response.code()).isEqualTo("ok");
        assertThat(response.phase()).isEqualTo("response_delivered");
        assertThat(response.responseText()).isNotBlank();

        // 验证 turn 正确写入
        var turn = mentorService.findTurnByCorrelationId("corr_tx_success");
        assertThat(turn).isNotNull();
        assertThat(turn.result()).isEqualTo("success");
        assertThat(turn.phase()).isEqualTo("response_delivered");

        // 验证完整 audit 链：chat_requested（阶段 1）→ chat_response_delivered（阶段 3）
        var audits = mentorService.listAuditRowsByCorrelationId("corr_tx_success");
        assertThat(audits)
                .extracting(MentorRepository.AuditRow::eventType)
                .containsExactly("chat_requested", "chat_response_delivered");
    }

    @Test
    void rateLimitContractExceptionPreservesAllAuditRows() {
        // 先消耗 rate limit（配置为 5）
        for (int i = 1; i <= 5; i++) {
            mentorService.chat(
                    new MentorService.ChatCommand(
                            "install-rate-tx",
                            "第 " + i + " 个问题",
                            "home",
                            "single_turn",
                            "corr_rate_fill_" + i,
                            null,
                            null
                    ),
                    null
            );
        }

        // 第 6 个请求触发 rate limit — ContractException 不应回滚 chat_requested 和 rate_limited audit
        assertThatThrownBy(() -> mentorService.chat(
                new MentorService.ChatCommand(
                        "install-rate-tx",
                        "第六个问题",
                        "home",
                        "single_turn",
                        "corr_rate_limited",
                        null,
                        null
                ),
                null
        ))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                    assertThat(contract.code()).isEqualTo("mentor_rate_limited");
                });

        // 验证 rate_limited 请求的 audit 行都被保留（ContractException 没有回滚事务）
        var audits = mentorService.listAuditRowsByCorrelationId("corr_rate_limited");
        assertThat(audits)
                .extracting(MentorRepository.AuditRow::eventType)
                .containsExactly("chat_requested", "rate_limited");
    }
}
