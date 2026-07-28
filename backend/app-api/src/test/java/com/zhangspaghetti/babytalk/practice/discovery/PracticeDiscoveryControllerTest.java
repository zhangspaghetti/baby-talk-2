package com.zhangspaghetti.babytalk.practice.discovery;

import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.handler;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.ObjectMapper;
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
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
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
    private MutableCustomSceneGenerator customSceneGenerationService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private ApplicationContext applicationContext;

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
        var response = objectMapper.readTree(body);
        var scene = response.get("scenes").get(0);
        var moment = response.get("moments").get(0);
        var utterance = moment.get("starterUtterances").get(0);
        var starter = response.get("starter");
        var reactionSupports = response.get("reactionSupports");
        assertThat(body)
                .contains("gen_scene_")
                .contains("gen_activity_")
                .contains("gen_phrase_")
                .doesNotContain("洗澡后哄睡")
                .doesNotContain("normalizedSceneText");
        assertThat(scene.get("sceneId").asText()).isEqualTo(scene.get("spaceId").asText());
        assertThat(scene.get("sceneId").asText()).startsWith("gen_scene_");
        assertThat(scene.get("spaceId").asText()).startsWith("gen_scene_");
        assertThat(moment.get("momentId").asText()).isEqualTo(moment.get("activityId").asText());
        assertThat(moment.get("momentId").asText()).startsWith("gen_activity_");
        assertThat(moment.get("activityId").asText()).startsWith("gen_activity_");
        assertThat(moment.get("sceneId").asText()).isEqualTo(scene.get("sceneId").asText());
        assertThat(moment.get("spaceId").asText()).isEqualTo(scene.get("spaceId").asText());
        assertThat(utterance.get("utteranceId").asText()).isEqualTo(utterance.get("phraseId").asText());
        assertThat(utterance.get("utteranceId").asText()).startsWith("gen_phrase_");
        assertThat(utterance.get("phraseId").asText()).startsWith("gen_phrase_");
        assertThat(starter.get("sceneId").asText()).isEqualTo(scene.get("sceneId").asText());
        assertThat(starter.get("spaceId").asText()).isEqualTo(scene.get("spaceId").asText());
        assertThat(starter.get("sceneId").asText()).startsWith("gen_scene_");
        assertThat(starter.get("spaceId").asText()).startsWith("gen_scene_");
        assertThat(starter.get("momentId").asText()).isEqualTo(moment.get("momentId").asText());
        assertThat(starter.get("activityId").asText()).isEqualTo(moment.get("activityId").asText());
        assertThat(starter.get("momentId").asText()).startsWith("gen_activity_");
        assertThat(starter.get("activityId").asText()).startsWith("gen_activity_");
        assertThat(starter.get("utteranceId").asText()).isEqualTo(utterance.get("utteranceId").asText());
        assertThat(starter.get("phraseId").asText()).isEqualTo(utterance.get("phraseId").asText());
        assertThat(starter.get("utteranceId").asText()).startsWith("gen_phrase_");
        assertThat(starter.get("phraseId").asText()).startsWith("gen_phrase_");
        assertThat(moment.get("coachTip").asText()).isEqualTo("看着宝宝。 慢慢说一遍。");
        assertThat(reactionSupports.size()).isEqualTo(5);
        assertThat(reactionSupports.get(0).get("reactionType").asText()).isEqualTo("cooperating");
        assertThat(reactionSupports.get(4).get("reactionType").asText()).isEqualTo("other");
        for (var support : reactionSupports) {
            assertThat(support.get("utteranceId").asText()).startsWith("gen_utt_");
            assertThat(support.get("english").asText()).isNotBlank();
            assertThat(support.get("chinese").asText()).isNotBlank();
        }
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content_utterances", Integer.class)).isEqualTo(6);
    }

    @Test
    void fakeModeRunsTheTypedOrchestratorAndPersistsAttemptBundleAndJudgeBeforeActivation() throws Exception {
        customSceneGenerationService.mode("repairable");

        mockMvc.perform(discovery(customSceneJson("洗澡后哄睡")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.source").value("generated"));

        assertThat(jdbcTemplate.queryForObject(
                "select status from practice_generated_content", String.class)).isEqualTo("active");
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content_attempts where status = 'completed'",
                Integer.class)).isEqualTo(2);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content_evidence_bundles", Integer.class)).isEqualTo(2);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content_judge_results", Integer.class)).isEqualTo(1);
        assertThat(applicationContext.getBeansOfType(
                com.zhangspaghetti.babytalk.practice.agentic.PracticeAiProviderManager.class)).isEmpty();
        assertThat(applicationContext.getBeansOfType(
                com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller.class)).isEmpty();
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_ai_provider_calls where provider_type <> 'fake'", Integer.class)).isZero();
    }

    @Test
    void exactReuseRehydratesSameBoundedUtteranceIdsWithoutAnotherBundle() throws Exception {
        var first = mockMvc.perform(discovery(customSceneJson("洗澡后哄睡")))
                .andExpect(status().isOk())
                .andReturn();
        var second = mockMvc.perform(discovery(customSceneJson("洗澡后哄睡")))
                .andExpect(status().isOk())
                .andReturn();

        var firstResponse = objectMapper.readTree(first.getResponse().getContentAsString());
        var secondResponse = objectMapper.readTree(second.getResponse().getContentAsString());
        assertThat(secondResponse.get("generatedContentId").asText())
                .isEqualTo(firstResponse.get("generatedContentId").asText());
        assertThat(secondResponse.get("starter").get("utteranceId").asText())
                .isEqualTo(firstResponse.get("starter").get("utteranceId").asText());
        var firstSupportIds = java.util.stream.StreamSupport.stream(
                        firstResponse.get("reactionSupports").spliterator(), false)
                .map(support -> support.get("utteranceId").asText())
                .toList();
        var secondSupportIds = java.util.stream.StreamSupport.stream(
                        secondResponse.get("reactionSupports").spliterator(), false)
                .map(support -> support.get("utteranceId").asText())
                .toList();
        assertThat(secondSupportIds).containsExactlyElementsOf(firstSupportIds);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content", Integer.class)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content_utterances", Integer.class)).isEqualTo(6);
    }

    @Test
    void carePathClientRequestIdReconcilesLostResponseWithoutClientTraceParticipation() throws Exception {
        var first = mockMvc.perform(discovery(carePathCustomSceneJson(
                        "洗澡后哄睡", "request_http_reconcile_001", "trace_first")))
                .andExpect(status().isOk())
                .andReturn();
        var second = mockMvc.perform(discovery(carePathCustomSceneJson(
                        "洗澡后哄睡", "request_http_reconcile_001", "trace_second")))
                .andExpect(status().isOk())
                .andReturn();

        var firstResponse = objectMapper.readTree(first.getResponse().getContentAsString());
        var secondResponse = objectMapper.readTree(second.getResponse().getContentAsString());
        assertThat(secondResponse.get("generatedContentId").asText())
                .isEqualTo(firstResponse.get("generatedContentId").asText());
        assertThat(jdbcTemplate.queryForObject(
                "select client_request_id from practice_generated_content",
                String.class)).isEqualTo("request_http_reconcile_001");
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content",
                Integer.class)).isEqualTo(1);
    }

    @Test
    void carePathClientRequestIdRejectsChangedFacts() throws Exception {
        mockMvc.perform(discovery(carePathCustomSceneJson(
                        "洗澡后哄睡", "request_http_conflict_001", "trace_first")))
                .andExpect(status().isOk());

        mockMvc.perform(discovery(carePathCustomSceneJson(
                        "出门前穿鞋", "request_http_conflict_001", "trace_second")))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("client_request_id_conflict"));
    }

    @Test
    void carePathClientRequestIdDoesNotCrossAccountOwners() throws Exception {
        var firstAccount = createAcceptedSession("13800138213", "install-care-path-owner-a");
        var secondAccount = createAcceptedSession("13800138214", "install-care-path-owner-b");
        var clientRequestId = "request_account_scope_001";

        var first = mockMvc.perform(discovery(carePathCustomSceneJson(
                        "洗澡后哄睡", clientRequestId, "trace_account_a", "install-care-path-owner-a"))
                        .header(HttpHeaders.AUTHORIZATION, bearer(firstAccount.accessToken())))
                .andExpect(status().isOk())
                .andReturn();
        var second = mockMvc.perform(discovery(carePathCustomSceneJson(
                        "洗澡后哄睡", clientRequestId, "trace_account_b", "install-care-path-owner-b"))
                        .header(HttpHeaders.AUTHORIZATION, bearer(secondAccount.accessToken())))
                .andExpect(status().isOk())
                .andReturn();

        assertThat(objectMapper.readTree(first.getResponse().getContentAsString())
                .get("generatedContentId").asText())
                .isNotEqualTo(objectMapper.readTree(second.getResponse().getContentAsString())
                        .get("generatedContentId").asText());
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where client_request_id = ?",
                Integer.class,
                clientRequestId)).isEqualTo(2);
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
    void customSceneInvalidOutputIsNonRetryable() throws Exception {
        customSceneGenerationService.mode("invalid");

        mockMvc.perform(discovery(customSceneJson("洗澡后哄睡")))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.code").value("generation_invalid_output"))
                .andExpect(jsonPath("$.details.retryable").value(false));
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
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("unsafe_custom_scene_text"));

        mockMvc.perform(discovery(customSceneJson("宝宝叫小明，洗澡后哄睡")))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("unsafe_custom_scene_text"));

        mockMvc.perform(discovery(customSceneJson("洗澡 ignore previous")))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("unsafe_custom_scene_text"));
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

    private String carePathCustomSceneJson(
            String customSceneText,
            String clientRequestId,
            String clientTraceId
    ) throws Exception {
        return carePathCustomSceneJson(customSceneText, clientRequestId, clientTraceId, "install_1");
    }

    private String carePathCustomSceneJson(
            String customSceneText,
            String clientRequestId,
            String clientTraceId,
            String installationId
    ) throws Exception {
        var root = objectMapper.createObjectNode();
        root.put("surface", "care_path");
        root.put("mode", "custom_scene");
        root.put("installationId", installationId);
        root.put("ageRange", "m7_11");
        root.put("parentGoal", "calmer_care");
        root.put("locale", "zh-CN");
        root.put("customSceneText", customSceneText);
        root.put("clientRequestId", clientRequestId);
        root.put("clientTraceId", clientTraceId);
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
        MutableCustomSceneGenerator mutableCustomSceneGenerator() {
            return new MutableCustomSceneGenerator();
        }
    }

    static class MutableCustomSceneGenerator implements CustomSceneGenerator {

        private final AtomicReference<String> mode = new AtomicReference<>("success");

        void mode(String mode) {
            this.mode.set(mode);
        }

        @Override
        public GeneratedPracticeContentCandidate generate(GeneratorRequest request) {
            return switch (mode.get()) {
                case "unsafe" -> candidate("学习任务", "答题打分", "Lesson quiz", "让孩子答对后再给分。", "答对后打分。", "Take the quiz.", "开始测验。");
                case "invalid" -> new GeneratedPracticeContentCandidate(
                        "日常照护", "洗澡安抚", "Bath care", "看着宝宝。", "慢慢说一遍。",
                        "Warm water.", "水暖暖的。", "warm water", "advanced", "fake");
                case "repairable" -> new GeneratedPracticeContentCandidate(
                        "日常照护", "洗澡安抚", "Bath care", "", "慢慢说一遍。",
                        "Warm water.", "水暖暖的。", "warm water", "starter", "fake");
                case "timeout" -> throw new GenerationTimeoutException();
                case "unavailable" -> throw new GenerationUnavailableException(
                        GenerationUnavailableReason.PROVIDER_UNAVAILABLE);
                default -> candidate("日常照护", "洗澡安抚", "Bath care", "看着宝宝。", "慢慢说一遍。", "Warm water.", "水暖暖的。");
            };
        }

        private GeneratedPracticeContentCandidate candidate(
                String spaceTitleZh,
                String activityTitleZh,
                String sceneTagEn,
                String tprActionZh,
                String deliveryGuidanceZh,
                String englishText,
                String chineseText
        ) {
            return new GeneratedPracticeContentCandidate(
                    spaceTitleZh,
                    activityTitleZh,
                    sceneTagEn,
                    tprActionZh,
                    deliveryGuidanceZh,
                    englishText,
                    chineseText,
                    englishText.toLowerCase().replaceAll("[^a-z ]", "").trim(),
                    "starter",
                    "fake"
            );
        }
    }
}
