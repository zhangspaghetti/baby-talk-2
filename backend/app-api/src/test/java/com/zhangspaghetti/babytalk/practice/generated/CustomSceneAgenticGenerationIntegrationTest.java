package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
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
import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.EnumMap;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
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
@Import(CustomSceneAgenticGenerationIntegrationTest.StubProviderConfiguration.class)
class CustomSceneAgenticGenerationIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @MockitoBean(name = "practiceAiStructuredOutputCaller")
    private PracticeAiStructuredOutputCaller structuredOutputCaller;

    private final StubResponses caller = new StubResponses();

    @Autowired
    private StubEvidenceRetriever evidenceRetriever;

    @BeforeEach
    void resetStub() {
        caller.mode(StubMode.PASS);
        evidenceRetriever.mode(EvidenceMode.SUFFICIENT);
        doAnswer(invocation -> caller.callRaw((Class<?>) invocation.getArgument(3)))
                .when(structuredOutputCaller)
                .callRaw(any(), anyString(), anyString(), any());
        doAnswer(invocation -> caller.call((Class<?>) invocation.getArgument(3)))
                .when(structuredOutputCaller)
                .call(any(), anyString(), anyString(), any());
    }

    @Test
    void firstEndpointRequestAuditsEveryStepActivatesAndExactReuseMakesNoExtraProviderCalls() throws Exception {
        var first = mockMvc.perform(discovery("install_agentic_1", "出门前宝宝不想穿鞋"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.source").value("generated"))
                .andExpect(jsonPath("$.generatedContentId").isNotEmpty())
                .andExpect(jsonPath("$.moments[0].coachTip").value("拿起鞋子。 慢慢说一遍。"))
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
                generatedContentId)).isNull();

        mockMvc.perform(discovery("install_agentic_1", "出门前宝宝不想穿鞋"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.generatedContentId").value(generatedContentId));

        assertThat(count("practice_ai_provider_calls")).isEqualTo(2);
        assertThat(caller.calls()).isEqualTo(2);
    }

    @Test
    void bidiInputIsRejectedBeforeDraftOrProviderCall() throws Exception {
        mockMvc.perform(discovery("install_agentic_bidi", "出门前\u202E宝宝不想穿鞋"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("unsafe_custom_scene_text"));

        assertThat(count("practice_generated_content")).isZero();
        assertThat(count("practice_ai_provider_calls")).isZero();
    }

    @Test
    void dailyQuotaDenialExpiresSecondDraftBeforeGeneratorCall() throws Exception {
        mockMvc.perform(discovery("install_agentic_daily", "出门前宝宝不想穿鞋"))
                .andExpect(status().isOk());
        var callsAfterFirst = count("practice_ai_provider_calls");

        mockMvc.perform(discovery("install_agentic_daily", "睡前宝宝想抱抱"))
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

        mockMvc.perform(discovery("install_agentic_judge", "出门前宝宝不想穿鞋"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("generation_unavailable"))
                .andExpect(jsonPath("$.details.retryable").value(true));

        assertThat(jdbcTemplate.queryForObject("select status from practice_generated_content", String.class))
                .isEqualTo("expired");
    }

    @Test
    void insufficientEvidenceExpiresBeforeProviderCall() throws Exception {
        evidenceRetriever.mode(EvidenceMode.INSUFFICIENT);

        mockMvc.perform(discovery("install_agentic_evidence", "出门前宝宝不想穿鞋"))
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

        mockMvc.perform(discovery("install_agentic_pii", "出门前宝宝不想穿鞋"))
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

        mockMvc.perform(discovery("install_agentic_duplicate", "出门前宝宝不想穿鞋"))
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

        mockMvc.perform(discovery("install_agentic_trailing", "出门前宝宝不想穿鞋"))
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

        mockMvc.perform(discovery("install_agentic_repair", "出门前宝宝不想穿鞋"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.source").value("generated"));

        assertThat(count("practice_generated_content_attempts")).isEqualTo(2);
        assertThat(count("practice_generated_content_evidence_bundles")).isEqualTo(2);
        assertThat(count("practice_generated_content_judge_results")).isEqualTo(1);
    }

    @Test
    void attemptsExhaustedRejectsTerminalRow() throws Exception {
        caller.mode(StubMode.ATTEMPT_EXHAUSTED);

        mockMvc.perform(discovery("install_agentic_exhaust", "出门前宝宝不想穿鞋"))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.code").value("generation_invalid_output"));

        assertThat(jdbcTemplate.queryForObject("select status from practice_generated_content", String.class))
                .isEqualTo("rejected");
        assertThat(count("practice_generated_content_attempts")).isEqualTo(2);
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder discovery(
            String installationId,
            String scene
    ) {
        return post("/api/v1/practice/discovery")
                .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"surface":"onboarding","mode":"custom_scene","installationId":"%s",
                        "ageRange":"m7_11","parentGoal":"calmer_care","locale":"zh-CN","customSceneText":"%s"}
                        """.formatted(installationId, scene));
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

        synchronized void mode(StubMode value) {
            mode.set(value);
            calls = 0;
            completeBundleCalls = 0;
        }

        synchronized int calls() {
            return calls;
        }

        synchronized Object call(Class<?> responseType) {
            calls++;
            if (responseType == CompleteGeneratedBundle.ProviderResponse.class) {
                return completeBundleCalls++ == 0 ? generatorResponse() : repairResponse();
            }
            if (responseType == AgenticCustomSceneQualityJudge.JudgeWireResponse.class) {
                if (mode.get() == StubMode.JUDGE_EXHAUSTED) {
                    throw new PracticeAiStructuredOutputCaller.StructuredOutputInvalidException();
                }
                return passJudgeResponse();
            }
            throw new AssertionError("unexpected response type " + responseType.getName());
        }

        synchronized String callRaw(Class<?> responseType) {
            if (responseType != CompleteGeneratedBundle.ProviderResponse.class) {
                throw new AssertionError("unexpected raw response type " + responseType.getName());
            }
            calls++;
            var json = new tools.jackson.databind.ObjectMapper().writeValueAsString(
                    completeBundleCalls++ == 0 ? generatorResponse() : repairResponse());
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
            var utterances = new java.util.LinkedHashMap<String, CompleteGeneratedBundle.ProviderUtterance>();
            utterances.put("starter", utterance(CompleteGeneratedBundle.UtteranceRole.STARTER, null, 1,
                    chineseText, tprAction, deliveryGuidance));
            for (var reaction : CompleteGeneratedBundle.Reaction.values()) {
                utterances.put(reaction.wireValue(), utterance(
                        CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                        reaction,
                        reaction.ordinal() + 2,
                        chineseText,
                        tprAction,
                        deliveryGuidance));
            }
            return new CompleteGeneratedBundle.ProviderResponse(
                    CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION,
                    new CompleteGeneratedBundle.SceneMetadata("日常照护", "穿鞋出门", "Shoes on"),
                    utterances);
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
    }
}
