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

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.provider-mode=dev",
        "app.mentor.rate-limit-max-requests=1"
})
class MentorServiceTest extends AbstractIntegrationTest {

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
    void anonymousBlockedPromptReturnsFallbackAndWritesAuditTrail() {
        var response = mentorService.chat(
                new MentorService.ChatCommand(
                        "install-alpha",
                        "我已经很急了，想体罚一下怎么办？",
                        "home",
                        "single_turn",
                        "corr_blocked",
                        null
                ),
                null
        );

        assertThat(response.code()).isEqualTo("blocked_fallback");
        assertThat(response.phase()).isEqualTo("blocked_fallback");
        assertThat(response.fallbackUsed()).isTrue();
        assertThat(response.authenticated()).isFalse();
        assertThat(response.responseText()).contains("I'm here with you.");
        assertThat(response.rateLimit().remaining()).isZero();

        var turn = mentorService.findTurnByCorrelationId("corr_blocked");
        assertThat(turn).isNotNull();
        assertThat(turn.result()).isEqualTo("fallback");
        assertThat(turn.blockedFallback()).isTrue();

        var audits = mentorService.listAuditRowsByCorrelationId("corr_blocked");
        assertThat(audits)
                .extracting(MentorRepository.AuditRow::eventType)
                .containsExactly("chat_requested", "blocked_fallback");
    }

    @Test
    void validSessionHappyPathAssociatesAccountAndRedactsSensitiveRequestPreview() {
        var session = createSignedInSession("13800138000", "install-alpha");

        var response = mentorService.chat(
                new MentorService.ChatCommand(
                        "install-alpha",
                        "手机号 13800138000，session 是 sess_secret_token，验证码 246810，我现在不知道该怎么安抚。",
                        "garden",
                        "single_turn",
                        "corr_success",
                        "baby stage context"
                ),
                session.sessionId()
        );

        assertThat(response.code()).isEqualTo("ok");
        assertThat(response.fallbackUsed()).isFalse();
        assertThat(response.authenticated()).isTrue();

        var turn = mentorService.findTurnByCorrelationId("corr_success");
        assertThat(turn).isNotNull();
        assertThat(turn.accountIdHint()).isEqualTo(session.accountId());
        assertThat(turn.sessionIdHint()).isEqualTo(session.sessionId());
        assertThat(turn.requestSummary()).doesNotContain("13800138000");
        assertThat(turn.requestSummary()).doesNotContain("246810");
        assertThat(turn.requestSummary()).doesNotContain("sess_secret_token");
    }

    @Test
    void providerTimeoutWritesAuditAndThrowsStable504() {
        assertThatThrownBy(() -> mentorService.chat(
                new MentorService.ChatCommand(
                        "install-alpha",
                        "请给我一个建议 [timeout]",
                        "discover",
                        "single_turn",
                        "corr_timeout",
                        null
                ),
                null
        ))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.GATEWAY_TIMEOUT);
                    assertThat(contract.code()).isEqualTo("provider_timeout");
                    assertThat(contract.details()).containsEntry("phase", "provider_timeout");
                    assertThat(contract.details()).containsEntry("retryable", true);
                });

        assertThat(mentorService.countTurns()).isZero();
        var audits = mentorService.listAuditRowsByCorrelationId("corr_timeout");
        assertThat(audits)
                .extracting(MentorRepository.AuditRow::eventType)
                .containsExactly("chat_requested", "provider_timeout");
    }

    @Test
    void providerMalformedWritesAuditAndThrowsStable502() {
        assertThatThrownBy(() -> mentorService.chat(
                new MentorService.ChatCommand(
                        "install-alpha",
                        "请给我一个建议 [malformed]",
                        "growth",
                        "single_turn",
                        "corr_malformed",
                        null
                ),
                null
        ))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_GATEWAY);
                    assertThat(contract.code()).isEqualTo("provider_malformed_response");
                    assertThat(contract.details()).containsEntry("phase", "provider_malformed_response");
                });

        assertThat(mentorService.countTurns()).isZero();
        var audits = mentorService.listAuditRowsByCorrelationId("corr_malformed");
        assertThat(audits)
                .extracting(MentorRepository.AuditRow::eventType)
                .containsExactly("chat_requested", "provider_malformed_response");
    }

    @Test
    void rateLimitRejectsSecondRequestWithinWindow() {
        var first = mentorService.chat(
                new MentorService.ChatCommand(
                        "install-alpha",
                        "宝宝哭了我该怎么说",
                        "home",
                        "single_turn",
                        "corr_first",
                        null
                ),
                null
        );
        assertThat(first.code()).isEqualTo("ok");

        assertThatThrownBy(() -> mentorService.chat(
                new MentorService.ChatCommand(
                        "install-alpha",
                        "我再问一次",
                        "home",
                        "single_turn",
                        "corr_second",
                        null
                ),
                null
        ))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                    assertThat(contract.code()).isEqualTo("mentor_rate_limited");
                    assertThat(contract.details()).containsEntry("phase", "rate_limited");
                    assertThat(contract.details()).containsEntry("rateLimited", true);
                });

        assertThat(mentorService.countTurns()).isEqualTo(1);
        // 新逻辑：rate-limited 请求先 INSERT chat_requested 再 COUNT，所以会有
        // 第一个请求：chat_requested + chat_response_delivered = 2
        // 第二个请求：chat_requested + rate_limited = 2
        // 总计 4 条 audit
        assertThat(mentorService.countAuditRows()).isEqualTo(4);
    }

    private AuthConsentSyncService.SessionResponse createSignedInSession(String phoneNumber, String installationId) {
        var challenge = authConsentSyncService.createChallenge(phoneNumber);
        return authConsentSyncService.verifyChallenge(challenge.challengeId(), "246810", installationId);
    }
}
