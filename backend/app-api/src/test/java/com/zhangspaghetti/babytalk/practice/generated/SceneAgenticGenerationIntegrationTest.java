package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.classic.spi.IThrowableProxy;
import ch.qos.logback.core.read.ListAppender;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.generated.audio.GeneratedAudioResponse;
import com.zhangspaghetti.babytalk.practice.generated.audio.GeneratedSpeechSynthesisPort;
import com.zhangspaghetti.babytalk.practice.generated.evidence.CompositeCustomSceneEvidenceRetriever;
import com.zhangspaghetti.babytalk.practice.generated.evidence.CustomSceneEvidenceRetriever;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceItem;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceRetrievalRequest;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceRetrievalResult;
import com.zhangspaghetti.babytalk.practice.generated.evidence.ReplayMode;
import com.zhangspaghetti.babytalk.practice.generated.evidence.RetrievalStatus;
import com.zhangspaghetti.babytalk.practice.generated.quality.DimensionResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeDimension;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdict;
import com.zhangspaghetti.babytalk.practice.generated.quality.RepairDirective;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;
import java.util.stream.Collectors;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

@SpringBootTest(properties = {
        "babytalk.practice.discovery.custom-scene.enabled=true",
        "babytalk.practice.discovery.custom-scene.provider-mode=agentic",
        "babytalk.practice.discovery.custom-scene.max-generation-attempts=2",
        "babytalk.practice.discovery.custom-scene.installation-burst-limit=10",
        "babytalk.practice.discovery.custom-scene.installation-daily-limit=1",
        "babytalk.practice.discovery.custom-scene.account-burst-limit=10",
        "babytalk.practice.discovery.custom-scene.account-daily-limit=2",
        "babytalk.practice.generated-audio.enabled=true",
        "babytalk.practice.generated-audio.provider-mode=fake",
        "app.contract.min-supported-version=1.3.0",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "babytalk.practice.discovery.owner.key-version=v1",
        "babytalk.practice.discovery.owner.key-secret=integration-owner-key-secret-at-least-32-bytes",
        "app.ai.routing-policy.version=integration-routing-v1",
        "app.ai.providers.primary.type=openai-compatible",
        "app.ai.providers.primary.base-url=http://127.0.0.1:9/v1",
        "app.ai.providers.primary.api-key-environment-variable=PATH",
        "app.ai.providers.primary.model=stub-model",
        "app.ai.providers.primary.timeout=2s",
        "app.ai.providers.primary.max-tokens=128",
        "app.ai.capabilities.custom-scene-generator.provider-names[0]=primary",
        "app.ai.capabilities.custom-scene-quality-judge.provider-names[0]=primary",
        "app.ai.capabilities.custom-scene-repair.provider-names[0]=primary"
})
@AutoConfigureMockMvc
@Import(SceneAgenticGenerationIntegrationTest.StubProviderConfiguration.class)
class SceneAgenticGenerationIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @MockitoBean(name = "practiceAiStructuredOutputCaller")
    private PracticeAiStructuredOutputCaller structuredOutputCaller;

    @MockitoBean
    private GeneratedSpeechSynthesisPort speechSynthesisPort;

    private final StubResponses caller = new StubResponses();

    @Autowired
    private AuthConsentSyncService authConsentSyncService;

    @Autowired
    private StubEvidenceRetriever evidenceRetriever;

    @Autowired
    private PracticeGeneratedContentQueryMapper generatedContentQueryMapper;

    private AuthConsentSyncService.SessionResponse session;

    @BeforeEach
    void resetStub() {
        var challenge = authConsentSyncService.createChallenge("13800139999");
        session = authConsentSyncService.verifyChallenge(
                challenge.challengeId(), "246810", "install-agentic-session");
        authConsentSyncService.acceptConsent(session.sessionId(), "pipl-v1");
        jdbcTemplate.update(
                """
                insert into baby_profiles (
                    profile_id, account_id, baby_name, age_range, parent_goal,
                    onboarding_state, version, created_at, updated_at
                ) values ('profile-agentic-integration', ?, '小满', 'm7_11', 'calmer_care',
                          'draft', 1, now(), now())
                """,
                session.accountId());

        caller.mode(StubMode.PASS);
        evidenceRetriever.mode(EvidenceMode.SUFFICIENT);
        doAnswer(invocation -> caller.callRaw(
                invocation.getArgument(1, String.class),
                invocation.getArgument(2, String.class),
                (Class<?>) invocation.getArgument(3)))
                .when(structuredOutputCaller)
                .callRaw(any(), anyString(), anyString(), any(), anyInt());
        doAnswer(invocation -> caller.call(
                invocation.getArgument(1, String.class),
                invocation.getArgument(2, String.class),
                (Class<?>) invocation.getArgument(3)))
                .when(structuredOutputCaller)
                .call(any(), anyString(), anyString(), any());
        doAnswer(invocation -> caller.call(
                invocation.getArgument(1, String.class),
                invocation.getArgument(2, String.class),
                (Class<?>) invocation.getArgument(3)))
                .when(structuredOutputCaller)
                .call(any(), anyString(), anyString(), any(), anyInt());
        doAnswer(invocation -> new GeneratedAudioResponse(
                new byte[]{0x49, 0x44, 0x33, 0x04, 0x00, 0x00}, "audio/mpeg", "generated-tts-v1"))
                .when(speechSynthesisPort)
                .synthesize(any());
    }

    @Test
    void firstEndpointRequestAuditsEveryStepActivatesAndExactReuseMakesNoExtraProviderCalls() throws Exception {
        var first = mockMvc.perform(generation("install_agentic_1", "出门前宝宝不想穿鞋"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.source.type").value("custom"))
                .andExpect(jsonPath("$.generatedContentId").isNotEmpty())
                .andExpect(jsonPath("$.scene.activityTitle").value("穿鞋出门"))
                .andExpect(jsonPath("$.starter.chinese").value("穿鞋出门。"))
                .andReturn();
        var generatedContentId = new tools.jackson.databind.ObjectMapper()
                .readTree(first.getResponse().getContentAsString())
                .get("generatedContentId")
                .asText();

        assertThat(count("practice_generated_content")).isEqualTo(1);
        assertThat(count("practice_generated_content_attempts")).isEqualTo(1);
        assertThat(count("practice_generated_content_evidence_bundles")).isEqualTo(1);
        assertThat(count("practice_generated_content_evidence_items")).isGreaterThan(0);
        assertThat(count("practice_ai_operation_runs")).isEqualTo(2);
        assertThat(count("practice_ai_provider_calls")).isEqualTo(2);
        assertThat(count("practice_generated_content_judge_results")).isEqualTo(1);
        assertThat(evidenceRetriever.externalDelegationCalls()).isZero();
        assertThat(jdbcTemplate.queryForObject(
                "select normalized_scene_text from practice_generated_content where generated_content_id = ?",
                String.class,
                generatedContentId)).isEqualTo("出门前宝宝不想穿鞋");

        mockMvc.perform(generation("install_agentic_1", "出门前宝宝不想穿鞋"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.generatedContentId").value(generatedContentId));

        assertThat(count("practice_ai_provider_calls")).isEqualTo(2);
        assertThat(caller.calls()).isEqualTo(2);
    }

    @Test
    void bidiInputIsRejectedBeforeDraftOrProviderCall() throws Exception {
        mockMvc.perform(generation("install_agentic_bidi", "出门前\u202E宝宝不想穿鞋"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_custom_scene_text"));

        assertThat(count("practice_generated_content")).isZero();
        assertThat(count("practice_ai_provider_calls")).isZero();
    }

    @Test
    void dailyQuotaDenialExpiresDraftBeforeGeneratorCall() throws Exception {
        mockMvc.perform(generation("install_agentic_daily", "出门前宝宝不想穿鞋"))
                .andExpect(status().isOk());
        mockMvc.perform(generation("install_agentic_daily_2", "睡前宝宝想抱抱"))
                .andExpect(status().isOk());
        var callsAfterFirst = count("practice_ai_provider_calls");

        mockMvc.perform(generation("install_agentic_daily_3", "喂饭时宝宝不愿张嘴"))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("custom_scene_rate_limited"));

        assertThat(count("practice_ai_provider_calls")).isEqualTo(callsAfterFirst);
        assertThat(jdbcTemplate.queryForObject(
                "select status from practice_generated_content order by created_at desc limit 1", String.class))
                .isEqualTo("expired");
    }

    @Test
    void judgeProviderExhaustionExpiresRetryableExecution() throws Exception {
        caller.mode(StubMode.JUDGE_EXHAUSTED);

        mockMvc.perform(generation("install_agentic_judge", "出门前宝宝不想穿鞋"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("generation_unavailable"))
                .andExpect(jsonPath("$.details.retryable").value(true));

        assertThat(jdbcTemplate.queryForObject("select status from practice_generated_content", String.class))
                .isEqualTo("expired");
    }

    @Test
    void insufficientEvidenceExpiresBeforeProviderCall() throws Exception {
        evidenceRetriever.mode(EvidenceMode.INSUFFICIENT);

        mockMvc.perform(generation("install_agentic_evidence", "出门前宝宝不想穿鞋"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("generation_unavailable"))
                .andExpect(jsonPath("$.details.reason").value("insufficient_evidence"))
                .andExpect(jsonPath("$.details.retryable").value(true));

        assertThat(jdbcTemplate.queryForObject("select status from practice_generated_content", String.class))
                .isEqualTo("expired");
        assertThat(count("practice_ai_provider_calls")).isZero();
    }

    @Test
    void terminalPiiOutputIsRejectedWithoutJudge() throws Exception {
        caller.mode(StubMode.PII);

        mockMvc.perform(generation("install_agentic_pii", "出门前宝宝不想穿鞋"))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.code").value("generation_invalid_output"));

        assertThat(jdbcTemplate.queryForObject("select status from practice_generated_content", String.class))
                .isEqualTo("rejected");
        assertThat(jdbcTemplate.queryForObject(
                "select normalized_scene_text from practice_generated_content", String.class)).isNull();
        assertThat(count("practice_generated_content_judge_results")).isZero();
    }

    @Test
    void duplicateProviderKeysExpireWithoutActivationOrJudge() throws Exception {
        caller.mode(StubMode.DUPLICATE_KEY);

        mockMvc.perform(generation("install_agentic_duplicate", "出门前宝宝不想穿鞋"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("generation_unavailable"));

        assertThat(jdbcTemplate.queryForObject("select status from practice_generated_content", String.class))
                .isEqualTo("expired");
        assertThat(count("practice_generated_content_judge_results")).isZero();
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where status = 'active'", Integer.class)).isZero();
    }

    @Test
    void trailingProviderTokensExpireWithoutActivationOrJudge() throws Exception {
        caller.mode(StubMode.TRAILING_TOKENS);

        mockMvc.perform(generation("install_agentic_trailing", "出门前宝宝不想穿鞋"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("generation_unavailable"));

        assertThat(jdbcTemplate.queryForObject("select status from practice_generated_content", String.class))
                .isEqualTo("expired");
        assertThat(count("practice_generated_content_judge_results")).isZero();
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where status = 'active'", Integer.class)).isZero();
    }

    @Test
    void repairThenPassCreatesFreshAttemptAndEvidenceBundle() throws Exception {
        caller.mode(StubMode.REPAIR_THEN_PASS);

        mockMvc.perform(generation("install_agentic_repair", "出门前宝宝不想穿鞋"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.source.type").value("custom"));

        assertThat(count("practice_generated_content_attempts")).isEqualTo(2);
        assertThat(count("practice_generated_content_evidence_bundles")).isEqualTo(2);
        assertThat(count("practice_generated_content_judge_results")).isEqualTo(1);
    }

    @Test
    void judgeTprFailureRepairsWithEvidenceActionContractThenFreshJudgeActivates() throws Exception {
        caller.mode(StubMode.JUDGE_TPR_REPAIR_THEN_PASS);

        mockMvc.perform(generation("install_agentic_tpr_repair", "出门前宝宝不想穿鞋"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.source.type").value("custom"));

        assertThat(count("practice_generated_content_attempts")).isEqualTo(2);
        assertThat(count("practice_ai_provider_calls")).isEqualTo(4);
        assertThat(count("practice_generated_content_judge_results")).isEqualTo(2);
        assertThat(jdbcTemplate.queryForObject(
                "select status from practice_generated_content", String.class)).isEqualTo("active");
        assertThat(caller.repairSystemPrompt())
                .contains(
                        "TPR_QUALITY_FAILED",
                        "judge_evidence_action_inconsistent",
                        "evidenceActionConsistencyPolicy.groundingSources");
        assertThat(caller.repairUserPrompt())
                .contains(
                        "\"violationCodes\":[\"TPR_QUALITY_FAILED\"]",
                        "\"evidenceActionConsistencyPolicy\":{",
                        "\"requireEachTprActionSupportedByGrounding\":true",
                        "\"forbidUnmentionedObjectsOrBodyActions\":true");
        assertThat(caller.judgeSystemPrompts()).hasSize(2).allSatisfy(prompt ->
                assertThat(prompt).contains(
                        "semantic triangle",
                        "Do not emit TPR_QUALITY_EVIDENCE_MISSING only because",
                        "Do not relax any rubric dimension"));
        assertThat(caller.judgeUserPrompts().get(0)).contains("看着毛巾。");
        assertThat(caller.judgeUserPrompts().get(1))
                .contains("拿起鞋子。")
                .doesNotContain("看着毛巾。");
    }

    @Test
    void attemptsExhaustedRejectsTerminalRow() throws Exception {
        caller.mode(StubMode.ATTEMPT_EXHAUSTED);

        mockMvc.perform(generation("install_agentic_exhaust", "出门前宝宝不想穿鞋"))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.code").value("generation_invalid_output"));

        assertThat(jdbcTemplate.queryForObject("select status from practice_generated_content", String.class))
                .isEqualTo("rejected");
        assertThat(count("practice_generated_content_attempts")).isEqualTo(2);
    }

    @Test
    void caregiverPresetAndCustomGenerationUsePrimaryProfileAndRespectHouseholdAccess() throws Exception {
        var primary = session;
        var profileId = jdbcTemplate.queryForObject(
                "select profile_id from baby_profiles where account_id = ?",
                String.class,
                primary.accountId());
        var presetIdentity = jdbcTemplate.queryForMap(
                """
                select a.id as activity_id, v.version_id, v.version as published_version,
                       a.slug as preset_scene_id, s.slug as space_id,
                       v.generation_brief, v.state, v.enabled
                from practice_activities a
                join practice_spaces s on s.id = a.space_id
                join practice_preset_scene_versions v
                  on v.version_id = a.current_published_version_id
                 and v.activity_id = a.id
                where a.slug = 'bath_time'
                  and v.state = 'published'
                  and v.enabled = true
                """);
        assertThat(presetIdentity)
                .containsEntry("preset_scene_id", "bath_time")
                .containsEntry("space_id", "daily_care")
                .containsEntry("published_version", 1)
                .containsEntry("state", "published")
                .containsEntry("enabled", true);
        var presetActivityId = ((Number) presetIdentity.get("activity_id")).longValue();
        var presetVersionId = ((Number) presetIdentity.get("version_id")).longValue();
        var presetBrief = presetIdentity.get("generation_brief").toString();

        syncEvent(primary.accessToken(), "install-agentic-session", "family-primary-event",
                "daily_care", "bath_time", "bath_time_warm_water", "cooperating",
                java.time.Instant.now().minusSeconds(30).toString());
        var invite = createInvite(primary.accessToken());
        var caregiver = createAcceptedSession("13900139998", "family-caregiver-install");
        acceptInvite(caregiver.accessToken(), invite.token());
        var outsider = createAcceptedSession("13700137777", "family-outsider-install");
        var privacyForbidden = familyPrivacyForbiddenValues(
                primary.accountId(), caregiver.accountId(), outsider.accountId(), profileId, invite, presetBrief);

        var appender = attachRootLogger();
        String presetBody;
        String customBody;
        String reusedPresetBody;
        String outsiderErrorBody;
        try {
            presetBody = mockMvc.perform(familyGeneration(
                            caregiver.accessToken(),
                            "family-caregiver-install",
                            "family-preset-caregiver",
                            "{\"type\":\"preset\",\"presetSceneId\":\"bath_time\"}"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.source.type").value("preset"))
                    .andExpect(jsonPath("$.source.presetSceneId").value("bath_time"))
                    .andExpect(jsonPath("$.source.presetSceneVersion").value(1))
                    .andExpect(jsonPath("$.route.sceneId").value("daily_care"))
                    .andExpect(jsonPath("$.route.spaceId").value("daily_care"))
                    .andExpect(jsonPath("$.route.momentId").value("bath_time"))
                    .andExpect(jsonPath("$.route.activityId").value("bath_time"))
                    .andReturn()
                    .getResponse()
                    .getContentAsString();

            customBody = mockMvc.perform(familyGeneration(
                            caregiver.accessToken(),
                            "family-caregiver-custom-install",
                            "family-custom-caregiver",
                            "{\"type\":\"custom\",\"text\":\"出门前宝宝不想穿鞋\"}"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.source.type").value("custom"))
                    .andExpect(jsonPath("$.source.presetSceneId").doesNotExist())
                    .andReturn()
                    .getResponse()
                    .getContentAsString();

            reusedPresetBody = mockMvc.perform(familyGeneration(
                            primary.accessToken(),
                            "family-primary-reuse-install",
                            "family-preset-primary-reuse",
                            "{\"type\":\"preset\",\"presetSceneId\":\"bath_time\"}"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.source.presetSceneId").value("bath_time"))
                    .andReturn()
                    .getResponse()
                    .getContentAsString();

            outsiderErrorBody = mockMvc.perform(familyGeneration(
                            outsider.accessToken(),
                            "family-outsider-install",
                            "family-outsider-request",
                            "{\"type\":\"custom\",\"text\":\"出门前宝宝不想穿鞋\"}"))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("profile_unavailable"))
                    .andReturn()
                    .getResponse()
                    .getContentAsString();

            assertThat(new tools.jackson.databind.ObjectMapper().readTree(reusedPresetBody)
                    .get("generatedContentId").asText())
                    .isEqualTo(new tools.jackson.databind.ObjectMapper().readTree(presetBody)
                            .get("generatedContentId").asText());

            syncEvent(caregiver.accessToken(), "family-caregiver-install", "family-caregiver-event",
                    "daily_care", "bath_time", "bath_time_warm_water", "resisting",
                    java.time.Instant.now().minusSeconds(10).toString());
        } finally {
            detachRootLogger(appender);
        }

        var presetJson = new tools.jackson.databind.ObjectMapper().readTree(presetBody);
        var customJson = new tools.jackson.databind.ObjectMapper().readTree(customBody);
        var generatedPresetId = presetJson.get("generatedContentId").asText();
        var generatedCustomId = customJson.get("generatedContentId").asText();
        assertThat(generatedPresetId).isNotEqualTo(generatedCustomId);
        assertPrivacySafe(presetBody, privacyForbidden);
        assertPrivacySafe(customBody, privacyForbidden);
        assertPrivacySafe(reusedPresetBody, privacyForbidden);
        assertPrivacySafe(outsiderErrorBody, privacyForbidden);
        var logs = appenderText(appender);
        assertPrivacySafe(logs, privacyForbidden);

        var rows = jdbcTemplate.queryForList(
                """
                select generated_content_id, owner_scope, account_id, profile_id, profile_version,
                       household_context_version, input_source, preset_activity_id,
                       preset_scene_version_id, normalized_scene_text, status, mode, surface,
                       installation_ref_hash, generation_profile_version, space_slug, activity_slug
                from practice_generated_content
                order by input_source asc
                """);
        assertThat(rows).hasSize(2);
        var presetRow = rows.stream()
                .filter(row -> "preset".equals(row.get("input_source")))
                .findFirst()
                .orElseThrow();
        var customRow = rows.stream()
                .filter(row -> "custom".equals(row.get("input_source")))
                .findFirst()
                .orElseThrow();
        assertThat(presetRow)
                .containsEntry("generated_content_id", generatedPresetId)
                .containsEntry("owner_scope", "profile")
                .containsEntry("account_id", primary.accountId())
                .containsEntry("profile_id", profileId)
                .containsEntry("profile_version", 1)
                .containsEntry("input_source", "preset")
                .containsEntry("preset_activity_id", presetActivityId)
                .containsEntry("preset_scene_version_id", presetVersionId)
                .containsEntry("normalized_scene_text", null)
                .containsEntry("space_slug", "daily_care")
                .containsEntry("activity_slug", "bath_time")
                .containsEntry("status", "active")
                .containsEntry("mode", "scene_generation")
                .containsEntry("surface", "care_path");
        assertThat(customRow)
                .containsEntry("generated_content_id", generatedCustomId)
                .containsEntry("owner_scope", "profile")
                .containsEntry("account_id", primary.accountId())
                .containsEntry("profile_id", profileId)
                .containsEntry("profile_version", 1)
                .containsEntry("input_source", "custom")
                .containsEntry("preset_activity_id", null)
                .containsEntry("preset_scene_version_id", null)
                .containsEntry("normalized_scene_text", "出门前宝宝不想穿鞋")
                .containsEntry("status", "active")
                .containsEntry("mode", "scene_generation")
                .containsEntry("surface", "care_path");
        assertThat(presetRow.get("household_context_version").toString())
                .matches("\\d{4}-W\\d{2}");
        assertThat(customRow.get("household_context_version"))
                .isEqualTo(presetRow.get("household_context_version"));
        assertThat(customRow.get("space_slug").toString())
                .matches("gen_scene_[a-f0-9]{20}");
        assertThat(customRow.get("activity_slug").toString())
                .matches("gen_activity_[a-f0-9]{20}");
        assertThat(presetRow.get("installation_ref_hash")).isNull();
        assertThat(customRow.get("installation_ref_hash")).isNull();
        assertThat(presetRow.get("generation_profile_version")).isNotNull();
        assertThat(customRow.get("generation_profile_version"))
                .isEqualTo(presetRow.get("generation_profile_version"));
        assertThat(rows)
                .allSatisfy(row -> assertThat(row.get("account_id"))
                        .isEqualTo(primary.accountId())
                        .isNotEqualTo(caregiver.accountId())
                        .isNotEqualTo(outsider.accountId()));

        var event = jdbcTemplate.queryForMap(
                """
                select account_id, space_id, activity_id, phrase_id, reaction_type
                from interaction_events
                where account_id = ?
                  and space_id = 'daily_care'
                  and activity_id = 'bath_time'
                  and phrase_id = 'bath_time_warm_water'
                  and reaction_type = 'resisting'
                """,
                caregiver.accountId());
        assertThat(event)
                .containsEntry("account_id", caregiver.accountId())
                .containsEntry("space_id", "daily_care")
                .containsEntry("activity_id", "bath_time")
                .containsEntry("phrase_id", "bath_time_warm_water")
                .containsEntry("reaction_type", "resisting");
        assertThat(event.get("account_id")).isNotEqualTo(primary.accountId());
        var starterUtteranceId = jdbcTemplate.queryForObject(
                "select utterance_id from practice_generated_content_utterances where generated_content_id = ? and role = 'starter'",
                String.class,
                generatedPresetId);
        assertThat(generatedContentQueryMapper.findActiveAccessibleByAccountId(
                generatedPresetId, primary.accountId())).isNotNull();
        assertThat(generatedContentQueryMapper.findActiveAccessibleByAccountId(
                generatedPresetId, caregiver.accountId())).isNotNull();
        assertThat(generatedContentQueryMapper.findActiveAccessibleByAccountId(
                generatedPresetId, outsider.accountId())).isNull();
        var audioAppender = attachRootLogger();
        String outsiderAudio;
        String revokedAudio;
        try {
        mockMvc.perform(get("/api/v1/practice/generated-content/{contentId}/utterances/{utteranceId}/audio",
                        generatedPresetId, starterUtteranceId)
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.3.0")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + primary.accessToken()))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.valueOf("audio/mpeg")));
        mockMvc.perform(get("/api/v1/practice/generated-content/{contentId}/utterances/{utteranceId}/audio",
                        generatedPresetId, starterUtteranceId)
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.3.0")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver.accessToken()))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.valueOf("audio/mpeg")));
        outsiderAudio = mockMvc.perform(get(
                        "/api/v1/practice/generated-content/{contentId}/utterances/{utteranceId}/audio",
                        generatedPresetId, starterUtteranceId)
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.3.0")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + outsider.accessToken()))
                .andExpect(status().isNotFound())
                .andReturn()
                .getResponse()
                .getContentAsString();
        assertPrivacySafe(outsiderAudio, privacyForbidden);

        jdbcTemplate.update(
                "update household_members set status = 'revoked' where household_id = ? and account_id = ?",
                invite.householdId(), caregiver.accountId());
        assertThat(generatedContentQueryMapper.findActiveAccessibleByAccountId(
                generatedPresetId, caregiver.accountId())).isNull();
        revokedAudio = mockMvc.perform(get(
                        "/api/v1/practice/generated-content/{contentId}/utterances/{utteranceId}/audio",
                        generatedPresetId, starterUtteranceId)
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.3.0")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver.accessToken()))
                .andExpect(status().isNotFound())
                .andReturn()
                .getResponse()
                .getContentAsString();
        assertPrivacySafe(revokedAudio, privacyForbidden);
        assertThat(generatedContentQueryMapper.findActiveAccessibleByAccountId(
                generatedPresetId, primary.accountId())).isNotNull();
        mockMvc.perform(get("/api/v1/practice/generated-content/{contentId}/utterances/{utteranceId}/audio",
                        generatedPresetId, starterUtteranceId)
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.3.0")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + primary.accessToken()))
                .andExpect(status().isOk());
        } finally {
            detachRootLogger(audioAppender);
        }
        assertPrivacySafe(appenderText(audioAppender), privacyForbidden);
    }

    @Test
    void familyAudioPrivacyContractIncludesEveryGenerationIdentifier() {
        var forbidden = familyPrivacyForbiddenValues(
                "primary-account",
                "caregiver-account",
                "outsider-account",
                "profile-id",
                new InviteView("household-id", "invite-token"),
                "preset brief");

        assertThat(forbidden)
                .contains(
                        "primary-account", "caregiver-account", "outsider-account", "profile-id",
                        "household-id", "invite-token", "13800139999", "13900139998", "13700137777",
                        "install-agentic-session", "family-caregiver-install",
                        "family-caregiver-custom-install", "family-primary-reuse-install",
                        "family-outsider-install", "family-primary-event", "family-caregiver-event",
                        "family-preset-caregiver", "family-custom-caregiver", "family-preset-primary-reuse",
                        "family-outsider-request", "出门前宝宝不想穿鞋", "preset brief",
                        "ScenePersonalizationContext{");
    }

    private String[] familyPrivacyForbiddenValues(
            String primaryAccountId,
            String caregiverAccountId,
            String outsiderAccountId,
            String profileId,
            InviteView invite,
            String presetBrief
    ) {
        return new String[] {
            primaryAccountId, caregiverAccountId, outsiderAccountId, profileId,
            invite.householdId(), invite.token(),
            "13800139999", "13900139998", "13700137777",
            "install-agentic-session", "family-caregiver-install",
            "family-caregiver-custom-install", "family-primary-reuse-install",
            "family-outsider-install", "family-primary-event", "family-caregiver-event",
            "family-preset-caregiver", "family-custom-caregiver", "family-preset-primary-reuse",
            "family-outsider-request", "出门前宝宝不想穿鞋", presetBrief,
            "ScenePersonalizationContext{"
        };
    }

    private ListAppender<ILoggingEvent> attachRootLogger() {
        return attachLogger(Logger.ROOT_LOGGER_NAME);
    }

    private ListAppender<ILoggingEvent> attachLogger(String loggerName) {
        return attachLogger(LoggerFactory.getLogger(loggerName));
    }

    private ListAppender<ILoggingEvent> attachLogger(org.slf4j.Logger logger) {
        var appender = new ListAppender<ILoggingEvent>();
        appender.start();
        ((Logger) logger).addAppender(appender);
        return appender;
    }

    private void detachRootLogger(ListAppender<ILoggingEvent> appender) {
        ((Logger) LoggerFactory.getLogger(Logger.ROOT_LOGGER_NAME)).detachAppender(appender);
        appender.stop();
    }

    private String appenderText(ListAppender<ILoggingEvent> appender) {
        return appender.list.stream()
                .map(event -> event.getFormattedMessage()
                        + "|mdc=" + event.getMDCPropertyMap()
                        + "|throwable=" + throwableText(event.getThrowableProxy()))
                .collect(Collectors.joining("\n"));
    }

    private String throwableText(IThrowableProxy throwable) {
        if (throwable == null) {
            return "";
        }
        return throwable.getClassName() + ":" + throwable.getMessage()
                + "|cause=" + throwableText(throwable.getCause());
    }

    private void assertPrivacySafe(String value, String... forbiddenValues) {
        assertThat(value).isNotNull();
        for (var forbidden : forbiddenValues) {
            assertThat(value).doesNotContain(forbidden);
        }
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder familyGeneration(
            String accessToken,
            String installationId,
            String clientRequestId,
            String source
    ) {
        return post("/api/v1/practice/scene-generations")
                .header(ApiVersionInterceptor.VERSION_HEADER, "1.3.0")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"source":%s,"locale":"zh-CN","installationId":"%s","clientRequestId":"%s"}
                        """.formatted(source, installationId, clientRequestId));
    }

    private AuthConsentSyncService.SessionResponse createAcceptedSession(
            String phoneNumber,
            String installationId
    ) {
        var challenge = authConsentSyncService.createChallenge(phoneNumber);
        var created = authConsentSyncService.verifyChallenge(
                challenge.challengeId(), "246810", installationId);
        authConsentSyncService.acceptConsent(created.sessionId(), "pipl-v1");
        return created;
    }

    private InviteView createInvite(String accessToken) throws Exception {
        var response = mockMvc.perform(post("/api/v1/caregiver-invites")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.3.0")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"role":"caregiver","source":"household_settings"}
                                """))
                .andExpect(status().isCreated())
                .andReturn();
        var json = new tools.jackson.databind.ObjectMapper()
                .readTree(response.getResponse().getContentAsString());
        return new InviteView(json.get("householdId").asText(), json.get("token").asText());
    }

    private void acceptInvite(String accessToken, String token) throws Exception {
        mockMvc.perform(post("/api/v1/caregiver-invites/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.3.0")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"token":"%s","source":"invite_link"}
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
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.3.0")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"%s",
                                  "events":[{
                                    "eventKey":"%s:%s",
                                    "localEventId":"%s",
                                    "installationId":"%s",
                                    "spaceId":"%s",
                                    "activityId":"%s",
                                    "phraseId":"%s",
                                    "reactionType":"%s",
                                    "clientTimestamp":"%s"
                                  }]
                                }
                                """.formatted(
                                installationId, installationId, localEventId, localEventId, installationId,
                                spaceId, activityId, phraseId, reactionType, clientTimestamp)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acceptedCount").value(1));
    }

    private record InviteView(String householdId, String token) {
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder generation(
            String installationId,
            String scene
    ) {
        return post("/api/v1/practice/scene-generations")
                .header(ApiVersionInterceptor.VERSION_HEADER, "1.3.0")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + session.accessToken())
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"source":{"type":"custom","text":"%s"},"locale":"zh-CN",
                        "installationId":"%s","clientRequestId":"request_%s_%s"}
                        """.formatted(
                                scene,
                                installationId,
                                installationId,
                                Integer.toUnsignedString(scene.hashCode())));
    }

    private int count(String table) {
        return jdbcTemplate.queryForObject("select count(*) from " + table, Integer.class);
    }

    @TestConfiguration
    static class StubProviderConfiguration {

        @Bean
        @Primary
        StubEvidenceRetriever stubEvidenceRetriever(
                @Qualifier("baselineFamilyEnglishEvidenceSource") CustomSceneEvidenceRetriever baseline,
                @Qualifier("palaceCustomSceneEvidenceSource") CustomSceneEvidenceRetriever palace,
                VersionedResourceRegistry registry
        ) {
            return new StubEvidenceRetriever(baseline, palace, registry);
        }
    }

    enum StubMode {
        PASS,
        PII,
        JUDGE_EXHAUSTED,
        REPAIR_THEN_PASS,
        JUDGE_TPR_REPAIR_THEN_PASS,
        ATTEMPT_EXHAUSTED,
        DUPLICATE_KEY,
        TRAILING_TOKENS
    }

    enum EvidenceMode {
        SUFFICIENT,
        INSUFFICIENT
    }

    static class StubEvidenceRetriever extends CompositeCustomSceneEvidenceRetriever {

        private final AtomicReference<EvidenceMode> mode = new AtomicReference<>(EvidenceMode.SUFFICIENT);
        private int externalDelegationCalls;

        StubEvidenceRetriever(
                CustomSceneEvidenceRetriever baseline,
                CustomSceneEvidenceRetriever palace,
                VersionedResourceRegistry registry
        ) {
            super(baseline, palace, registry);
        }

        synchronized void mode(EvidenceMode value) {
            mode.set(value);
            externalDelegationCalls = 0;
        }

        synchronized int externalDelegationCalls() {
            return externalDelegationCalls;
        }

        @Override
        public EvidenceRetrievalResult retrieve(EvidenceRetrievalRequest request) {
            if (mode.get() == EvidenceMode.INSUFFICIENT) {
                return new EvidenceRetrievalResult(List.of(), request.retrievalTraceId(), RetrievalStatus.INSUFFICIENT);
            }
            return new EvidenceRetrievalResult(
                    List.of(
                            evidence("scene_support", "Keep the routine familiar and concrete."),
                            evidence("parent_speakability", "Use short words a parent can say naturally."),
                            evidence("age_guidance", "Keep the invitation playful and age appropriate."),
                            evidence("low_pressure_delivery", "Allow silence and repetition without correction.")),
                    request.retrievalTraceId(),
                    RetrievalStatus.INITIAL);
        }

        private EvidenceItem evidence(String claimType, String summary) {
            return new EvidenceItem(
                    "stub-" + claimType,
                    ReplayMode.SNAPSHOT,
                    "strategy_pack",
                    "stub-evidence-v1",
                    "stub-strategy-v1",
                    claimType,
                    summary,
                    sha256(summary),
                    0.9d);
        }

        private String sha256(String value) {
            try {
                return java.util.HexFormat.of().formatHex(
                        MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
            } catch (NoSuchAlgorithmException exception) {
                throw new IllegalStateException("SHA-256 unavailable", exception);
            }
        }
    }

    static class StubResponses {

        private final AtomicReference<StubMode> mode = new AtomicReference<>(StubMode.PASS);
        private int calls;
        private int completeBundleCalls;
        private int judgeCalls;
        private String repairSystemPrompt;
        private String repairUserPrompt;
        private final ArrayList<String> judgeSystemPrompts = new ArrayList<>();
        private final ArrayList<String> judgeUserPrompts = new ArrayList<>();

        synchronized void mode(StubMode value) {
            mode.set(value);
            calls = 0;
            completeBundleCalls = 0;
            judgeCalls = 0;
            repairSystemPrompt = null;
            repairUserPrompt = null;
            judgeSystemPrompts.clear();
            judgeUserPrompts.clear();
        }

        synchronized int calls() {
            return calls;
        }

        synchronized String repairSystemPrompt() {
            return repairSystemPrompt;
        }

        synchronized String repairUserPrompt() {
            return repairUserPrompt;
        }

        synchronized List<String> judgeSystemPrompts() {
            return List.copyOf(judgeSystemPrompts);
        }

        synchronized List<String> judgeUserPrompts() {
            return List.copyOf(judgeUserPrompts);
        }

        synchronized Object call(String systemPrompt, String userPrompt, Class<?> responseType) {
            calls++;
            if (responseType == CompleteGeneratedBundle.ProviderResponse.class) {
                return completeBundleCalls++ == 0 ? generatorResponse() : repairResponse();
            }
            if (responseType == AgenticCustomSceneQualityJudge.JudgeWireResponse.class) {
                judgeSystemPrompts.add(systemPrompt);
                judgeUserPrompts.add(userPrompt);
                if (mode.get() == StubMode.JUDGE_EXHAUSTED) {
                    throw new PracticeAiStructuredOutputCaller.StructuredOutputInvalidException();
                }
                if (mode.get() == StubMode.JUDGE_TPR_REPAIR_THEN_PASS && judgeCalls++ == 0) {
                    return tprRepairJudgeResponse();
                }
                return passJudgeResponse();
            }
            throw new AssertionError("unexpected response type " + responseType.getName());
        }

        synchronized String callRaw(String systemPrompt, String userPrompt, Class<?> responseType) {
            if (responseType != CompleteGeneratedBundle.ProviderResponse.class) {
                throw new AssertionError("unexpected raw response type " + responseType.getName());
            }
            calls++;
            var currentBundleCall = completeBundleCalls++;
            if (currentBundleCall > 0) {
                repairSystemPrompt = systemPrompt;
                repairUserPrompt = userPrompt;
            }
            var json = new tools.jackson.databind.ObjectMapper().writeValueAsString(
                    currentBundleCall == 0 ? generatorResponse() : repairResponse());
            return switch (mode.get()) {
                case DUPLICATE_KEY -> "{\"schemaVersion\":\"wrong\"," + json.substring(1);
                case TRAILING_TOKENS -> json + " {}";
                default -> json;
            };
        }

        private CompleteGeneratedBundle.ProviderResponse generatorResponse() {
            return switch (mode.get()) {
                case PII -> generator("宝宝叫小明，出门穿鞋。", "拿起鞋子。", "慢慢说一遍。");
                case REPAIR_THEN_PASS, ATTEMPT_EXHAUSTED -> generator("穿鞋出门。", "慢慢说一遍。", "慢慢说一遍。");
                case JUDGE_TPR_REPAIR_THEN_PASS -> generator("穿鞋出门。", "看着毛巾。", "慢慢说一遍。");
                default -> generator("穿鞋出门。", "拿起鞋子。", "慢慢说一遍。");
            };
        }

        private CompleteGeneratedBundle.ProviderResponse repairResponse() {
            return switch (mode.get()) {
                case ATTEMPT_EXHAUSTED -> repair("慢慢说一遍。", "慢慢说一遍。");
                default -> repair("拿起鞋子。", "慢慢说一遍。");
            };
        }

        private CompleteGeneratedBundle.ProviderResponse generator(
                String chineseText,
                String tprAction,
                String deliveryGuidance
        ) {
            return bundle(chineseText, tprAction, deliveryGuidance);
        }

        private CompleteGeneratedBundle.ProviderResponse repair(String tprAction, String deliveryGuidance) {
            return bundle("穿鞋出门。", tprAction, deliveryGuidance);
        }

        private CompleteGeneratedBundle.ProviderResponse bundle(
                String chineseText,
                String tprAction,
                String deliveryGuidance
        ) {
            return new CompleteGeneratedBundle.ProviderResponse(
                    CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION,
                    new CompleteGeneratedBundle.SceneMetadata("日常照护", "穿鞋出门", "Shoes on"),
                    new CompleteGeneratedBundle.ProviderUtterances(
                            utterance(CompleteGeneratedBundle.UtteranceRole.STARTER, null, 1,
                                    chineseText, tprAction, deliveryGuidance),
                            utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                    CompleteGeneratedBundle.Reaction.COOPERATING, 2,
                                    chineseText, tprAction, deliveryGuidance),
                            utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                    CompleteGeneratedBundle.Reaction.HESITANT, 3,
                                    chineseText, tprAction, deliveryGuidance),
                            utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                    CompleteGeneratedBundle.Reaction.RESISTING, 4,
                                    chineseText, tprAction, deliveryGuidance),
                            utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                    CompleteGeneratedBundle.Reaction.NO_RESPONSE, 5,
                                    chineseText, tprAction, deliveryGuidance),
                            utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                    CompleteGeneratedBundle.Reaction.OTHER, 6,
                                    chineseText, tprAction, deliveryGuidance)));
        }

        private CompleteGeneratedBundle.ProviderUtterance utterance(
                CompleteGeneratedBundle.UtteranceRole role,
                CompleteGeneratedBundle.Reaction reaction,
                int displayOrder,
                String chineseText,
                String tprAction,
                String deliveryGuidance
        ) {
            return new CompleteGeneratedBundle.ProviderUtterance(
                    role, reaction, "Shoes on.", chineseText, "shoes on", tprAction, deliveryGuidance,
                    "starter", displayOrder);
        }

        private AgenticCustomSceneQualityJudge.JudgeWireResponse passJudgeResponse() {
            var dimensions = new EnumMap<JudgeDimension, DimensionResult>(JudgeDimension.class);
            for (var dimension : JudgeDimension.values()) {
                dimensions.put(dimension, DimensionResult.PASS);
            }
            return new AgenticCustomSceneQualityJudge.JudgeWireResponse(
                    JudgeVerdict.PASS, dimensions, List.of(), List.of(), List.of(), 1.0d);
        }

        private AgenticCustomSceneQualityJudge.JudgeWireResponse tprRepairJudgeResponse() {
            var dimensions = new EnumMap<JudgeDimension, DimensionResult>(JudgeDimension.class);
            for (var dimension : JudgeDimension.values()) {
                dimensions.put(dimension, DimensionResult.PASS);
            }
            dimensions.put(JudgeDimension.TPR_QUALITY, DimensionResult.FAIL);
            return new AgenticCustomSceneQualityJudge.JudgeWireResponse(
                    JudgeVerdict.REPAIR,
                    dimensions,
                    List.of("TPR_QUALITY_FAILED"),
                    List.of(RepairDirective.REPAIR_TPR_QUALITY),
                    List.of(),
                    0.9d);
        }
    }
}
