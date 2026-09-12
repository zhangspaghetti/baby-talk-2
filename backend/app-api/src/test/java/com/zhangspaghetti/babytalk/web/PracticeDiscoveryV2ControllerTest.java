package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import tools.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.http.HttpHeaders;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "babytalk.practice.discovery.custom-scene.enabled=true",
        "babytalk.practice.discovery.owner.key-secret=test-owner-key-secret-test-owner-key",
        "babytalk.practice.discovery.custom-scene.provider-mode=fake"
})
@AutoConfigureMockMvc
class PracticeDiscoveryV2ControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private AuthConsentSyncService authConsentSyncService;

    @Test
    void healthSceneReturnsOnlySafetyVariant() throws Exception {
        var session = createAcceptedSession("13800139001", "install-v2-health");
        var result = mockMvc.perform(post("/api/v2/practice/discovery")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + session.accessToken())
                        .header("X-App-Version", "1.2.0")
                        .content(requestJson("宝宝拉肚子哭闹怎么办")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.schemaVersion").value("custom-scene-result-v2"))
                .andExpect(jsonPath("$.resultType").value("health_safety"))
                .andExpect(jsonPath("$.safety.action").value("seek_medical_help"))
                .andExpect(jsonPath("$.safety.templateId").value("health-concern-v1"))
                .andExpect(jsonPath("$.safety.policyVersion").value("health-safety-v1"))
                .andReturn();

        var root = objectMapper.readTree(result.getResponse().getContentAsString());
        assertThat(fieldNames(root)).containsExactlyInAnyOrder(
                "schemaVersion", "discoveryTraceId", "resultType", "safety");
        assertThat(fieldNames(root)).doesNotContain(
                "generatedContentId", "scene", "english", "starter", "audio");
    }

    @Test
    void ordinarySceneReturnsGeneratedVariantWithNestedScene() throws Exception {
        var session = createAcceptedSession("13800139002", "install-v2-ordinary");
        var result = mockMvc.perform(post("/api/v2/practice/discovery")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + session.accessToken())
                        .header("X-App-Version", "1.2.0")
                        .content(requestJson("洗澡后哄睡")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.resultType").value("generated_scene"))
                .andExpect(jsonPath("$.policyVersion").value("health-safety-v1"))
                .andExpect(jsonPath("$.scene.source").value("generated"))
                .andExpect(jsonPath("$.safety").doesNotExist())
                .andReturn();

        var root = objectMapper.readTree(result.getResponse().getContentAsString());
        assertThat(fieldNames(root)).contains("schemaVersion", "discoveryTraceId", "resultType",
                "policyVersion", "scene");
    }

    private String requestJson(String customSceneText) throws Exception {
        var request = objectMapper.createObjectNode();
        request.put("surface", "onboarding");
        request.put("mode", "custom_scene");
        request.put("installationId", "install_v2_test");
        request.put("ageRange", "m7_11");
        request.put("parentGoal", "calmer_care");
        request.put("locale", "zh-CN");
        request.put("limit", 6);
        request.put("customSceneText", customSceneText);
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

    private List<String> fieldNames(tools.jackson.databind.JsonNode root) {
        return new ArrayList<>(root.propertyNames());
    }
}
