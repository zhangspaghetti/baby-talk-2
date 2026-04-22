package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.service.ShareLandingService;
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
        "app.share.landing.public-base-url=https://share.example.com",
        "app.share.landing.default-link-ttl=PT72H",
        "app.share.landing.allowed-sources[0]=latest_impact",
        "app.share.landing.allowed-sources[1]=continuity_recommendation",
        "app.share.landing.allowed-sources[2]=paired_progress",
        "app.share.landing.open-app-targets.android=babytalk://share/open",
        "app.share.landing.open-app-targets.ios=babytalk://share/open"
})
@AutoConfigureMockMvc
class ShareLandingWebTest extends AbstractIntegrationTest {

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
    void landingRendersWarmPaperOgMetaAndWritesPageViewAudit() throws Exception {
        var token = createShareLink();

        mockMvc.perform(get("/share/{token}", token)
                        .header("User-Agent", "Mozilla/5.0 (Linux; Android 14)"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.TEXT_HTML))
                .andExpect(header().string(ShareLandingService.RESULT_HEADER, "page_view"))
                .andExpect(header().string(ShareLandingService.AUDIT_HEADER, "recorded"))
                .andExpect(header().string(ShareLandingService.FAILURE_REASON_HEADER, ""))
                .andExpect(content().string(containsString("max-width: 430px")))
                .andExpect(content().string(containsString("property=\"og:title\"")))
                .andExpect(content().string(containsString("property=\"og:description\"")))
                .andExpect(content().string(containsString("Warm water, please.")))
                .andExpect(content().string(containsString("/share/" + token + "/open-app?platform=android")))
                .andExpect(content().string(containsString("/share/" + token + "/download?platform=android")));

        var events = listShareEvents();
        assertThat(events).hasSize(2);
        assertThat(events)
                .extracting(event -> event.get("result"))
                .containsExactly("create", "page_view");
    }

    @Test
    void invalidAndExpiredTokensRenderVisibleFailureStatesAndAuditRows() throws Exception {
        var token = createShareLink();
        jdbcTemplate.update(
                "update share_landing_cards set expires_at = ? where token = ?",
                Timestamp.from(Instant.now().minus(1, ChronoUnit.HOURS)),
                token
        );

        mockMvc.perform(get("/share/{token}", "missingToken123"))
                .andExpect(status().isNotFound())
                .andExpect(header().string(ShareLandingService.RESULT_HEADER, "invalid"))
                .andExpect(header().string(ShareLandingService.FAILURE_REASON_HEADER, "token_not_found"))
                .andExpect(content().string(containsString("分享链接不可用")));

        mockMvc.perform(get("/share/{token}", token))
                .andExpect(status().isGone())
                .andExpect(header().string(ShareLandingService.RESULT_HEADER, "expired"))
                .andExpect(header().string(ShareLandingService.FAILURE_REASON_HEADER, "token_expired"))
                .andExpect(content().string(containsString("已过期")));

        var events = listShareEvents();
        assertThat(events)
                .extracting(event -> event.get("result") + ":" + event.get("failure_reason"))
                .contains("invalid:token_not_found", "expired:token_expired");
    }

    @Test
    void openAppRedirectAndDownloadFallbackAreControlledAndAudited() throws Exception {
        var token = createShareLink();

        mockMvc.perform(get("/share/{token}/open-app", token).queryParam("platform", "android"))
                .andExpect(status().isFound())
                .andExpect(header().string(ShareLandingService.RESULT_HEADER, "open_app_redirect"))
                .andExpect(header().string(ShareLandingService.AUDIT_HEADER, "recorded"))
                .andExpect(header().string("Location", containsString("babytalk://share/open")))
                .andExpect(header().string("Location", containsString("token=" + token)))
                .andExpect(header().string("Location", containsString("spaceId=daily_care")))
                .andExpect(header().string("Location", containsString("activityId=bath_time")));

        mockMvc.perform(get("/share/{token}/download", token).queryParam("platform", "android"))
                .andExpect(status().isFound())
                .andExpect(header().string(ShareLandingService.RESULT_HEADER, "download_fallback"))
                .andExpect(redirectedUrl("/download?source=share_card&platform=android"));

        var events = listShareEvents();
        assertThat(events)
                .extracting(event -> event.get("result"))
                .contains("open_app_redirect", "download_fallback");
        assertThat(events)
                .extracting(event -> (String) event.get("failure_reason"))
                .doesNotContain("fallbackReason", "eventKey");
    }

    @Test
    void missingOpenAppTargetAndAuditFailureStayVisible() throws Exception {
        var token = createShareLink();

        mockMvc.perform(get("/share/{token}/open-app", token).queryParam("platform", "windows"))
                .andExpect(status().isBadRequest())
                .andExpect(header().string(ShareLandingService.RESULT_HEADER, "invalid"))
                .andExpect(header().string(ShareLandingService.FAILURE_REASON_HEADER, "unknown_platform"))
                .andExpect(content().string(containsString("无法继续打开 app")));

        jdbcTemplate.execute("alter table share_landing_events rename to share_landing_events_bak");
        try {
            mockMvc.perform(get("/share/{token}", token))
                    .andExpect(status().isOk())
                    .andExpect(header().string(ShareLandingService.RESULT_HEADER, "page_view"))
                    .andExpect(header().string(ShareLandingService.AUDIT_HEADER, "failed"))
                    .andExpect(content().string(containsString("Baby Talk · 成长分享")));
        } finally {
            jdbcTemplate.execute("alter table share_landing_events_bak rename to share_landing_events");
        }
    }

    private String createShareLink() throws Exception {
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
                .andReturn();
        return readJson(result.getResponse().getContentAsString()).get("token").asText();
    }

    private JsonNode readJson(String rawJson) throws Exception {
        return objectMapper.readTree(rawJson);
    }

    private List<Map<String, Object>> listShareEvents() {
        return jdbcTemplate.queryForList(
                """
                select entrypoint, result, failure_reason, platform
                from share_landing_events
                order by event_id asc
                """
        );
    }
}
