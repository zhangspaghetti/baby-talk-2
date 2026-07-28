package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.agentic.OperationRequest;
import com.zhangspaghetti.babytalk.practice.agentic.OperationResult;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiCapability;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiOperationRunner;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller;
import com.zhangspaghetti.babytalk.practice.agentic.ResolvedProvider;
import com.zhangspaghetti.babytalk.practice.agentic.config.GenerationProfile;
import com.zhangspaghetti.babytalk.practice.agentic.config.QualityRubric;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedRef;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratedPracticeContentCandidate;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneQualityJudge.JudgeRequest;
import com.zhangspaghetti.babytalk.practice.generated.quality.DimensionResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeDimension;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeResultAuditPort;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdict;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdictCalculator;
import java.util.Arrays;
import java.util.EnumMap;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.ai.chat.client.ChatClient;
import tools.jackson.databind.ObjectMapper;

class AgenticCustomSceneQualityJudgeTest {

    private static final UUID OPERATION_RUN_ID = UUID.fromString("30000000-0000-0000-0000-000000000001");
    private static final UUID PROVIDER_CALL_ID = UUID.fromString("30000000-0000-0000-0000-000000000002");
    private static final UUID EVIDENCE_BUNDLE_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");

    @Test
    void requestContainsOnlyApprovedBusinessFieldsAndAuditIds() {
        assertThat(Arrays.stream(JudgeRequest.class.getRecordComponents())
                .map(component -> component.getName())
                .toList())
                .containsExactly(
                        "generatedContentId",
                        "attemptNumber",
                        "evidenceBundleId",
                        "displayText",
                        "ageRange",
                        "parentGoal",
                        "candidate",
                        "careMoment",
                        "strategyIds",
                        "communicationPrimitiveIds",
                        "ageGuidanceTags",
                        "safetyConstraintTags",
                        "orderedSanitizedEvidenceSummaries",
                        "rubricVersion",
                        "rubricContentHash")
                .doesNotContain(
                        "securityText",
                        "rawEvidenceChunks",
                        "accountId",
                        "profileId",
                        "deviceId",
                        "providerPrompt",
                        "providerResponse",
                        "logs",
                        "reasoning");
    }

