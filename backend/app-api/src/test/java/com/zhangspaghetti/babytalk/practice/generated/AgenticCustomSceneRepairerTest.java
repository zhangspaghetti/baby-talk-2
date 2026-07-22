package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
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
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedRef;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeDimension;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdict;
import com.zhangspaghetti.babytalk.practice.generated.quality.RepairDirective;
import com.zhangspaghetti.babytalk.practice.generated.quality.TypedRepairPackage;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceSummary;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.ai.chat.client.ChatClient;

class AgenticCustomSceneRepairerTest {

    private static final UUID EVIDENCE_BUNDLE_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");

    @Test
    void typedRepairPackageExcludesRawPrivateAndProviderFields() {
        assertThat(Arrays.stream(TypedRepairPackage.class.getRecordComponents())
                .map(component -> component.getName())
                .toList())
                .containsExactly(
                        "displayText",
                        "ageRange",
                        "parentGoal",
                        "previousCandidate",
                        "effectiveVerdict",
                        "failedDimensions",
                        "violationCodes",
                        "repairDirectives",
                        "evidenceSummaries",
                        "generationProfile")
                .doesNotContain(
                        "rawEvidenceChunks",
                        "securityText",
                        "ownerKey",
                        "accountId",
                        "profileId",
                        "deviceId",
                        "providerResponse",
                        "providerPrompt",
                        "reasoning");
    }

    @Test
    @SuppressWarnings({"unchecked", "rawtypes"})
    void runsRepairCapabilityWithVersionedPromptAndTrustedOutputMapping() {
        var runner = mock(PracticeAiOperationRunner.class);
        var caller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        when(registry.currentGenerationProfile()).thenReturn(profile());
        when(registry.promptText(VersionedResourceRegistry.PromptKind.REPAIR)).thenReturn("REPAIR SYSTEM PROMPT");
        var operationCaptor = ArgumentCaptor.forClass(OperationRequest.class);
        var wire = wire();
        when(runner.execute(operationCaptor.capture())).thenReturn(new OperationResult<>(
                wire,
                UUID.fromString("20000000-0000-0000-0000-000000000001"),
                UUID.fromString("20000000-0000-0000-0000-000000000002"),
                "primary",
                "gpt-test",
                null));
        var repairer = new AgenticCustomSceneRepairer(runner, caller, registry);

        var candidate = repairer.repair(request());

        assertThat(candidate).isEqualTo(new CustomSceneGenerator.GeneratedPracticeContentCandidate(
                "日常照护", "穿鞋出门", "Shoes on", "拿起鞋子。", "慢慢说。", "Shoes on.", "穿鞋出门。",
                "shoes on", "starter", "agentic_search"));
        var operation = (OperationRequest<AgenticCustomSceneRepairer.RepairWireResponse>) operationCaptor.getValue();
        assertThat(operation.capability()).isEqualTo(PracticeAiCapability.CUSTOM_SCENE_REPAIR);
        assertThat(operation.subjectType()).isEqualTo("generated_content");
        assertThat(operation.generatedContentId()).isEqualTo("pgc_repair_test");
        assertThat(operation.attemptNumber()).isEqualTo(2);
        assertThat(operation.evidenceBundleId()).isEqualTo(EVIDENCE_BUNDLE_ID);
        assertThat(operation.promptVersion()).isEqualTo("repair-v1");
        assertThat(operation.promptHash()).isEqualTo("d".repeat(64));
        assertThat(operation.policyVersion()).isEqualTo("evidence-v1");
        assertThat(operation.policyHash()).isEqualTo("e".repeat(64));

        var provider = new ResolvedProvider("primary", "openai-compatible", "gpt-test", mock(ChatClient.class));
        when(caller.call(eq(provider), eq("REPAIR SYSTEM PROMPT"), any(String.class),
                eq(AgenticCustomSceneRepairer.RepairWireResponse.class))).thenReturn(wire);
        var callbackResult = operation.invocation().invoke(provider);

        assertThat(callbackResult.value()).isEqualTo(wire);
        var promptCaptor = ArgumentCaptor.forClass(String.class);
        verify(caller).call(eq(provider), eq("REPAIR SYSTEM PROMPT"), promptCaptor.capture(),
                eq(AgenticCustomSceneRepairer.RepairWireResponse.class));
        assertThat(promptCaptor.getValue())
                .contains("给宝宝穿鞋", "m7_11", "calmer_care", "Shoes on.", "MISSING_TPR_ACTION", "先轻声说。")
                .doesNotContain(
                        "pgc_repair_test",
                        "securityText",
                        "rawEvidenceChunks",
                        "ownerKey",
                        "accountId",
                        "profileId",
                        "providerTraceId",
                        "modelName",
                        "reasoning");
    }

