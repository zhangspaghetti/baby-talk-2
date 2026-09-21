package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.provider-mode=dev",
        "app.mentor.rate-limit-max-requests=5"
})
class MentorSafetyAuditTest extends AbstractIntegrationTest {

    private static final String SAFETY_TEXT =
            "你描述的是宝宝的健康问题。仅凭这段描述，无法判断原因或严重程度，请联系儿科医生进行评估。";

    @Autowired
    private MentorService mentorService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @MockitoBean
    private MentorProvider mentorProvider;

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
    void healthSafetyProviderResponseIsPersistedAsRedactedSafetyAudit() {
        when(mentorProvider.respond(any())).thenReturn(
                new MentorProvider.ProviderResponse(SAFETY_TEXT, "fixed health safety response", true));
        var privatePrompt = "宝宝拉肚子，私密病例编号 health-secret-123";

        var response = mentorService.chat(
                new MentorService.ChatCommand(
                        "install-health-audit",
                        privatePrompt,
                        "home",
                        "single_turn",
                        "corr-health-audit",
                        null,
                        null,
                        18),
                null);

        assertThat(response.code()).isEqualTo("health_safety");
        assertThat(response.phase()).isEqualTo("health_safety");
        assertThat(response.fallbackUsed()).isTrue();

        var turn = mentorService.findTurnByCorrelationId("corr-health-audit");
        assertThat(turn).isNotNull();
        assertThat(turn.result()).isEqualTo("fallback");
        assertThat(turn.phase()).isEqualTo("health_safety");
        assertThat(turn.blockedFallback()).isTrue();
        assertThat(turn.requestSummary()).doesNotContain(privatePrompt, "health-secret-123");

        var audits = mentorService.listAuditRowsByCorrelationId("corr-health-audit");
        assertThat(audits)
                .extracting(MentorRepository.AuditRow::eventType)
                .containsExactly("chat_requested", "health_safety_fallback");
        var safetyAudit = audits.get(1);
        assertThat(safetyAudit.phase()).isEqualTo("health_safety");
        assertThat(safetyAudit.result()).isEqualTo("fallback");
        assertThat(safetyAudit.failureCode()).isEqualTo("health_safety");
        assertThat(safetyAudit.reason()).isEqualTo("health_safety_policy_triggered");
        assertThat(safetyAudit.requestSummary()).doesNotContain(privatePrompt, "health-secret-123");
        assertThat(safetyAudit.responseSummary()).doesNotContain(privatePrompt, "health-secret-123");
    }
}