    @Test
    @SuppressWarnings({"unchecked", "rawtypes"})
    void runsMandatoryJudgeRoutePersistsReceiptBoundResultAndReturnsSuggestion() {
        var runner = mock(PracticeAiOperationRunner.class);
        var caller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        var auditPort = mock(JudgeResultAuditPort.class);
        var provider = new ResolvedProvider("primary", "openai-compatible", "gpt-test", mock(ChatClient.class));
        var operationCaptor = ArgumentCaptor.forClass(OperationRequest.class);
        when(registry.currentGenerationProfile()).thenReturn(profile());
        when(registry.qualityRubric()).thenReturn(rubric());
        when(registry.promptText(VersionedResourceRegistry.PromptKind.JUDGE)).thenReturn("JUDGE SYSTEM PROMPT");
        when(caller.call(eq(provider), eq("JUDGE SYSTEM PROMPT"), any(String.class),
                eq(AgenticCustomSceneQualityJudge.JudgeWireResponse.class))).thenReturn(passWire());
        when(runner.execute(operationCaptor.capture())).thenAnswer(invocation -> {
            var operation = (OperationRequest) invocation.getArgument(0);
            var invoked = operation.invocation().invoke(provider);
            return new OperationResult<>(
                    invoked.value(), OPERATION_RUN_ID, PROVIDER_CALL_ID, "primary", "gpt-test", null);
        });
        var judge = new AgenticCustomSceneQualityJudge(
                runner, caller, registry, new JudgeVerdictCalculator(), auditPort);

        var result = judge.judge(request());

        assertThat(result.suggestedVerdict()).isEqualTo(JudgeVerdict.PASS);
        assertThat(result.dimensionResults().values()).containsOnly(DimensionResult.PASS);
        var operation = operationCaptor.getValue();
        assertThat(operation.capability()).isEqualTo(PracticeAiCapability.CUSTOM_SCENE_QUALITY_JUDGE);
        assertThat(operation.subjectType()).isEqualTo("generated_content");
        assertThat(operation.subjectId()).isEqualTo("pgc_judge_test");
        assertThat(operation.generatedContentId()).isEqualTo("pgc_judge_test");
        assertThat(operation.attemptNumber()).isEqualTo(2);
        assertThat(operation.evidenceBundleId()).isEqualTo(EVIDENCE_BUNDLE_ID);
        assertThat(operation.promptVersion()).isEqualTo("judge-v1");
        assertThat(operation.promptHash()).isEqualTo("c".repeat(64));
        assertThat(operation.policyVersion()).isEqualTo("rubric-v1");
        assertThat(operation.policyHash()).isEqualTo("9".repeat(64));

        var promptCaptor = ArgumentCaptor.forClass(String.class);
        verify(caller).call(
                eq(provider), eq("JUDGE SYSTEM PROMPT"), promptCaptor.capture(),
                eq(AgenticCustomSceneQualityJudge.JudgeWireResponse.class));
        var prompt = promptCaptor.getValue();
        assertThat(prompt)
                .contains(
                        "给宝宝穿鞋",
                        "m7_11",
                        "calmer_care",
                        "Shoes on.",
                        "family-english-strategy-v1",
                        "joint_attention",
                        "先轻声说。",
                        "再停下来观察。",
                        "rubric-v1",
                        "9".repeat(64),
                        "agentic_search")
                .doesNotContain(
                        "pgc_judge_test",
                        "securityText",
                        "rawEvidenceChunks",
                        "accountId",
                        "profileId",
                        "deviceId",
                        "providerPrompt",
                        "providerResponse",
                        "providerTraceId",
                        "modelName",
                        "reasoning");
        assertThat(prompt.indexOf("先轻声说。"))
                .isLessThan(prompt.indexOf("再停下来观察。"));
        @SuppressWarnings("unchecked")
        var payload = (java.util.Map<String, Object>) new ObjectMapper().readValue(prompt, java.util.Map.class);
        assertThat(payload.keySet()).containsExactly(
                "displayText",
                "ageRange",
                "parentGoal",
                "candidate",
                "reactionSupports",
                "strategyIds",
                "communicationPrimitiveIds",
                "ageGuidanceTags",
                "safetyConstraintTags",
                "orderedSanitizedEvidenceSummaries",
                "rubricVersion",
                "rubricContentHash");
        assertThat((java.util.Map<String, Object>) payload.get("candidate"))
                .containsKey("generationSource");
        var reactionSupports = (java.util.List<java.util.Map<String, Object>>) payload.get("reactionSupports");
        assertThat(reactionSupports).hasSize(5);
        assertThat(reactionSupports.get(0).get("reactionType")).isEqualTo("cooperating");

        var auditCaptor = ArgumentCaptor.forClass(JudgeResultAuditPort.JudgeAuditRecord.class);
        verify(auditPort).persist(auditCaptor.capture());
        assertThat(auditCaptor.getValue().providerCallId()).isEqualTo(PROVIDER_CALL_ID);
        assertThat(auditCaptor.getValue().suggested()).isEqualTo(result);
        assertThat(auditCaptor.getValue().effective().effectiveVerdict()).isEqualTo(JudgeVerdict.PASS);
        assertThat(auditCaptor.getValue().rubric()).isEqualTo(rubric());
    }

    @Test
    @SuppressWarnings({"unchecked", "rawtypes"})
    void structuredOutputInvalidEscapesCallbackWithoutInternalRecovery() {
        var runner = mock(PracticeAiOperationRunner.class);
        var caller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        var auditPort = mock(JudgeResultAuditPort.class);
        var provider = new ResolvedProvider("primary", "openai-compatible", "gpt-test", mock(ChatClient.class));
        when(registry.currentGenerationProfile()).thenReturn(profile());
        when(registry.qualityRubric()).thenReturn(rubric());
        when(registry.promptText(VersionedResourceRegistry.PromptKind.JUDGE)).thenReturn("JUDGE SYSTEM PROMPT");
        var failure = new PracticeAiStructuredOutputCaller.StructuredOutputInvalidException();
        when(caller.call(eq(provider), eq("JUDGE SYSTEM PROMPT"), any(String.class),
                eq(AgenticCustomSceneQualityJudge.JudgeWireResponse.class))).thenThrow(failure);
        when(runner.execute(any())).thenAnswer(invocation -> {
            var operation = (OperationRequest) invocation.getArgument(0);
            return operation.invocation().invoke(provider);
        });
        var judge = new AgenticCustomSceneQualityJudge(
                runner, caller, registry, new JudgeVerdictCalculator(), auditPort);

        assertThatThrownBy(() -> judge.judge(request()))
                .isSameAs(failure)
                .hasMessage("structured_output_invalid");
        verify(caller, times(1)).call(
                eq(provider), eq("JUDGE SYSTEM PROMPT"), any(String.class),
                eq(AgenticCustomSceneQualityJudge.JudgeWireResponse.class));
        verifyNoInteractions(auditPort);
    }

