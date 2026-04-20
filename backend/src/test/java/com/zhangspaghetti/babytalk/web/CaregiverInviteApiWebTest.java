package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/upgrade?channel=stable&source=version_gate",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.caregiver-invite.public-base-url=https://invite.example.com",
        "app.caregiver-invite.default-link-ttl=PT72H",
        "app.caregiver-invite.allowed-roles[0]=caregiver",
        "app.caregiver-invite.allowed-sources[0]=household_settings",
        "app.caregiver-invite.allowed-sources[1]=invite_banner",
        "app.caregiver-invite.allowed-sources[2]=invite_link",
        "app.caregiver-invite.open-app-targets.android=babytalk://invite/open",
        "app.caregiver-invite.open-app-targets.ios=babytalk://invite/open"
})
@AutoConfigureMockMvc
class CaregiverInviteApiWebTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void resetTables() {
        jdbcTemplate.execute("delete from caregiver_invite_events");
        jdbcTemplate.execute("delete from household_shared_context");
        jdbcTemplate.execute("delete from caregiver_invites");
        jdbcTemplate.execute("delete from household_members");
        jdbcTemplate.execute("delete from households");
        jdbcTemplate.execute("delete from share_landing_events");
        jdbcTemplate.execute("delete from share_landing_cards");
        jdbcTemplate.execute("delete from mentor_turns");
        jdbcTemplate.execute("delete from mentor_audit_logs");
        jdbcTemplate.execute("delete from release_distribution_events");
        jdbcTemplate.execute("delete from interaction_events");
        jdbcTemplate.execute("delete from consent_audit_logs");
        jdbcTemplate.execute("delete from sms_challenges");
        jdbcTemplate.execute("delete from account_sessions");
        jdbcTemplate.execute("delete from accounts");
    }

    @Test
    void createInviteAcceptInviteAndFetchSharedContextUseAccountLevelMemberships() throws Exception {
        var primary = createAcceptedSession("13800138000", "install-primary");
        syncEvent(primary.sessionId(), "install-primary", "evt_1", "daily_care", "bath_time", "bath_time_warm_water", "calm",
                "2026-04-09T02:00:00Z");
        syncEvent(primary.sessionId(), "install-primary", "evt_2", "daily_care", "bath_time", "bath_time_splash_splash", "engaged",
                "2026-04-09T02:01:00Z");

        var invite = createInvite(primary.sessionId(), "caregiver", "household_settings");
        assertThat(invite.inviteUrl()).isEqualTo("https://invite.example.com/invite/" + invite.token());

        var secondary = createAcceptedSession("13900139000", "install-secondary");
        var acceptResult = mockMvc.perform(post("/api/v1/caregiver-invites/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", secondary.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "token":"%s",
                                  "source":"invite_link"
                                }
                                """.formatted(invite.token())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.householdId").value(invite.householdId()))
                .andExpect(jsonPath("$.role").value("caregiver"))
                .andExpect(jsonPath("$.sharedContext.snapshot.practice.spaceId").value("daily_care"))
                .andExpect(jsonPath("$.sharedContext.snapshot.practice.activityId").value("bath_time"))
                .andExpect(jsonPath("$.sharedContext.snapshot.actor.role").value("primary_caregiver"))
                .andExpect(jsonPath("$.sharedContext.snapshot.actor.source").value("sync_event"))
                .andExpect(jsonPath("$.sharedContext.snapshot.actor.result").value("engaged"))
                .andExpect(jsonPath("$.sharedContext.snapshot.nextStep.spaceId").value("daily_care"))
                .andExpect(jsonPath("$.sharedContext.snapshot.nextStep.activityId").value("bath_time"))
                .andExpect(jsonPath("$.sharedContext.snapshot.nextStep.reason").value("latest_activity"))
                .andExpect(jsonPath("$.sharedContext.snapshot.babyProfileSummary").value(org.hamcrest.Matchers.containsString("已同步 2 条互动")))
                .andReturn();

        var acceptBody = acceptResult.getResponse().getContentAsString();
        assertThat(acceptBody)
                .doesNotContain("install-primary", "install-secondary")
                .doesNotContain(primary.sessionId(), secondary.sessionId());

        mockMvc.perform(get("/api/v1/household/shared-context")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", secondary.sessionId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.householdId").value(invite.householdId()))
                .andExpect(jsonPath("$.role").value("caregiver"))
                .andExpect(jsonPath("$.snapshot.continuitySummary").value(org.hamcrest.Matchers.containsString("bath_time")))
                .andExpect(jsonPath("$.snapshot.gardenSummary").value(org.hamcrest.Matchers.containsString("daily_care/bath_time")));

        assertThat(jdbcTemplate.queryForObject("select count(*) from households", Integer.class)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject("select count(*) from household_members", Integer.class)).isEqualTo(2);
        assertThat(jdbcTemplate.queryForObject(
                "select status from caregiver_invites where token = ?",
                String.class,
                invite.token()
        )).isEqualTo("accepted");

        var projectionColumns = jdbcTemplate.queryForMap(
                "select * from household_shared_context where household_id = ?",
                invite.householdId()
        ).keySet();
        assertThat(projectionColumns)
                .doesNotContain("child_name", "installation_id", "session_id", "raw_payload");

        var auditRows = jdbcTemplate.queryForList(
                "select entrypoint, result, failure_reason from caregiver_invite_events order by event_id asc"
        );
        assertThat(auditRows)
                .extracting(row -> row.get("entrypoint") + ":" + row.get("result"))
                .contains("create:create", "accept:accept");
    }

    @Test
    void caregiverCannotCreateInviteAndRoleDeniedIsAudited() throws Exception {
        var primary = createAcceptedSession("13800138000", "install-primary");
        syncEvent(primary.sessionId(), "install-primary", "evt_1", "daily_care", "bath_time", "bath_time_warm_water", "calm",
                "2026-04-09T02:00:00Z");
        var invite = createInvite(primary.sessionId(), "caregiver", "household_settings");

        var secondary = createAcceptedSession("13900139000", "install-secondary");
        mockMvc.perform(post("/api/v1/caregiver-invites/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", secondary.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "token":"%s",
                                  "source":"invite_link"
                                }
                                """.formatted(invite.token())))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/caregiver-invites")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", secondary.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "role":"caregiver",
                                  "source":"household_settings"
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("role_not_allowed"));

        var latestAudit = jdbcTemplate.queryForMap(
                "select entrypoint, result, failure_reason from caregiver_invite_events order by event_id desc limit 1"
        );
        assertThat(latestAudit)
                .containsEntry("entrypoint", "create")
                .containsEntry("result", "role_not_allowed")
                .containsEntry("failure_reason", "current_role_caregiver");
    }

    @Test
    void acceptInviteReturnsStableInvalidAndExpiredContracts() throws Exception {
        var primary = createAcceptedSession("13800138000", "install-primary");
        syncEvent(primary.sessionId(), "install-primary", "evt_1", "daily_care", "bath_time", "bath_time_warm_water", "calm",
                "2026-04-09T02:00:00Z");
        var invite = createInvite(primary.sessionId(), "caregiver", "household_settings");
        jdbcTemplate.update(
                "update caregiver_invites set expires_at = ? where token = ?",
                Timestamp.from(Instant.now().minus(1, ChronoUnit.HOURS)),
                invite.token()
        );

        var secondary = createAcceptedSession("13900139000", "install-secondary");

        mockMvc.perform(post("/api/v1/caregiver-invites/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", secondary.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "token":"bad*token",
                                  "source":"invite_link"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_invite_token"));

        mockMvc.perform(post("/api/v1/caregiver-invites/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", secondary.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "token":"missingToken123",
                                  "source":"invite_link"
                                }
                                """))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("invite_not_found"));

        mockMvc.perform(post("/api/v1/caregiver-invites/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", secondary.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "token":"%s",
                                  "source":"invite_link"
                                }
                                """.formatted(invite.token())))
                .andExpect(status().isGone())
                .andExpect(jsonPath("$.code").value("invite_expired"));

        var auditRows = jdbcTemplate.queryForList(
                "select result, failure_reason from caregiver_invite_events order by event_id asc"
        );
        assertThat(auditRows)
                .extracting(row -> row.get("result") + ":" + row.get("failure_reason"))
                .contains("invalid:token_not_found", "expired:token_expired");
    }

    @Test
    void acceptInviteReportsAlreadyUsedAndKeepsPendingInviteWhenSharedContextUnavailable() throws Exception {
        var primary = createAcceptedSession("13800138000", "install-primary");
        syncEvent(primary.sessionId(), "install-primary", "evt_1", "daily_care", "bath_time", "bath_time_warm_water", "calm",
                "2026-04-09T02:00:00Z");
        var usedInvite = createInvite(primary.sessionId(), "caregiver", "household_settings");
        var acceptedCaregiver = createAcceptedSession("13900139000", "install-secondary");
        mockMvc.perform(post("/api/v1/caregiver-invites/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", acceptedCaregiver.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "token":"%s",
                                  "source":"invite_link"
                                }
                                """.formatted(usedInvite.token())))
                .andExpect(status().isOk());

        var anotherCaregiver = createAcceptedSession("13700137000", "install-third");
        mockMvc.perform(post("/api/v1/caregiver-invites/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", anotherCaregiver.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "token":"%s",
                                  "source":"invite_link"
                                }
                                """.formatted(usedInvite.token())))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("invite_already_used"));

        var noContextPrimary = createAcceptedSession("13600136000", "install-fourth");
        var pendingInvite = createInvite(noContextPrimary.sessionId(), "caregiver", "household_settings");
        var noContextCaregiver = createAcceptedSession("13500135000", "install-fifth");

        mockMvc.perform(post("/api/v1/caregiver-invites/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", noContextCaregiver.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "token":"%s",
                                  "source":"invite_link"
                                }
                                """.formatted(pendingInvite.token())))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("shared_context_unavailable"));

        assertThat(jdbcTemplate.queryForObject(
                "select status from caregiver_invites where token = ?",
                String.class,
                pendingInvite.token()
        )).isEqualTo("pending");
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from household_members where account_id = ?",
                Integer.class,
                noContextCaregiver.accountId()
        )).isZero();

        var auditRows = jdbcTemplate.queryForList(
                "select result, failure_reason from caregiver_invite_events order by event_id asc"
        );
        assertThat(auditRows)
                .extracting(row -> row.get("result") + ":" + row.get("failure_reason"))
                .contains("already_used:token_already_used", "shared_context_unavailable:no_household_activity");
    }

    @Test
    void primaryCaregiverCanRevokeInviteAndPreventFutureAccept() throws Exception {
        var primary = createAcceptedSession("13800138000", "install-primary");
        syncEvent(primary.sessionId(), "install-primary", "evt_1", "daily_care", "bath_time", "bath_time_warm_water", "calm",
                "2026-04-09T02:00:00Z");
        var invite = createInvite(primary.sessionId(), "caregiver", "household_settings");

        mockMvc.perform(post("/api/v1/caregiver-invites/{token}/revoke", invite.token())
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", primary.sessionId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.applied").value(true))
                .andExpect(jsonPath("$.result").value("revoked"));

        var secondary = createAcceptedSession("13900139000", "install-secondary");
        mockMvc.perform(post("/api/v1/caregiver-invites/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", secondary.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "token":"%s",
                                  "source":"invite_link"
                                }
                                """.formatted(invite.token())))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("invite_revoked"));

        var auditRows = jdbcTemplate.queryForList(
                "select entrypoint, result, failure_reason from caregiver_invite_events order by event_id asc"
        );
        assertThat(auditRows)
                .extracting(row -> row.get("entrypoint") + ":" + row.get("result") + ":" + row.get("failure_reason"))
                .contains("revoke:revoked:invite_revoked", "accept:revoked:invite_revoked");
    }

    private SessionView createAcceptedSession(String phoneNumber, String installationId) throws Exception {
        var challengeId = createChallenge(phoneNumber);
        var session = verifyChallenge(challengeId, installationId);
        acceptConsent(session.sessionId());
        return session;
    }

    private String createChallenge(String phoneNumber) throws Exception {
        var result = mockMvc.perform(post("/api/v1/auth/challenges")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"phoneNumber":"%s"}
                                """.formatted(phoneNumber)))
                .andExpect(status().isCreated())
                .andReturn();
        return readJson(result.getResponse().getContentAsString()).get("challengeId").asText();
    }

    private SessionView verifyChallenge(String challengeId, String installationId) throws Exception {
        var result = mockMvc.perform(post("/api/v1/auth/verify")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "challengeId":"%s",
                                  "verificationCode":"246810",
                                  "installationId":"%s"
                                }
                                """.formatted(challengeId, installationId)))
                .andExpect(status().isOk())
                .andReturn();
        var json = readJson(result.getResponse().getContentAsString());
        return new SessionView(json.get("accountId").asText(), json.get("sessionId").asText());
    }

    private void acceptConsent(String sessionId) throws Exception {
        mockMvc.perform(post("/api/v1/consent/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", sessionId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"consentVersion":"pipl-v1"}
                                """))
                .andExpect(status().isOk());
    }

    private InviteView createInvite(String sessionId, String role, String source) throws Exception {
        var result = mockMvc.perform(post("/api/v1/caregiver-invites")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", sessionId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "role":"%s",
                                  "source":"%s"
                                }
                                """.formatted(role, source)))
                .andExpect(status().isCreated())
                .andReturn();
        var json = readJson(result.getResponse().getContentAsString());
        return new InviteView(
                json.get("householdId").asText(),
                json.get("token").asText(),
                json.get("inviteUrl").asText()
        );
    }

    private void syncEvent(
            String sessionId,
            String installationId,
            String localEventId,
            String spaceId,
            String activityId,
            String phraseId,
            String reactionType,
            String clientTimestamp
    ) throws Exception {
        mockMvc.perform(post("/api/v1/sync/events")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", sessionId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"%s",
                                  "events":[
                                    {
                                      "eventKey":"%s:%s",
                                      "localEventId":"%s",
                                      "installationId":"%s",
                                      "spaceId":"%s",
                                      "activityId":"%s",
                                      "phraseId":"%s",
                                      "reactionType":"%s",
                                      "clientTimestamp":"%s"
                                    }
                                  ]
                                }
                                """.formatted(
                                installationId,
                                installationId,
                                localEventId,
                                localEventId,
                                installationId,
                                spaceId,
                                activityId,
                                phraseId,
                                reactionType,
                                clientTimestamp
                        )))
                .andExpect(status().isOk());
    }

    private JsonNode readJson(String rawJson) throws Exception {
        return objectMapper.readTree(rawJson);
    }

    private record SessionView(String accountId, String sessionId) {
    }

    private record InviteView(String householdId, String token, String inviteUrl) {
    }
}
