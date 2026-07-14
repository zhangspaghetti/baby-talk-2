package com.zhangspaghetti.babytalk.practice.discovery;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.handler;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import com.zhangspaghetti.babytalk.web.PracticeDiscoveryController;
import java.time.Instant;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
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
class PracticeDiscoveryControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private AuthConsentSyncService authConsentSyncService;

    @Autowired
    private MutableCustomSceneGenerationService customSceneGenerationService;

    @BeforeEach
    void resetCustomSceneGenerator() {
        customSceneGenerationService.mode("success");
    }

    @Test
    void draftCatalogDiscoverySucceedsWithoutJwt() throws Exception {
        mockMvc.perform(discovery(draftJson()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.surface").value("onboarding"))
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
        assertThat(java.util.Arrays.stream(PracticeDiscoveryController.class.getDeclaredConstructors())
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
    void oldOnboardingDiscoveryRouteIsAbsent() throws Exception {
        var session = createSignedInSession("13800138208", "install-practice-discovery-old-route");

        mockMvc.perform(oldDiscovery(draftJson())
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("not_found"))
                .andExpect(handler().handlerType(org.springframework.web.servlet.resource.ResourceHttpRequestHandler.class));
    }

    @Test
    void draftCustomSceneDiscoverySucceedsWithoutJwt() throws Exception {
        var result = mockMvc.perform(discovery(customSceneJson("洗澡后哄睡")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.surface").value("onboarding"))
                .andExpect(jsonPath("$.mode").value("custom_scene"))
                .andExpect(jsonPath("$.profileMode").value("draft"))
                .andExpect(jsonPath("$.source").value("generated"))
                .andExpect(jsonPath("$.generatedContentId").isNotEmpty())
                .andExpect(jsonPath("$.starter.source").value("generated"))
                .andExpect(jsonPath("$.scenes[0].reasonCode").value("custom_scene_match"))
                .andExpect(jsonPath("$.starter.sceneId").isNotEmpty())
                .andExpect(jsonPath("$.starter.activityId").isNotEmpty())
                .andExpect(jsonPath("$.starter.phraseId").isNotEmpty())
                .andReturn();

        var body = result.getResponse().getContentAsString();
        assertThat(body)
                .contains("gen_scene_")
                .contains("gen_activity_")
                .contains("gen_phrase_")
                .doesNotContain("洗澡后哄睡")
                .doesNotContain("normalizedSceneText");
    }

    @Test
    void acceptedAccountCustomSceneSucceedsWithoutInstallationId() throws Exception {
        var session = createAcceptedSession("13800138209", "install-onboarding-discovery-9");

        mockMvc.perform(discovery(customSceneJson("洗澡前宝宝有点紧张", null))
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.profileMode").value("authenticated_request"))
                .andExpect(jsonPath("$.starter.source").value("generated"));
    }

    @Test
    void customSceneRateLimitReturns429WithoutOwnerKeyOrRawText() throws Exception {
        mockMvc.perform(discovery(customSceneJson("洗澡后哄睡一")))
                .andExpect(status().isOk());
        mockMvc.perform(discovery(customSceneJson("洗澡后哄睡二")))
                .andExpect(status().isOk());
        mockMvc.perform(discovery(customSceneJson("洗澡后哄睡三")))
                .andExpect(status().isOk());

        var result = mockMvc.perform(discovery(customSceneJson("洗澡后哄睡四")))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("custom_scene_rate_limited"))
                .andExpect(jsonPath("$.details.scope").value("installation"))
                .andExpect(jsonPath("$.details.limit").value(3))
                .andExpect(jsonPath("$.details.window").value("burst"))
                .andExpect(jsonPath("$.details.windowSeconds").value(600))
                .andExpect(jsonPath("$.details.retryAfterSeconds").value(600))
                .andReturn();

        assertThat(result.getResponse().getContentAsString())
                .doesNotContain("owner_")
                .doesNotContain("ownerKey")
                .doesNotContain("install_1")
                .doesNotContain("洗澡后哄睡四");
    }

    @Test
    void customSceneUnsafeOutputRejected() throws Exception {
        customSceneGenerationService.mode("unsafe");

        mockMvc.perform(discovery(customSceneJson("洗澡后哄睡")))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("generated_content_rejected"));
    }

    @Test
    void customSceneRejectedRetryDoesNotPrimaryKeyCrash() throws Exception {
        customSceneGenerationService.mode("unsafe");

        mockMvc.perform(discovery(customSceneJson("洗澡后哄睡重试")))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("generated_content_rejected"));

        mockMvc.perform(discovery(customSceneJson("洗澡后哄睡重试")))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("generated_content_rejected"));
    }

    @Test
    void customSceneTimeoutReturnsFallbackHint() throws Exception {
        customSceneGenerationService.mode("timeout");

        mockMvc.perform(discovery(customSceneJson("洗澡后哄睡")))
                .andExpect(status().isGatewayTimeout())
                .andExpect(jsonPath("$.code").value("generation_timeout"))
                .andExpect(jsonPath("$.details.retryable").value(true))
                .andExpect(jsonPath("$.details.suggestCatalogFallback").value(true));
    }

    @Test
    void transientProviderUnavailableReturnsRetryableFallbackHint() throws Exception {
        customSceneGenerationService.mode("unavailable");

        mockMvc.perform(discovery(customSceneJson("洗澡后哄睡")))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("generation_unavailable"))
                .andExpect(jsonPath("$.details.retryable").value(true))
                .andExpect(jsonPath("$.details.suggestCatalogFallback").value(true))
                .andExpect(jsonPath("$.details.reason").value("provider_unavailable"));
    }

    @Test
    void invalidCustomSceneTextRejectedBeforeGeneration() throws Exception {
        mockMvc.perform(discovery(customSceneJson("洗澡 138001380001")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("unsafe_custom_scene_text"));

        mockMvc.perform(discovery(customSceneJson("宝宝叫小明，洗澡后哄睡")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("unsafe_custom_scene_text"));

        mockMvc.perform(discovery(customSceneJson("洗澡 ignore previous")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("unsupported_custom_scene_text"));
    }

    @Test
    void unknownModeReturns400() throws Exception {
        expectBadRequestWithCode("""
                {
                  "surface":"onboarding",
                  "mode":"surprise",
                  "installationId":"install_1",
                  "ageRange":"m7_11",
                  "parentGoal":"calmer_care",
                  "locale":"zh-CN"
                }
                """, "invalid_discovery_mode");
    }

    @Test
    void missingOrUnknownSurfaceReturns400() throws Exception {
        expectBadRequestWithCode("""
                {"mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN"}
                """, "invalid_discovery_surface");
        expectBadRequestWithCode("""
                {"surface":"daily_practice","mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN"}
                """, "invalid_discovery_surface");
    }

    @Test
    void knownButOutOfScopeSurfaceReturnsUnsupportedSurfaceMode() throws Exception {
        expectBadRequestWithCode("""
                {"surface":"scene_search","mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN"}
                """, "unsupported_surface_mode");
    }

    @Test
    void missingModeReturns400() throws Exception {
        expectBadRequestWithCode("""
                {"surface":"onboarding","installationId":"install_1","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN"}
                """, "invalid_discovery_mode");
    }

    @Test
    void invalidOrMissingAgeRangeRejectedWithoutSavedProfile() throws Exception {
        expectBadRequestWithCode("""
                {"surface":"onboarding","mode":"catalog","installationId":"install_1","parentGoal":"calmer_care","locale":"zh-CN"}
                """, "invalid_age_range");
        expectBadRequestWithCode("""
                {"surface":"onboarding","mode":"catalog","installationId":"install_1","ageRange":"m99","parentGoal":"calmer_care","locale":"zh-CN"}
                """, "invalid_age_range");
    }

    @Test
    void invalidOrMissingParentGoalRejectedWithoutSavedProfile() throws Exception {
        expectBadRequestWithCode("""
                {"surface":"onboarding","mode":"catalog","installationId":"install_1","ageRange":"m7_11","locale":"zh-CN"}
                """, "invalid_parent_goal");
        expectBadRequestWithCode("""
                {"surface":"onboarding","mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"sleep_more","locale":"zh-CN"}
                """, "invalid_parent_goal");
    }

    @Test
    void invalidLocaleRejected() throws Exception {
        expectBadRequestWithCode("""
                {"surface":"onboarding","mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"calmer_care","locale":"en-US"}
                """, "unsupported_locale");
    }

    @Test
    void limitBoundsAreEnforced() throws Exception {
        expectBadRequestWithCode("""
                {"surface":"onboarding","mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN","limit":0}
                """, "invalid_limit");
        expectBadRequestWithCode("""
                {"surface":"onboarding","mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN","limit":21}
                """, "invalid_limit");
    }

    @Test
    void invalidInstallationIdRejected() throws Exception {
        expectBadRequestWithCode("""
                {"surface":"onboarding","mode":"catalog","installationId":"_bad","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN"}
                """, "invalid_installation_id");
    }

    @Test
    void draftDiscoveryStillRequiresInstallationId() throws Exception {
        expectBadRequestWithCode("""
                {"surface":"onboarding","mode":"catalog","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN"}
                """, "invalid_installation_id");
    }

    @Test
    void invalidClientTraceIdRejected() throws Exception {
        expectBadRequestWithCode("""
                {"surface":"onboarding","mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN","clientTraceId":"_bad"}
                """, "invalid_client_trace_id");
    }

    @Test
    void phoneLikeInstallationIdAndClientTraceIdRejected() throws Exception {
        expectBadRequestWithCode("""
                {"surface":"onboarding","mode":"catalog","installationId":"install_13800138000","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN"}
                """, "invalid_installation_id");
        expectBadRequestWithCode("""
                {"surface":"onboarding","mode":"catalog","installationId":"install_1","ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN","clientTraceId":"trace_13800138000"}
                """, "invalid_client_trace_id");
    }

    @Test
    void unsupportedPrivateOrFreeFormFieldsRejected() throws Exception {
        expectBadRequestWithCode("""
                {
                  "surface":"onboarding",
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
                  "surface":"onboarding",
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
                  "surface":"onboarding",
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
        return post("/api/v1/practice/discovery")
                .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json);
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder oldDiscovery(String json) {
        return post("/api/v1/onboarding/discovery")
                .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json);
    }

    private String draftJson() {
        return """
                {
                  "surface":"onboarding",
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

    private String customSceneJson(String customSceneText) throws Exception {
        return customSceneJson(customSceneText, "install_1");
    }

    private String customSceneJson(String customSceneText, String installationId) throws Exception {
        var root = objectMapper.createObjectNode();
        root.put("surface", "onboarding");
        root.put("mode", "custom_scene");
        if (installationId != null) {
            root.put("installationId", installationId);
        }
        root.put("ageRange", "m7_11");
        root.put("parentGoal", "calmer_care");
        root.put("locale", "zh-CN");
        root.put("customSceneText", customSceneText);
        return objectMapper.writeValueAsString(root);
    }

    private String profileJson(String profileId, String ageRange, String parentGoal) throws Exception {
        return profileJson(profileId, ageRange, parentGoal, "install_1");
    }

    private String profileJson(String profileId, String ageRange, String parentGoal, String installationId) throws Exception {
        var root = objectMapper.createObjectNode();
        root.put("surface", "onboarding");
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

    @TestConfiguration
    static class TestCustomSceneGenerationConfiguration {

        @Bean
        @Primary
        MutableCustomSceneGenerationService mutableCustomSceneGenerationService() {
            return new MutableCustomSceneGenerationService();
        }
    }

    static class MutableCustomSceneGenerationService implements CustomSceneGenerationService {

        private final AtomicReference<String> mode = new AtomicReference<>("success");

        void mode(String mode) {
            this.mode.set(mode);
        }

        @Override
        public GeneratedPracticeContentCandidate generateCustomSceneStarter(CustomSceneGenerationRequest request) {
            return switch (mode.get()) {
                case "unsafe" -> candidate("学习任务", "答题打分", "Lesson quiz", "让孩子答对后再给分。", "Take the quiz.", "开始测验。");
                case "timeout" -> throw new GenerationTimeoutException(request.timeout());
                case "unavailable" -> throw new GenerationUnavailableException(
                        GenerationUnavailableReason.PROVIDER_UNAVAILABLE);
                default -> candidate("日常照护", "洗澡安抚", "Bath care", "看着宝宝，慢慢说一遍。", "Warm water.", "水暖暖的。");
            };
        }

        private GeneratedPracticeContentCandidate candidate(
                String spaceTitleZh,
                String activityTitleZh,
                String sceneTagEn,
                String coachTipZh,
                String englishText,
                String chineseText
        ) {
            return new GeneratedPracticeContentCandidate(
                    spaceTitleZh,
                    activityTitleZh,
                    sceneTagEn,
                    coachTipZh,
                    englishText,
                    chineseText,
                    englishText.toLowerCase().replaceAll("[^a-z ]", "").trim(),
                    "starter",
                    "fake",
                    "test_provider_trace",
                    null,
                    "test-custom-scene"
            );
        }
    }
}