    @Test
    void rubricDriftFailsBeforeRunnerCallerOrAudit() {
        var runner = mock(PracticeAiOperationRunner.class);
        var caller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        var auditPort = mock(JudgeResultAuditPort.class);
        when(registry.currentGenerationProfile()).thenReturn(profile());
        when(registry.qualityRubric()).thenReturn(new QualityRubric(
                "rubric-v2", "9".repeat(64), rubric().dimensions(),
                rubric().rejectOnFail(), rubric().repairOnFail(), true));
        var judge = new AgenticCustomSceneQualityJudge(
                runner, caller, registry, new JudgeVerdictCalculator(), auditPort);

        assertThatThrownBy(() -> judge.judge(request()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("judge request rubric must match current registry rubric");
        verifyNoInteractions(runner, caller, auditPort);
    }

    @Test
    @SuppressWarnings({"unchecked", "rawtypes"})
    void auditFailurePropagatesAfterExactlyOneSuccessfulProviderCall() {
        var runner = mock(PracticeAiOperationRunner.class);
        var caller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        var auditPort = mock(JudgeResultAuditPort.class);
        var provider = new ResolvedProvider("primary", "openai-compatible", "gpt-test", mock(ChatClient.class));
        when(registry.currentGenerationProfile()).thenReturn(profile());
        when(registry.qualityRubric()).thenReturn(rubric());
        when(registry.promptText(VersionedResourceRegistry.PromptKind.JUDGE)).thenReturn("JUDGE SYSTEM PROMPT");
        when(caller.call(eq(provider), eq("JUDGE SYSTEM PROMPT"), any(String.class),
                eq(AgenticCustomSceneQualityJudge.JudgeWireResponse.class))).thenReturn(passWire());
        when(runner.execute(any())).thenAnswer(invocation -> {
            var operation = (OperationRequest) invocation.getArgument(0);
            var invoked = operation.invocation().invoke(provider);
            return new OperationResult<>(
                    invoked.value(), OPERATION_RUN_ID, PROVIDER_CALL_ID, "primary", "gpt-test", null);
        });
        var failure = new IllegalStateException("judge audit unavailable");
        org.mockito.Mockito.doThrow(failure).when(auditPort).persist(any());
        var judge = new AgenticCustomSceneQualityJudge(
                runner, caller, registry, new JudgeVerdictCalculator(), auditPort);

        assertThatThrownBy(() -> judge.judge(request())).isSameAs(failure);
        verify(caller, times(1)).call(
                eq(provider), eq("JUDGE SYSTEM PROMPT"), any(String.class),
                eq(AgenticCustomSceneQualityJudge.JudgeWireResponse.class));
        verify(auditPort, times(1)).persist(any());
    }

    @Test
    void missingDimensionCannotEnterProviderCallbackAsAValidWireResult() {
        var incomplete = allPass();
        incomplete.remove(JudgeDimension.LOW_PRESSURE_SUPPORT);

        assertThatThrownBy(() -> new AgenticCustomSceneQualityJudge.JudgeWireResponse(
                JudgeVerdict.PASS, incomplete, List.of(), List.of(), List.of(), 0.8d))
                .isInstanceOf(PracticeAiStructuredOutputCaller.StructuredOutputInvalidException.class)
                .hasMessage("structured_output_invalid");
    }

    @Test
    void unknownViolationCodeFailsClosedInsideProviderCallback() {
        var failed = allPass();
        failed.put(JudgeDimension.SCENE_ALIGNMENT, DimensionResult.FAIL);

        assertWireRejected(new AgenticCustomSceneQualityJudge.JudgeWireResponse(
                JudgeVerdict.REPAIR,
                failed,
                List.of("MODEL_FREE_TEXT"),
                List.of(),
                List.of(),
                0.8d));
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private void assertWireRejected(AgenticCustomSceneQualityJudge.JudgeWireResponse wire) {
        var runner = mock(PracticeAiOperationRunner.class);
        var caller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        var auditPort = mock(JudgeResultAuditPort.class);
        var provider = new ResolvedProvider("primary", "openai-compatible", "gpt-test", mock(ChatClient.class));
        when(registry.currentGenerationProfile()).thenReturn(profile());
        when(registry.qualityRubric()).thenReturn(rubric());
        when(registry.promptText(VersionedResourceRegistry.PromptKind.JUDGE)).thenReturn("JUDGE SYSTEM PROMPT");
        when(caller.call(eq(provider), eq("JUDGE SYSTEM PROMPT"), any(String.class),
                eq(AgenticCustomSceneQualityJudge.JudgeWireResponse.class))).thenReturn(wire);
        when(runner.execute(any())).thenAnswer(invocation -> {
            var operation = (OperationRequest) invocation.getArgument(0);
            return operation.invocation().invoke(provider);
        });
        var judge = new AgenticCustomSceneQualityJudge(
                runner, caller, registry, new JudgeVerdictCalculator(), auditPort);

        assertThatThrownBy(() -> judge.judge(request()))
                .isInstanceOf(PracticeAiStructuredOutputCaller.StructuredOutputInvalidException.class)
                .hasMessage("structured_output_invalid");
        verify(caller, times(1)).call(
                eq(provider), eq("JUDGE SYSTEM PROMPT"), any(String.class),
                eq(AgenticCustomSceneQualityJudge.JudgeWireResponse.class));
        verifyNoInteractions(auditPort);
    }

    private JudgeRequest request() {
        return new JudgeRequest(
                "pgc_judge_test",
                2,
                EVIDENCE_BUNDLE_ID,
                "给宝宝穿鞋",
                "m7_11",
                "calmer_care",
                new GeneratedPracticeContentCandidate(
                        "日常照护", "穿鞋出门", "Shoes on", "拿起鞋子。", "慢慢说。",
                        "Shoes on.", "穿鞋出门。", "shoes on", "starter", "agentic_search"),
                List.of("family-english-strategy-v1"),
                List.of("joint_attention"),
                List.of("m7_11_short_phrase"),
                List.of("low_pressure"),
                List.of("先轻声说。", "再停下来观察。"),
                "rubric-v1",
                "9".repeat(64));
    }

    private AgenticCustomSceneQualityJudge.JudgeWireResponse passWire() {
        return new AgenticCustomSceneQualityJudge.JudgeWireResponse(
                JudgeVerdict.PASS, allPass(), List.of(), List.of(), List.of(), 0.91d);
    }

    private EnumMap<JudgeDimension, DimensionResult> allPass() {
        var dimensions = new EnumMap<JudgeDimension, DimensionResult>(JudgeDimension.class);
        for (var dimension : JudgeDimension.values()) {
            dimensions.put(dimension, DimensionResult.PASS);
        }
        return dimensions;
    }

    private QualityRubric rubric() {
        return new QualityRubric(
                "rubric-v1",
                "9".repeat(64),
                Arrays.stream(JudgeDimension.values()).map(JudgeDimension::rubricKey).toList(),
                Set.of("age_suitability"),
                Set.of(
                        "scene_alignment",
                        "parent_speakability",
                        "non_course_framing",
                        "tpr_quality",
                        "delivery_guidance_quality",
                        "bilingual_consistency",
                        "low_pressure_support"),
                true);
    }

    private GenerationProfile profile() {
        return new GenerationProfile(
                "profile-v1",
                "f".repeat(64),
                new VersionedRef("generator-v1", "a".repeat(64), "generator-v1.txt"),
                new VersionedRef("judge-v1", "c".repeat(64), "judge-v1.txt"),
                new VersionedRef("repair-v1", "d".repeat(64), "repair-v1.txt"),
                new VersionedRef("rubric-v1", "9".repeat(64), "rubric-v1.yml"),
                new VersionedRef("evidence-v1", "e".repeat(64), "evidence-v1.yml"),
                new VersionedRef("baseline-v1", "b".repeat(64), "baseline-v1.yml"),
                "strategy-v1",
                "safety-v1",
                "schema-v1");
    }
}
