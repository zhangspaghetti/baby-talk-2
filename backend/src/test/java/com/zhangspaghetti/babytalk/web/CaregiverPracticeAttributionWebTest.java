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
import java.time.OffsetDateTime;
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
class CaregiverPracticeAttributionWebTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void resetTables() {
                resetDatabase(jdbcTemplate);
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
    void secondaryCaregiverPracticeRefreshesProjectionAndKeepsInteractionEventsAppendOnly() throws Exception {
        var primary = createAcceptedSession("13800138000", "install-primary");
        syncEvent(primary.sessionId(), "install-primary", "evt_1", "daily_care", "bath_time", "bath_time_warm_water", "calm",
                "2026-04-09T02:00:00Z");
        syncEvent(primary.sessionId(), "install-primary", "evt_2", "daily_care", "bath_time", "bath_time_splash_splash", "engaged",
                "2026-04-09T02:01:00Z");

        var invite = createInvite(primary.sessionId(), "caregiver", "household_settings");
        var caregiver = createAcceptedSession("13900139000", "install-secondary");
        mockMvc.perform(post("/api/v1/caregiver-invites/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", caregiver.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "token":"%s",
                                  "source":"invite_link"
                                }
                                """.formatted(invite.token())))
                .andExpect(status().isOk());

        var beforeRefresh = jdbcTemplate.queryForObject(
                "select updated_at from household_shared_context where household_id = ?",
                Timestamp.class,
                invite.householdId()
        ).toInstant();

        mockMvc.perform(post("/api/v1/sync/events")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", caregiver.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-secondary",
                                  "events":[
                                    {
                                      "eventKey":"install-secondary:evt_3",
                                      "localEventId":"evt_3",
                                      "installationId":"install-secondary",
                                      "spaceId":"sleep_support",
                                      "activityId":"bedtime_story",
                                      "phraseId":"bedtime_story_soft_voice",
                                      "reactionType":"needs_break",
                                      "clientTimestamp":"2026-04-09T02:05:00Z"
                                    }
                                  ]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acceptedCount").value(1));

        var response = mockMvc.perform(get("/api/v1/household/shared-context")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", primary.sessionId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.snapshot.practice.spaceId").value("sleep_support"))
                .andExpect(jsonPath("$.snapshot.practice.activityId").value("bedtime_story"))
                .andExpect(jsonPath("$.snapshot.actor.role").value("caregiver"))
                .andExpect(jsonPath("$.snapshot.actor.source").value("sync_event"))
                .andExpect(jsonPath("$.snapshot.actor.result").value("needs_break"))
                .andExpect(jsonPath("$.snapshot.nextStep.spaceId").value("daily_care"))
                .andExpect(jsonPath("$.snapshot.nextStep.activityId").value("bath_time"))
                .andExpect(jsonPath("$.snapshot.nextStep.reason").value("top_activity"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain("install-primary", "install-secondary")
                .doesNotContain(primary.sessionId(), caregiver.sessionId())
                .doesNotContain("bedtime_story_soft_voice");

        var projectionRow = jdbcTemplate.queryForMap(
                """
                select latest_interaction_at,
                       updated_at,
                       latest_actor_role,
                       latest_actor_source,
                       latest_actor_result,
                       next_step_space_id,
                       next_step_activity_id,
                       next_step_reason
                from household_shared_context
                where household_id = ?
                """,
                invite.householdId()
        );
        assertThat(toInstant(projectionRow.get("updated_at"))).isAfter(beforeRefresh);
        assertThat(toInstant(projectionRow.get("latest_interaction_at")))
                .isEqualTo(Instant.parse("2026-04-09T02:05:00Z"));
        assertThat(projectionRow)
                .containsEntry("latest_actor_role", "caregiver")
                .containsEntry("latest_actor_source", "sync_event")
                .containsEntry("latest_actor_result", "needs_break")
                .containsEntry("next_step_space_id", "daily_care")
                .containsEntry("next_step_activity_id", "bath_time")
                .containsEntry("next_step_reason", "top_activity");

        assertThat(jdbcTemplate.queryForObject("select count(*) from interaction_events", Integer.class)).isEqualTo(3);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from interaction_events where account_id = ?",
                Integer.class,
                caregiver.accountId()
        )).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject("select count(*) from household_shared_context", Integer.class)).isEqualTo(1);

        var projectionColumns = jdbcTemplate.queryForMap(
                "select * from household_shared_context where household_id = ?",
                invite.householdId()
        ).keySet();
        assertThat(projectionColumns)
                .doesNotContain("child_name", "installation_id", "session_id", "raw_payload");
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

    private Instant toInstant(Object value) {
        if (value instanceof Timestamp timestamp) {
            return timestamp.toInstant();
        }
        if (value instanceof OffsetDateTime offsetDateTime) {
            return offsetDateTime.toInstant();
        }
        if (value instanceof Instant instant) {
            return instant;
        }
        throw new IllegalArgumentException("Unsupported time value: " + value);
    }

    private record SessionView(String accountId, String sessionId) {
    }

    private record InviteView(String householdId, String token, String inviteUrl) {
    }
}
