package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.startsWith;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.service.ShareLandingService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
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
        "app.share.landing.public-base-url=https://share.example.com",
        "app.share.landing.default-link-ttl=PT72H",
        "app.share.landing.allowed-sources[0]=latest_impact",
        "app.share.landing.allowed-sources[1]=continuity_recommendation",
        "app.share.landing.allowed-sources[2]=paired_progress",
        "app.share.landing.open-app-targets.android=babytalk://share/open",
        "app.share.landing.open-app-targets.ios=babytalk://share/open"
})
@AutoConfigureMockMvc
class ShareLinkApiWebTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void resetTables() {
                resetDatabase(jdbcTemplate);
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
    void createShareLinkReturnsTokenizedUrlAndPersistsOnlyRedactedSnapshot() throws Exception {
        var result = mockMvc.perform(post("/api/v1/share-links")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "source":"paired_progress",
                                  "platformHint":"android",
                                  "headline":"今晚洗澡时，她第一次主动说 warm water。",
                                  "storyText":"我们在浴室里重复了两次，宝宝笑着拍水回应。",
                                  "phraseText":"Warm water, please.",
                                  "phraseTranslation":"请给我温温的水。",
                                  "recommendationTitle":"睡前再重复一次这句短语",
                                  "recommendationReason":"趁今天记忆最鲜活时，再在睡前重复一次。",
                                  "spaceId":"daily_care",
                                  "activityId":"bath_time"
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(header().string(ShareLandingService.RESULT_HEADER, "create"))
                .andExpect(jsonPath("$.token").isString())
                .andExpect(jsonPath("$.shareUrl", startsWith("https://share.example.com/share/")))
                .andExpect(jsonPath("$.expiresAt").isString())
                .andReturn();

        var body = readJson(result.getResponse().getContentAsString());
        var token = body.get("token").asText();

        var snapshot = jdbcTemplate.queryForMap(
                """
                select token, source, headline, story_text, phrase_text, phrase_translation,
                       recommendation_title, recommendation_reason, space_id, activity_id, platform_hint
                from share_landing_cards
                where token = ?
                """,
                token
        );
        assertThat(snapshot)
                .containsEntry("token", token)
                .containsEntry("source", "paired_progress")
                .containsEntry("platform_hint", "android")
                .containsEntry("space_id", "daily_care")
                .containsEntry("activity_id", "bath_time");
        assertThat(snapshot.get("headline")).isEqualTo("今晚洗澡时，她第一次主动说 warm water。");
        assertThat(snapshot.get("phrase_text")).isEqualTo("Warm water, please.");

        var persistedColumns = jdbcTemplate.queryForMap(
                "select * from share_landing_cards where token = ?",
                token
        ).keySet();
        assertThat(persistedColumns)
                .doesNotContain("child_name", "installation_id", "event_key", "fallback_reason");

        var events = jdbcTemplate.queryForList(
                "select entrypoint, result, platform from share_landing_events order by event_id asc"
        );
        assertThat(events).hasSize(1);
        assertThat(events.get(0))
                .containsEntry("entrypoint", "create")
                .containsEntry("result", "create")
                .containsEntry("platform", "android");
    }

    @Test
    void malformedOrSensitivePayloadIsRejectedWithoutWrites() throws Exception {
        mockMvc.perform(post("/api/v1/share-links")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "source":"paired_progress",
                                  "headline":"分享失败",
                                  "storyText":"不应该接受内部字段。",
                                  "phraseText":"Warm water, please.",
                                  "installationId":"install-secret",
                                  "eventKey":"event-secret"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_share_payload"));

        mockMvc.perform(post("/api/v1/share-links")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "source":"rogue_source",
                                  "headline":"分享失败",
                                  "storyText":"未知来源",
                                  "phraseText":"Warm water, please."
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_share_source"));

        mockMvc.perform(post("/api/v1/share-links")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "source":"latest_impact",
                                  "platformHint":"windows",
                                  "headline":"分享失败",
                                  "storyText":"未知平台",
                                  "phraseText":"Warm water, please."
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_share_platform"));

        mockMvc.perform(post("/api/v1/share-links")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "source":"latest_impact",
                                  "headline":"",
                                  "storyText":"空 headline",
                                  "phraseText":"Warm water, please."
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));

        mockMvc.perform(post("/api/v1/share-links")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(("""
                                {
                                  "source":"latest_impact",
                                  "headline":"过长短语",
                                  "storyText":"应该被拦截",
                                  "phraseText":"%s"
                                }
                                """
                        ).formatted("W".repeat(121))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));

        assertThat(jdbcTemplate.queryForObject("select count(*) from share_landing_cards", Integer.class)).isZero();
        assertThat(jdbcTemplate.queryForObject("select count(*) from share_landing_events", Integer.class)).isZero();
    }

    private JsonNode readJson(String rawJson) throws Exception {
        return objectMapper.readTree(rawJson);
    }
}
