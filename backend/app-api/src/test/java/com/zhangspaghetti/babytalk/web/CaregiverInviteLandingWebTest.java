package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.service.SensitiveAuthDataProtector;
import com.zhangspaghetti.babytalk.service.CaregiverInviteService;
import com.zhangspaghetti.babytalk.service.DistributionService;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
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
class CaregiverInviteLandingWebTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private SensitiveAuthDataProtector sensitiveAuthDataProtector;

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
        jdbcTemplate.execute("delete from release_distribution_events");
        jdbcTemplate.execute("delete from mentor_turns");
        jdbcTemplate.execute("delete from mentor_audit_logs");
        jdbcTemplate.execute("delete from interaction_events");
        jdbcTemplate.execute("delete from consent_audit_logs");
        jdbcTemplate.execute("delete from sms_challenges");
        jdbcTemplate.execute("delete from account_sessions");
        jdbcTemplate.execute("delete from accounts");
    }

    @Test
    void landingRendersInviteHtmlHeadersAndWritesPageViewAudit() throws Exception {
        var primary = createAcceptedSession("13800138000", "install-primary");
        var invite = createInvite(primary.accessToken(), "caregiver", "household_settings");

        var landing = mockMvc.perform(get("/invite/{token}", invite.token())
                        .header("User-Agent", "Mozilla/5.0 (Linux; Android 14)"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.TEXT_HTML))
                .andExpect(header().string(CaregiverInviteService.RESULT_HEADER, "page_view"))
                .andExpect(header().string(CaregiverInviteService.AUDIT_HEADER, "recorded"))
                .andExpect(header().string(CaregiverInviteService.FAILURE_REASON_HEADER, ""))
                .andExpect(content().string(containsString("加入 Baby Talk 协作照护")))
                .andExpect(content().string(containsString("property=\"og:title\"")))
                .andExpect(content().string(containsString("邀请角色")))
                .andExpect(content().string(containsString("/invite/" + invite.token() + "/open-app?platform=android")))
                .andExpect(content().string(containsString("/invite/" + invite.token() + "/download?platform=android")))
                .andReturn();

        assertThat(landing.getResponse().getContentAsString())
                .doesNotContain(primary.sessionId())
                .doesNotContain("install-primary")
                .doesNotContain("babyProfileSummary");

        var events = listInviteEvents();
        assertThat(events)
                .extracting(event -> event.get("entrypoint") + ":" + event.get("result"))
                .containsExactly("create:create", "landing:page_view");
    }

    @Test
    void landingStaysPublicEvenWhenInvalidBearerHeaderIsPresent() throws Exception {
        var primary = createAcceptedSession("13800138000", "install-primary");
        var invite = createInvite(primary.accessToken(), "caregiver", "household_settings");

        mockMvc.perform(get("/invite/{token}", invite.token())
                        .header(HttpHeaders.AUTHORIZATION, "Bearer not-a-real-jwt")
                        .header("User-Agent", "Mozilla/5.0 (Linux; Android 14)"))
                .andExpect(status().isOk())
                .andExpect(header().string(CaregiverInviteService.RESULT_HEADER, "page_view"))
                .andExpect(content().string(containsString("加入 Baby Talk 协作照护")));
    }

    @Test
    void invalidExpiredAlreadyUsedAndRevokedTokensRenderVisibleFailureStatesAndAuditRows() throws Exception {
        var primary = createAcceptedSession("13800138000", "install-primary");
        syncEvent(primary.accessToken(), "install-primary", "evt_1", "daily_care", "bath_time", "bath_time_warm_water", "cooperating",
                "2026-04-09T02:00:00Z");
        var expiredInvite = createInvite(primary.accessToken(), "caregiver", "household_settings");
        jdbcTemplate.update(
                "update caregiver_invites set expires_at = ? where token = ?",
                Timestamp.from(Instant.now().minus(1, ChronoUnit.HOURS)),
                inviteLookupRef(expiredInvite.token())
        );

        var usedInvite = createInvite(primary.accessToken(), "caregiver", "household_settings");
        var secondary = createAcceptedSession("13900139000", "install-secondary");
        acceptInvite(secondary.accessToken(), usedInvite.token());

        var revokedInvite = createInvite(primary.accessToken(), "caregiver", "household_settings");
        mockMvc.perform(post("/api/v1/caregiver-invites/{token}/revoke", revokedInvite.token())
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(primary.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.result").value("revoked"));

        mockMvc.perform(get("/invite/{token}", "missingToken123"))
                .andExpect(status().isNotFound())
                .andExpect(header().string(CaregiverInviteService.RESULT_HEADER, "invalid"))
                .andExpect(header().string(CaregiverInviteService.FAILURE_REASON_HEADER, "token_not_found"))
                .andExpect(content().string(containsString("邀请链接不可用")));

        mockMvc.perform(get("/invite/{token}", expiredInvite.token()))
                .andExpect(status().isGone())
                .andExpect(header().string(CaregiverInviteService.RESULT_HEADER, "expired"))
                .andExpect(header().string(CaregiverInviteService.FAILURE_REASON_HEADER, "token_expired"))
                .andExpect(content().string(containsString("已过期")));

        mockMvc.perform(get("/invite/{token}", usedInvite.token()))
                .andExpect(status().isConflict())
                .andExpect(header().string(CaregiverInviteService.RESULT_HEADER, "already_used"))
                .andExpect(header().string(CaregiverInviteService.FAILURE_REASON_HEADER, "token_already_used"))
                .andExpect(content().string(containsString("已被使用")));

        mockMvc.perform(get("/invite/{token}", revokedInvite.token()))
                .andExpect(status().isConflict())
                .andExpect(header().string(CaregiverInviteService.RESULT_HEADER, "revoked"))
                .andExpect(header().string(CaregiverInviteService.FAILURE_REASON_HEADER, "invite_revoked"))
                .andExpect(content().string(containsString("已撤销")));

        var events = listInviteEvents();
        assertThat(events)
                .extracting(event -> event.get("result") + ":" + event.get("failure_reason"))
                .contains("invalid:token_not_found", "expired:token_expired", "already_used:token_already_used", "revoked:invite_revoked");
    }

    @Test
    void openAppAndDownloadFallbackAreControlledAndDistributionSourceIsReusable() throws Exception {
        var primary = createAcceptedSession("13800138000", "install-primary");
        var invite = createInvite(primary.accessToken(), "caregiver", "household_settings");

        mockMvc.perform(get("/invite/{token}/open-app", invite.token()).queryParam("platform", "android"))
                .andExpect(status().isFound())
                .andExpect(header().string(CaregiverInviteService.RESULT_HEADER, "open_app_redirect"))
                .andExpect(header().string(CaregiverInviteService.AUDIT_HEADER, "recorded"))
                .andExpect(header().string("Location", containsString("babytalk://invite/open")))
                .andExpect(header().string("Location", containsString("token=" + invite.token())))
                .andExpect(header().string("Location", containsString("source=household_settings")))
                .andExpect(header().string("Location", containsString("role=caregiver")));

        mockMvc.perform(get("/invite/{token}/download", invite.token()).queryParam("platform", "android"))
                .andExpect(status().isFound())
                .andExpect(header().string(CaregiverInviteService.RESULT_HEADER, "download_fallback"))
                .andExpect(redirectedUrl("/download?source=caregiver_invite&platform=android"));

        mockMvc.perform(get("/download")
                        .queryParam("source", "caregiver_invite")
                        .queryParam("platform", "android")
                        .header("User-Agent", "Mozilla/5.0 (Linux; Android 14)"))
                .andExpect(status().isOk())
                .andExpect(header().string(DistributionService.RESULT_HEADER, "page_view"))
                .andExpect(content().string(containsString("下载 Baby Talk")));

        var inviteEvents = listInviteEvents();
        assertThat(inviteEvents)
                .extracting(event -> event.get("result"))
                .contains("open_app_redirect", "download_fallback");

        var distributionEvents = listReleaseEvents();
        assertThat(distributionEvents)
                .extracting(event -> event.get("source") + ":" + event.get("result"))
                .contains("caregiver_invite:page_view");
    }

    @Test
    void missingOpenAppTargetUnknownPlatformAndAuditFailureStayVisible() throws Exception {
        var primary = createAcceptedSession("13800138000", "install-primary");
        var invite = createInvite(primary.accessToken(), "caregiver", "household_settings");

        mockMvc.perform(get("/invite/{token}/open-app", invite.token()))
                .andExpect(status().isServiceUnavailable())
                .andExpect(header().string(CaregiverInviteService.RESULT_HEADER, "unavailable"))
                .andExpect(header().string(CaregiverInviteService.AUDIT_HEADER, "recorded"))
                .andExpect(header().string(CaregiverInviteService.FAILURE_REASON_HEADER, "platform_unresolved"))
                .andExpect(content().string(containsString("暂时无法判断设备平台")));

        mockMvc.perform(get("/invite/{token}/open-app", invite.token()).queryParam("platform", "windows"))
                .andExpect(status().isBadRequest())
                .andExpect(header().string(CaregiverInviteService.RESULT_HEADER, "invalid"))
                .andExpect(header().string(CaregiverInviteService.FAILURE_REASON_HEADER, "unknown_platform"))
                .andExpect(content().string(containsString("无法继续打开 app")));

        jdbcTemplate.execute("alter table caregiver_invite_events rename to caregiver_invite_events_bak");
        try {
            mockMvc.perform(get("/invite/{token}", invite.token())
                            .header("User-Agent", "Mozilla/5.0 (Linux; Android 14)"))
                    .andExpect(status().isOk())
                    .andExpect(header().string(CaregiverInviteService.RESULT_HEADER, "page_view"))
                    .andExpect(header().string(CaregiverInviteService.AUDIT_HEADER, "failed"))
                    .andExpect(content().string(containsString("Baby Talk · caregiver invite")));
        } finally {
            jdbcTemplate.execute("alter table caregiver_invite_events_bak rename to caregiver_invite_events");
        }
    }

    private TokenView createAcceptedSession(String phoneNumber, String installationId) throws Exception {
        var challengeId = createChallenge(phoneNumber);
        var session = verifyChallenge(challengeId, installationId);
        acceptConsent(session.accessToken());
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

    private TokenView verifyChallenge(String challengeId, String installationId) throws Exception {
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
        return new TokenView(
                json.get("accountId").asText(),
                json.get("sessionId").asText(),
                json.get("accessToken").asText()
        );
    }

    private void acceptConsent(String accessToken) throws Exception {
        mockMvc.perform(post("/api/v1/consent/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"consentVersion":"pipl-v1"}
                                """))
                .andExpect(status().isOk());
    }

    private InviteView createInvite(String accessToken, String role, String source) throws Exception {
        var result = mockMvc.perform(post("/api/v1/caregiver-invites")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
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

    private void acceptInvite(String accessToken, String token) throws Exception {
        mockMvc.perform(post("/api/v1/caregiver-invites/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "token":"%s",
                                  "source":"invite_link"
                                }
                                """.formatted(token)))
                .andExpect(status().isOk());
    }

    private void syncEvent(
            String accessToken,
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
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
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

    private List<Map<String, Object>> listInviteEvents() {
        return jdbcTemplate.queryForList(
                """
                select entrypoint, result, failure_reason, source, requested_role, platform
                from caregiver_invite_events
                order by event_id asc
                """
        );
    }

    private List<Map<String, Object>> listReleaseEvents() {
        return jdbcTemplate.queryForList(
                """
                select entrypoint, source, platform, result, failure_reason
                from release_distribution_events
                order by event_id asc
                """
        );
    }

    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }

    private String inviteLookupRef(String rawToken) {
        return sensitiveAuthDataProtector.inviteTokenLookupRef(rawToken);
    }

    private record TokenView(String accountId, String sessionId, String accessToken) {
    }

    private record InviteView(String householdId, String token, String inviteUrl) {
    }
}
