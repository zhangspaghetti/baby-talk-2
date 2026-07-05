package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810"
})
@AutoConfigureMockMvc
class OnboardingDiscoveryControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private AuthConsentSyncService authConsentSyncService;

    @Test
    void draftCatalogDiscoverySucceedsWithoutJwt() throws Exception {
        mockMvc.perform(discovery(draftJson()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mode").value("catalog"))
                .andExpect(jsonPath("$.profileMode").value("draft"))
                .andExpect(jsonPath("$.source").value("catalog"))
                .andExpect(jsonPath("$.discoveryTraceId").isNotEmpty())
                .andExpect(jsonPath("$.scenes[0].sceneId").value("daily_care"))
                .andExpect(jsonPath("$.scenes[0].spaceId").value("daily_care"))
                .andExpect(jsonPath("$.moments[0].momentId").value("bath_time"))
                .andExpect(jsonPath("$.moments[0].activityId").value("bath_time"))
                .andExpect(jsonPath("$.starter.source").value("catalog"));
    }

    @Test
    void controllerUsesTypedRequestBindingWithoutObjectMapperConversion() {
        assertThat(java.util.Arrays.stream(OnboardingDiscoveryController.class.getDeclaredConstructors())
                .flatMap(constructor -> java.util.Arrays.stream(constructor.getParameterTypes()))
                .map(Class::getName))
                .doesNotContain("com.fasterxml.jackson.databind.ObjectMapper");
    }

    @Test
    void draftSuccessOmitsPrivateIdentifiers() throws Exception {
        var result = mockMvc.perform(discovery(draftJson()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.scenes").isArray())
                .andExpect(jsonPath("$.moments").isArray())
                .andExpect(jsonPath("$.starter").exists())
                .andExpect(jsonPath("$.source").value("catalog"))
                .andReturn();

        assertThat(result.getResponse().getContentAsString())
                .doesNotContain("accountId")
                .doesNotContain("sessionId")
                .doesNotContain("phone")
                .doesNotContain("babyName")
                .doesNotContain("babyProfileId");
    }

    @Test
    void customSceneReturns501() throws Exception {
        mockMvc.perform(discovery("""
                        {
                          "mode":"custom_scene",
                          "installationId":"install_1",
                          "ageRange":"m7_11",
                          "parentGoal":"calmer_care",
                          "locale":"zh-CN"
                        }
                        """))
                .andExpect(status().isNotImplemented())
                .andExpect(jsonPath("$.code").value("custom_scene_not_implemented"))
                .andExpect(jsonPath("$.details.supportedModes[0]").value("catalog"));
    }

    @Test
    void unknownModeReturns400() throws Exception {
        expectBadRequestWithCode("""
                {
                  "mode":"surprise",
                  "installationId":"install_1",
                  "ageRange":"m7_11",
                  "parentGoal":"calmer_care",
                  "locale":"zh-CN"
                }
                """, "invalid_discovery_mode");
    }

    @Test
    void invalidOrMissingAgeRangeRejectedWithoutSavedProfile() throws Exception {
        expectBadRequestWithCode("""
                {"mode":"catalog","installationId":"install_1","parentGoal":"calmer_care","locale":"zh-CN"}
                """, "invalid_age_range");
        expectBadRequestWithCode("""
                {"mode":"catalog","installationId":"install_1","ageRange":"m99","parentGoal":"calmer_care","locale":"zh-CN"}
                """, "invalid_age_range");
    }

    @Test
    void invalidOrMissingParentGoalRejectedWithoutSavedProfile() throws Exception {
        expectBadRequestWithCode("""
                {"mode":"catalog","installationId":"install_1","ageRange":"m7_11","locale":"zh-CN"}
                """, "invalid_parent_goal");
        expectBadRequestWithCode("""
                {"mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"sleep_more","locale":"zh-CN"}
                """, "invalid_parent_goal");
    }

    @Test
    void invalidLocaleRejected() throws Exception {
        expectBadRequestWithCode("""
                {"mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"calmer_care","locale":"en-US"}
                """, "unsupported_locale");
    }

    @Test
    void limitBoundsAreEnforced() throws Exception {
        expectBadRequestWithCode("""
                {"mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN","limit":0}
                """, "invalid_limit");
        expectBadRequestWithCode("""
                {"mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN","limit":21}
                """, "invalid_limit");
    }

    @Test
    void invalidInstallationIdRejected() throws Exception {
        expectBadRequestWithCode("""
                {"mode":"catalog","installationId":"_bad","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN"}
                """, "invalid_installation_id");
    }

    @Test
    void draftDiscoveryStillRequiresInstallationId() throws Exception {
        expectBadRequestWithCode("""
                {"mode":"catalog","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN"}
                """, "invalid_installation_id");
    }

    @Test
    void invalidClientTraceIdRejected() throws Exception {
        expectBadRequestWithCode("""
                {"mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN","clientTraceId":"_bad"}
                """, "invalid_client_trace_id");
    }

    @Test
    void phoneLikeInstallationIdAndClientTraceIdRejected() throws Exception {
        expectBadRequestWithCode("""
                {"mode":"catalog","installationId":"install_13800138000","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN"}
                """, "invalid_installation_id");
        expectBadRequestWithCode("""
                {"mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN","clientTraceId":"trace_13800138000"}
                """, "invalid_client_trace_id");
    }

    @Test
    void unsupportedPrivateOrFreeFormFieldsRejected() throws Exception {
        expectBadRequestWithCode("""
                {
                  "mode":"catalog",
                  "installationId":"install_1",
                  "ageRange":"m7_11",
                  "parentGoal":"calmer_care",
                  "locale":"zh-CN",
                  "babyName":"小满"
                }
                """, "invalid_request_body");
        expectBadRequestWithCode("""
                {
                  "mode":"catalog",
                  "installationId":"install_1",
                  "ageRange":"m7_11",
                  "parentGoal":"calmer_care",
                  "locale":"zh-CN",
                  "customSceneText":"洗澡后哄睡"
                }
                """, "invalid_request_body");
    }

    @Test
    void nonObjectDiscoveryBodiesReturnContractError() throws Exception {
        expectBadRequestWithCode("""
                ["catalog"]
                """, "invalid_request_body");
        expectBadRequestWithCode("""
                "catalog"
                """, "invalid_request_body");
    }

    @Test
    void invalidTypedDiscoveryFieldsReturnContractError() throws Exception {
        expectBadRequestWithCode("""
                {
                  "mode":"catalog",
                  "installationId":"install_1",
                  "ageRange":"m7_11",
                  "parentGoal":"calmer_care",
                  "locale":"zh-CN",
                  "limit":"many"
                }
                """, "invalid_request_body");
    }

    @Test
    void authenticatedRequestWithoutBabyProfileIdDoesNotRequireAcceptedConsent() throws Exception {
        var session = createSignedInSession("13800138200", "install-onboarding-discovery-1");

        mockMvc.perform(discovery(draftJson())
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.profileMode").value("authenticated_request"))
                .andExpect(jsonPath("$.source").value("catalog"));
    }

    @Test
    void authenticatedProfileVerifiesOwnershipAndUsesSavedContext() throws Exception {
        var owner = createAcceptedSession("13800138201", "install-onboarding-discovery-2");
        var other = createAcceptedSession("13800138202", "install-onboarding-discovery-3");
        var profileId = createCompletedProfile(owner.accessToken());

        mockMvc.perform(discovery(profileJson(profileId, null, null))
                        .header(HttpHeaders.AUTHORIZATION, bearer(owner.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.profileMode").value("authenticated_profile"))
                .andExpect(jsonPath("$.starter.source").value("catalog"));

        mockMvc.perform(discovery(profileJson(profileId, null, null))
                        .header(HttpHeaders.AUTHORIZATION, bearer(other.accessToken())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("onboarding_profile_not_found"));
    }

    @Test
    void profileBackedDiscoverySucceedsWithoutInstallationId() throws Exception {
        var owner = createAcceptedSession("13800138206", "install-onboarding-discovery-6");
        var profileId = createCompletedProfile(owner.accessToken());

        mockMvc.perform(discovery(profileJson(profileId, null, null, null))
                        .header(HttpHeaders.AUTHORIZATION, bearer(owner.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.profileMode").value("authenticated_profile"))
                .andExpect(jsonPath("$.starter.source").value("catalog"));
    }

    @Test
    void profileBackedDiscoveryRejectsUnsafeInstallationIdIfProvided() throws Exception {
        var owner = createAcceptedSession("13800138207", "install-onboarding-discovery-7");
        var profileId = createCompletedProfile(owner.accessToken());

        mockMvc.perform(discovery(profileJson(profileId, null, null, "_bad"))
                        .header(HttpHeaders.AUTHORIZATION, bearer(owner.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_installation_id"));
    }

    @Test
    void babyProfileIdWithoutJwtDoesNotEnterProfileMode() throws Exception {
        mockMvc.perform(discovery(profileJson("babyprof_any", null, null, null)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("consumer_authentication_required"));
    }

    @Test
    void authenticatedProfileRejectsProfileRequestContextMismatch() throws Exception {
        var owner = createAcceptedSession("13800138203", "install-onboarding-discovery-4");
        var profileId = createCompletedProfile(owner.accessToken());

        mockMvc.perform(discovery(profileJson(profileId, "m12_17", "calmer_care"))
                        .header(HttpHeaders.AUTHORIZATION, bearer(owner.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("profile_context_mismatch"));
    }

    @Test
    void profileModeReturnsConsentRequiredWhenConsentNotAccepted() throws Exception {
        var session = createSignedInSession("13800138204", "install-onboarding-discovery-5");

        mockMvc.perform(discovery(profileJson("babyprof_any", null, "calmer_care"))
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken())))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("consent_required"));
    }

    @Test
    void invalidBearerTokenOnDiscoveryIsRejected() throws Exception {
        mockMvc.perform(discovery(draftJson())
                        .header(HttpHeaders.AUTHORIZATION, "Bearer not-a-real-token"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("invalid_access_token"));
    }

    private void expectBadRequestWithCode(String json, String code) throws Exception {
        mockMvc.perform(discovery(json))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(code));
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder discovery(String json) {
        return post("/api/v1/onboarding/discovery")
                .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json);
    }

    private String draftJson() {
        return """
                {
                  "mode":"catalog",
                  "installationId":"install_1",
                  "ageRange":"m7_11",
                  "parentGoal":"calmer_care",
                  "locale":"zh-CN",
                  "limit":6,
                  "clientTraceId":"trace_1"
                }
                """;
    }

    private String profileJson(String profileId, String ageRange, String parentGoal) throws Exception {
        return profileJson(profileId, ageRange, parentGoal, "install_1");
    }

    private String profileJson(String profileId, String ageRange, String parentGoal, String installationId) throws Exception {
        var root = objectMapper.createObjectNode();
        root.put("mode", "catalog");
        if (installationId != null) {
            root.put("installationId", installationId);
        }
        root.put("babyProfileId", profileId);
        root.put("locale", "zh-CN");
        if (ageRange != null) {
            root.put("ageRange", ageRange);
        }
        if (parentGoal != null) {
            root.put("parentGoal", parentGoal);
        }
        return objectMapper.writeValueAsString(root);
    }

    private String createCompletedProfile(String accessToken) throws Exception {
        var completedAt = Instant.now().minusSeconds(60).toString();
        var result = mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "babyName":"小满",
                                  "ageRange":"m7_11",
                                  "parentGoal":"calmer_care",
                                  "onboardingState":"completed",
                                  "completedAt":"%s",
                                  "clientTraceId":"onb_profile_001",
                                  "starter":{
                                    "sceneId":"daily_care",
                                    "momentId":"bath_time",
                                    "activityId":"bath_time",
                                    "utteranceId":"bath_time_warm_water",
                                    "phraseId":"bath_time_warm_water",
                                    "source":"catalog"
                                  }
                                }
                                """.formatted(completedAt)))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString()).get("babyProfileId").asText();
    }

    private AuthConsentSyncService.SessionResponse createSignedInSession(String phoneNumber, String installationId) {
        var challenge = authConsentSyncService.createChallenge(phoneNumber);
        return authConsentSyncService.verifyChallenge(challenge.challengeId(), "246810", installationId);
    }

    private AuthConsentSyncService.SessionResponse createAcceptedSession(String phoneNumber, String installationId) {
        var session = createSignedInSession(phoneNumber, installationId);
        authConsentSyncService.acceptConsent(session.sessionId(), "pipl-v1");
        return session;
    }

    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }
}