    @Test
    @SuppressWarnings({"unchecked", "rawtypes"})
    void structuredOutputInvalidEscapesRepairCallbackForOperationFallback() {
        var runner = mock(PracticeAiOperationRunner.class);
        var caller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        when(registry.currentGenerationProfile()).thenReturn(profile());
        when(registry.promptText(VersionedResourceRegistry.PromptKind.REPAIR)).thenReturn("REPAIR SYSTEM PROMPT");
        var operationCaptor = ArgumentCaptor.forClass(OperationRequest.class);
        when(runner.execute(operationCaptor.capture())).thenReturn(new OperationResult<>(
                wire(), UUID.randomUUID(), UUID.randomUUID(), "primary", "gpt-test", null));
        var repairer = new AgenticCustomSceneRepairer(runner, caller, registry);
        repairer.repair(request());
        var operation = (OperationRequest<AgenticCustomSceneRepairer.RepairWireResponse>) operationCaptor.getValue();
        var provider = new ResolvedProvider("primary", "openai-compatible", "gpt-test", mock(ChatClient.class));
        var failure = new PracticeAiStructuredOutputCaller.StructuredOutputInvalidException();
        when(caller.call(eq(provider), eq("REPAIR SYSTEM PROMPT"), any(String.class),
                eq(AgenticCustomSceneRepairer.RepairWireResponse.class))).thenThrow(failure);

        assertThatThrownBy(() -> operation.invocation().invoke(provider))
                .isSameAs(failure)
                .hasMessage("structured_output_invalid");
    }

    @Test
    void profileMismatchFailsBeforeOperationOrProviderCall() {
        var runner = mock(PracticeAiOperationRunner.class);
        var caller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        when(registry.currentGenerationProfile()).thenReturn(new GenerationProfile(
                "profile-v2", "f".repeat(64), profile().generatorPrompt(), profile().judgePrompt(),
                profile().repairPrompt(), profile().rubric(), profile().evidencePolicy(), profile().baselineEvidence(),
                "strategy-v1", "safety-v1", "schema-v1"));
        var repairer = new AgenticCustomSceneRepairer(runner, caller, registry);

        assertThatThrownBy(() -> repairer.repair(request()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("repair request generation profile must match current registry profile");
        verifyNoInteractions(runner, caller);
    }

    private static CustomSceneRepairer.RepairRequest request() {
        return new CustomSceneRepairer.RepairRequest("pgc_repair_test", 2, EVIDENCE_BUNDLE_ID, "zh-CN",
                new TypedRepairPackage(
                        "给宝宝穿鞋",
                        "m7_11",
                        "calmer_care",
                        new CustomSceneGenerator.GeneratedPracticeContentCandidate(
                                "日常照护", "穿鞋出门", "Shoes on", "", "慢慢说。", "Shoes on.", "穿鞋出门。",
                                "shoes on", "starter", "agentic_search"),
                        JudgeVerdict.REPAIR,
                        List.of(JudgeDimension.TPR_QUALITY),
                        List.of("MISSING_TPR_ACTION"),
                        List.of(RepairDirective.REPAIR_TPR_QUALITY),
                        List.of(new EvidenceSummary("先轻声说。", "a".repeat(64))),
                        profile()));
    }

    private static AgenticCustomSceneRepairer.RepairWireResponse wire() {
        return new AgenticCustomSceneRepairer.RepairWireResponse(
                "日常照护", "穿鞋出门", "Shoes on", "拿起鞋子。", "慢慢说。", "Shoes on.", "穿鞋出门。",
                "shoes on", "starter");
    }

    private static GenerationProfile profile() {
        return new GenerationProfile(
                "profile-v1",
                "p".repeat(64),
                new VersionedRef("generator-v1", "a".repeat(64), "generator.txt"),
                new VersionedRef("judge-v1", "c".repeat(64), "judge.txt"),
                new VersionedRef("repair-v1", "d".repeat(64), "repair.txt"),
                new VersionedRef("rubric-v1", "r".repeat(64), "rubric.yml"),
                new VersionedRef("evidence-v1", "e".repeat(64), "evidence.yml"),
                new VersionedRef("baseline-v1", "b".repeat(64), "baseline.yml"),
                "strategy-v1",
                "safety-v1",
                "schema-v1");
    }
}
