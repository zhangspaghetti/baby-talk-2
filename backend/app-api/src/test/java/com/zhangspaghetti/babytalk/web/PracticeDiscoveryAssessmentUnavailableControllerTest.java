package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import java.util.ArrayList;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import tools.jackson.databind.ObjectMapper;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "babytalk.practice.discovery.custom-scene.enabled=true",
        "babytalk.practice.discovery.custom-scene.provider-mode=disabled",
        "babytalk.practice.discovery.owner.key-secret=test-owner-key-secret-test-owner-key"
})
@AutoConfigureMockMvc
class PracticeDiscoveryAssessmentUnavailableControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private AuthConsentSyncService authConsentSyncService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void v2AssessmentUnavailableReturnsExactSafetyEnvelopeWithoutGenerationFields() throws Exception {
        var session = createAcceptedSession("13800139901", "install-v2-unavailable");
        var result = mockMvc.perform(post("/api/v2/practice/discovery")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + session.accessToken())
                        .header("X-App-Version", "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(requestJson("洗澡后哄睡")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.schemaVersion").value("custom-scene-result-v2"))
                .andExpect(jsonPath("$.resultType").value("assessment_unavailable"))
                .andExpect(jsonPath("$.safety.templateId").value("health-assessment-unavailable-v1"))
                .andReturn();

        var root = objectMapper.readTree(result.getResponse().getContentAsString());
        assertThat(new ArrayList<>(root.propertyNames())).containsExactlyInAnyOrder(
                "schemaVersion", "discoveryTraceId", "resultType", "safety");
        assertThat(root.get("safety").get("action").asText()).isEqualTo("uncertain");
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content", Integer.class)).isZero();
    }

    @Test
    void v1AssessmentUnavailableReturns503WithoutGeneration() throws Exception {
        var result = mockMvc.perform(post("/api/v1/practice/discovery")
                        .header("X-App-Version", "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(requestJson("洗澡后哄睡")))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("health_assessment_unavailable"))
                .andReturn();

        assertThat(result.getResponse().getContentAsString())
                .contains("已暂停生成")
                .doesNotContain("洗澡后哄睡");
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content", Integer.class)).isZero();
    }

    private String requestJson(String sceneText) throws Exception {
        var request = objectMapper.createObjectNode();
        request.put("surface", "onboarding");
        request.put("mode", "custom_scene");
        request.put("installationId", "install_unavailable");
        request.put("ageRange", "m7_11");
        request.put("parentGoal", "calmer_care");
        request.put("locale", "zh-CN");
        request.put("limit", 6);
        request.put("customSceneText", sceneText);
        return objectMapper.writeValueAsString(request);
    }

    private AuthConsentSyncService.SessionResponse createAcceptedSession(
            String phoneNumber,
            String installationId
    ) {
        var challenge = authConsentSyncService.createChallenge(phoneNumber);
        var session = authConsentSyncService.verifyChallenge(challenge.challengeId(), "246810", installationId);
        authConsentSyncService.acceptConsent(session.sessionId(), "pipl-v1");
        return session;
    }
}
