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

import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.service.DistributionService;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:distribution-page-web-test;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_UPPER=false",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/upgrade?channel=stable&source=version_gate",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.distribution.default-channel=stable",
        "app.distribution.download-default-source=public_link",
        "app.distribution.upgrade-default-source=version_gate",
        "app.distribution.allowed-sources[0]=public_link",
        "app.distribution.allowed-sources[1]=version_gate",
        "app.distribution.channels.stable.label=正式版",
        "app.distribution.channels.stable.platforms.android=https://download.example.com/android/stable.apk",
        "app.distribution.channels.stable.platforms.ios=https://apps.apple.com/app/id1234567890",
        "app.distribution.channels.beta.label=测试版",
        "app.distribution.channels.beta.platforms.android=https://download.example.com/android/beta.apk"
})
@AutoConfigureMockMvc
class DistributionPageWebTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void resetTables() {
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
    void downloadPageRendersCtasAndWritesPageViewAudit() throws Exception {
        mockMvc.perform(get("/download")
                        .queryParam("channel", "stable")
                        .queryParam("source", "public_link")
                        .header("User-Agent", "Mozilla/5.0 (Linux; Android 14)"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.TEXT_HTML))
                .andExpect(header().string(DistributionService.RESULT_HEADER, "page_view"))
                .andExpect(header().string(DistributionService.AUDIT_HEADER, "recorded"))
                .andExpect(content().string(containsString("下载 Baby Talk")))
                .andExpect(content().string(containsString("Android 下载 · 推荐")))
                .andExpect(content().string(containsString("/download/redirect?channel=stable&amp;source=public_link&amp;platform=android")))
                .andExpect(content().string(containsString("iPhone / iPad 安装")));

        var events = listEvents();
        assertThat(events).hasSize(1);
        assertThat(events.get(0))
                .containsEntry("result", "page_view")
                .containsEntry("release_channel", "stable")
                .containsEntry("source", "public_link")
                .containsEntry("platform", "android");
    }

    @Test
    void upgradePageDefaultsToVersionGateAndShowsUnavailableStateWhenPlatformMissing() throws Exception {
        mockMvc.perform(get("/upgrade")
                        .queryParam("channel", "beta")
                        .queryParam("platform", "ios"))
                .andExpect(status().isOk())
                .andExpect(header().string(DistributionService.RESULT_HEADER, "unavailable"))
                .andExpect(content().string(containsString("升级 Baby Talk")))
                .andExpect(content().string(containsString("当前渠道暂未提供该平台入口")))
                .andExpect(content().string(containsString("Android 下载")));

        var events = listEvents();
        assertThat(events).hasSize(1);
        assertThat(events.get(0))
                .containsEntry("result", "unavailable")
                .containsEntry("failure_reason", "platform_target_missing")
                .containsEntry("source", "version_gate")
                .containsEntry("platform", "ios");
    }

    @Test
    void redirectEndpointOnlyUsesWhitelistedTargetsAndWritesRedirectAudit() throws Exception {
        mockMvc.perform(get("/download/redirect")
                        .queryParam("channel", "stable")
                        .queryParam("source", "public_link")
                        .queryParam("platform", "android"))
                .andExpect(status().isFound())
                .andExpect(header().string(DistributionService.RESULT_HEADER, "redirect"))
                .andExpect(header().string(DistributionService.AUDIT_HEADER, "recorded"))
                .andExpect(redirectedUrl("https://download.example.com/android/stable.apk"));

        var events = listEvents();
        assertThat(events).hasSize(1);
        assertThat(events.get(0))
                .containsEntry("result", "redirect")
                .containsEntry("platform", "android");
    }

    @Test
    void invalidChannelAndSourceProduceVisibleFailuresAndAuditRows() throws Exception {
        mockMvc.perform(get("/download")
                        .queryParam("channel", "rogue")
                        .queryParam("source", "public_link"))
                .andExpect(status().isBadRequest())
                .andExpect(header().string(DistributionService.RESULT_HEADER, "invalid_channel"))
                .andExpect(content().string(containsString("分发链接无效")));

        mockMvc.perform(get("/download")
                        .queryParam("channel", "stable")
                        .queryParam("source", "rogue"))
                .andExpect(status().isBadRequest())
                .andExpect(header().string(DistributionService.RESULT_HEADER, "invalid_source"))
                .andExpect(content().string(containsString("分发链接无效")));

        var events = listEvents();
        assertThat(events).hasSize(2);
        assertThat(events)
                .extracting(event -> event.get("result"))
                .containsExactly("invalid_channel", "invalid_source");
    }

    @Test
    void invalidPlatformOnRedirectIsRejectedWithoutOpenRedirect() throws Exception {
        mockMvc.perform(get("/download/redirect")
                        .queryParam("channel", "stable")
                        .queryParam("source", "public_link")
                        .queryParam("platform", "windows"))
                .andExpect(status().isBadRequest())
                .andExpect(header().string(DistributionService.RESULT_HEADER, "invalid_platform"))
                .andExpect(content().string(containsString("无法继续跳转")));

        var events = listEvents();
        assertThat(events).hasSize(1);
        assertThat(events.get(0))
                .containsEntry("result", "invalid_platform")
                .containsEntry("failure_reason", "unknown_platform");
    }

    @Test
    void upgradeRequiredHandshakeStillPointsToRealUpgradePage() throws Exception {
        mockMvc.perform(post("/api/v1/auth/challenges")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"phoneNumber":"13800138000"}
                                """))
                .andExpect(status().isUpgradeRequired())
                .andExpect(header().string(
                        ApiVersionInterceptor.UPGRADE_URL_HEADER,
                        "https://download.example.com/upgrade?channel=stable&source=version_gate"
                ))
                .andExpect(jsonPath("$.upgradeUrl")
                        .value("https://download.example.com/upgrade?channel=stable&source=version_gate"));
    }

    private List<Map<String, Object>> listEvents() {
        return jdbcTemplate.queryForList(
                """
                select release_channel, source, platform, result, failure_reason
                from release_distribution_events
                order by event_id asc
                """
        );
    }
}
