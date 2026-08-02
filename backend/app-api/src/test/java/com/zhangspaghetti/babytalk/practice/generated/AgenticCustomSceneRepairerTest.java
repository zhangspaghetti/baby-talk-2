package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
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
import com.zhangspaghetti.babytalk.practice.agentic.config.PracticeAiReasoningEffort;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedRef;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeDimension;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdict;
import com.zhangspaghetti.babytalk.practice.generated.quality.RepairDirective;
import com.zhangspaghetti.babytalk.practice.generated.quality.TypedRepairPackage;
import com.zhangspaghetti.babytalk.practice.generated.quality.TypedRepairPackage.Branch;
import com.zhangspaghetti.babytalk.practice.generated.quality.TypedRepairPackage.BranchRequirement;
import com.zhangspaghetti.babytalk.practice.generated.quality.GeneratedOutputViolationCode;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceSummary;
import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.mockito.ArgumentCaptor;
import org.springframework.ai.chat.client.ChatClient;
import tools.jackson.databind.json.JsonMapper;

class AgenticCustomSceneRepairerTest {

    private static final UUID EVIDENCE_BUNDLE_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private static final JsonMapper JSON_MAPPER = new JsonMapper();

    @Test
    void typedRepairPackageExcludesRawPrivateAndProviderFields() {
        assertThat(Arrays.stream(TypedRepairPackage.class.getRecordComponents())
                .map(component -> component.getName())
                .toList())
                .containsExactly(
                        "displayText",
                        "ageRange",
                        "parentGoal",
                        "previousBundle",
                        "effectiveVerdict",
                        "failedDimensions",
                        "violationCodes",
                        "branchRequirements",
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
    void typedBranchRequirementsAreCanonicalBoundedAndRepairable() {
        var starter = requirement(
                Branch.STARTER,
                GeneratedOutputViolationCode.MISSING_DELIVERY_GUIDANCE,
                GeneratedOutputViolationCode.MISSING_TPR_ACTION,
                GeneratedOutputViolationCode.MISSING_TPR_ACTION);
        assertThat(starter.violationCodes()).containsExactly(
                GeneratedOutputViolationCode.MISSING_TPR_ACTION,
                GeneratedOutputViolationCode.MISSING_DELIVERY_GUIDANCE);

        var repairPackage = repairPackage(List.of(
                requirement(Branch.OTHER, GeneratedOutputViolationCode.MISSING_TPR_ACTION),
                starter));
        assertThat(repairPackage.branchRequirements())
                .extracting(BranchRequirement::branch)
                .containsExactly(Branch.STARTER, Branch.OTHER);

        assertThatThrownBy(() -> new BranchRequirement(
                Branch.STARTER, List.of(GeneratedOutputViolationCode.OUTPUT_PII)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("branch requirements must contain bounded repairable violations");
        assertThatThrownBy(() -> repairPackage(List.of(starter, starter)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("repair branch requirements must be unique and bounded");
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

        var candidate = repairer.repairCareMoment(request()).starter();

        assertThat(candidate).isEqualTo(new CustomSceneGenerator.GeneratedPracticeContentCandidate(
                "日常照护", "穿鞋出门", "Shoes on", "拿起鞋子。", "慢慢说。", "Shoes on.", "穿鞋出门。",
                "shoes on", "starter", "agentic_search"));
        var operation = (OperationRequest<CompleteGeneratedBundle.ProviderResponse>) operationCaptor.getValue();
        assertThat(operation.capability()).isEqualTo(PracticeAiCapability.CUSTOM_SCENE_REPAIR);
        assertThat(operation.subjectType()).isEqualTo("generated_content");
        assertThat(operation.generatedContentId()).isEqualTo("pgc_repair_test");
        assertThat(operation.attemptNumber()).isEqualTo(2);
        assertThat(operation.evidenceBundleId()).isEqualTo(EVIDENCE_BUNDLE_ID);
        assertThat(operation.promptVersion()).isEqualTo("repair-v1");
        assertThat(operation.promptHash()).isEqualTo("d".repeat(64));
        assertThat(operation.policyVersion()).isEqualTo("evidence-v1");
        assertThat(operation.policyHash()).isEqualTo("e".repeat(64));

        var provider = new ResolvedProvider("primary", "openai-compatible", "glm-5.2", mock(ChatClient.class));
        when(caller.callRaw(eq(provider), eq("REPAIR SYSTEM PROMPT"), any(String.class),
                eq(CompleteGeneratedBundle.ProviderResponse.class), eq(8192),
                eq(PracticeAiReasoningEffort.NONE))).thenReturn(wireJson());
        var callbackResult = operation.invocation().invoke(provider);

        assertThat(callbackResult.value()).isEqualTo(wire);
        var promptCaptor = ArgumentCaptor.forClass(String.class);
        verify(caller).callRaw(eq(provider), eq("REPAIR SYSTEM PROMPT"), promptCaptor.capture(),
                eq(CompleteGeneratedBundle.ProviderResponse.class), eq(8192),
                eq(PracticeAiReasoningEffort.NONE));
        assertThat(promptCaptor.getValue())
                .contains(
                        "给宝宝穿鞋",
                        "m7_11",
                        "calmer_care",
                        "Shoes on.",
                        "MISSING_TPR_ACTION",
                        "先轻声说。",
                        "\"branchRequirements\":[",
                        "\"branch\":\"starter\"",
                        "\"violationCodes\":[\"MISSING_TPR_ACTION\",\"MISSING_DELIVERY_GUIDANCE\"]",
                        "\"branch\":\"no_response\"",
                        "\"branch\":\"other\"",
                        "\"contentConstraints\":{",
                        "\"maxEnglishWords\":6",
                        "\"maxEnglishChars\":40",
                        "\"persistenceCodePointLimits\":{",
                        "\"spaceTitleZh\":120",
                        "\"activityTitleZh\":120",
                        "\"sceneTagEn\":120",
                        "\"englishText\":120",
                        "\"chineseText\":120",
                        "\"pronunciationHint\":120",
                        "\"tprActionZh\":240",
                        "\"deliveryGuidanceZh\":240",
                        "\"difficulty\":16",
                        "\"evidenceActionConsistencyPolicy\":{",
                        "\"groundingSources\":[\"displayText\",\"parentGoal\",\"utteranceEnglishText\",\"utteranceChineseText\",\"orderedSanitizedEvidenceSummaries\"]",
                        "\"requireEachTprActionSupportedByGrounding\":true",
                        "\"forbidUnmentionedObjectsOrBodyActions\":true",
                        "\"repairAllTprBranchesWhenJudgeReportsInconsistency\":true")
                .doesNotContain(
                        "pgc_repair_test",
                        "securityText",
                        "rawEvidenceChunks",
                        "ownerKey",
                        "accountId",
                        "profileId",
                        "providerTraceId",
                        "reasoning");
    }

    @ParameterizedTest
    @CsvSource({
            "openai-compatible, other-model",
            "other-compatible, glm-5.2"
    })
    @SuppressWarnings({"unchecked", "rawtypes"})
    void nonAllowlistedRepairProviderKeepsDefaultInferenceOptions(
            String providerType,
            String modelName
    ) {
        var runner = mock(PracticeAiOperationRunner.class);
        var caller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        when(registry.currentGenerationProfile()).thenReturn(profile());
        when(registry.promptText(VersionedResourceRegistry.PromptKind.REPAIR))
                .thenReturn("REPAIR SYSTEM PROMPT");
        var operationCaptor = ArgumentCaptor.forClass(OperationRequest.class);
        when(runner.execute(operationCaptor.capture())).thenReturn(new OperationResult<>(
                wire(), UUID.randomUUID(), UUID.randomUUID(), "secondary", modelName, null));
        var repairer = new AgenticCustomSceneRepairer(runner, caller, registry);
        repairer.repairCareMoment(request());
        var operation = (OperationRequest<CompleteGeneratedBundle.ProviderResponse>) operationCaptor.getValue();
        var provider = new ResolvedProvider(
                "secondary", providerType, modelName, mock(ChatClient.class));
        when(caller.callRaw(eq(provider), eq("REPAIR SYSTEM PROMPT"), any(String.class),
                eq(CompleteGeneratedBundle.ProviderResponse.class), eq(8192))).thenReturn(wireJson());

        assertThat(operation.invocation().invoke(provider).value()).isEqualTo(wire());

        verify(caller).callRaw(eq(provider), eq("REPAIR SYSTEM PROMPT"), any(String.class),
                eq(CompleteGeneratedBundle.ProviderResponse.class), eq(8192));
        verify(caller, never()).callRaw(eq(provider), eq("REPAIR SYSTEM PROMPT"), any(String.class),
                eq(CompleteGeneratedBundle.ProviderResponse.class), eq(8192),
                any(PracticeAiReasoningEffort.class));
    }

    @Test
    void overlongTrustedProvenanceLeavesRepairerForDeterministicGate() {
        var runner = mock(PracticeAiOperationRunner.class);
        var caller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        when(registry.currentGenerationProfile()).thenReturn(profile());
        when(registry.promptText(VersionedResourceRegistry.PromptKind.REPAIR))
                .thenReturn("REPAIR SYSTEM PROMPT");
        when(runner.execute(any())).thenReturn(new OperationResult<>(
                wire(),
                UUID.randomUUID(),
                UUID.randomUUID(),
                "p".repeat(CompleteGeneratedBundle.PROVIDER_NAME_MAX_CODE_POINTS + 1),
                "m".repeat(CompleteGeneratedBundle.MODEL_NAME_MAX_CODE_POINTS + 1),
                null));
        var repairer = new AgenticCustomSceneRepairer(runner, caller, registry);

        var provenance = repairer.repairCareMoment(request())
                .completeBundle().utterances().get(0).providerProvenance();

        assertThat(provenance.providerName()).hasSize(65);
        assertThat(provenance.modelName()).hasSize(97);
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
        repairer.repairCareMoment(request());
        var operation = (OperationRequest<CompleteGeneratedBundle.ProviderResponse>) operationCaptor.getValue();
        var provider = new ResolvedProvider("primary", "openai-compatible", "gpt-test", mock(ChatClient.class));
        var failure = new PracticeAiStructuredOutputCaller.StructuredOutputInvalidException();
        when(caller.callRaw(eq(provider), eq("REPAIR SYSTEM PROMPT"), any(String.class),
                eq(CompleteGeneratedBundle.ProviderResponse.class), eq(8192))).thenThrow(failure);

        assertThatThrownBy(() -> operation.invocation().invoke(provider))
                .hasMessage("staged_provider_failure")
                .satisfies(error -> assertThat(error.getCause()).isSameAs(failure));
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

        assertThatThrownBy(() -> repairer.repairCareMoment(request()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("repair request generation profile must match current registry profile");
        verifyNoInteractions(runner, caller);
    }

    private static CustomSceneRepairer.RepairRequest request() {
        return new CustomSceneRepairer.RepairRequest("pgc_repair_test", 2, EVIDENCE_BUNDLE_ID, "zh-CN",
                CustomSceneGenerator.ContentConstraints.defaults(),
                repairPackage(List.of(
                                requirement(
                                        Branch.STARTER,
                                        GeneratedOutputViolationCode.MISSING_TPR_ACTION,
                                        GeneratedOutputViolationCode.MISSING_DELIVERY_GUIDANCE),
                                requirement(Branch.COOPERATING, GeneratedOutputViolationCode.MISSING_TPR_ACTION),
                                requirement(Branch.HESITANT, GeneratedOutputViolationCode.MISSING_TPR_ACTION),
                                requirement(Branch.RESISTING, GeneratedOutputViolationCode.MISSING_TPR_ACTION),
                                requirement(
                                        Branch.NO_RESPONSE,
                                        GeneratedOutputViolationCode.MISSING_TPR_ACTION,
                                        GeneratedOutputViolationCode.MISSING_DELIVERY_GUIDANCE),
                                requirement(
                                        Branch.OTHER,
                                        GeneratedOutputViolationCode.MISSING_TPR_ACTION,
                                        GeneratedOutputViolationCode.MISSING_DELIVERY_GUIDANCE))));
    }

    private static TypedRepairPackage repairPackage(List<BranchRequirement> branchRequirements) {
        return new TypedRepairPackage(
                "给宝宝穿鞋",
                "m7_11",
                "calmer_care",
                previousBundle(),
                JudgeVerdict.REPAIR,
                List.of(JudgeDimension.TPR_QUALITY),
                List.of("MISSING_TPR_ACTION"),
                branchRequirements,
                List.of(RepairDirective.REPAIR_TPR_QUALITY),
                List.of(new EvidenceSummary("先轻声说。", "a".repeat(64))),
                profile());
    }

    private static BranchRequirement requirement(
            Branch branch,
            GeneratedOutputViolationCode... violations
    ) {
        return new BranchRequirement(branch, List.of(violations));
    }

    private static CompleteGeneratedBundle.ProviderResponse wire() {
        return new CompleteGeneratedBundle.ProviderResponse(
                CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION,
                new CompleteGeneratedBundle.SceneMetadata("日常照护", "穿鞋出门", "Shoes on"),
                new CompleteGeneratedBundle.ProviderUtterances(
                        utterance(CompleteGeneratedBundle.UtteranceRole.STARTER, null, 1),
                        utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.COOPERATING, 2),
                        utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.HESITANT, 3),
                        utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.RESISTING, 4),
                        utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.NO_RESPONSE, 5),
                        utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.OTHER, 6)));
    }

    private static String wireJson() {
        return JSON_MAPPER.writeValueAsString(wire());
    }

    private static CompleteGeneratedBundle previousBundle() {
        return GeneratedCareMomentBundle.fakeFixture(new CustomSceneGenerator.GeneratedPracticeContentCandidate(
                "日常照护", "穿鞋出门", "Shoes on", "拿起鞋子。", "慢慢说。", "Shoes on.", "穿鞋出门。",
                "shoes on", "starter", "provider_generated")).completeBundle();
    }

    private static CompleteGeneratedBundle.ProviderUtterance utterance(
            CompleteGeneratedBundle.UtteranceRole role,
            CompleteGeneratedBundle.Reaction reaction,
            int displayOrder
    ) {
        return new CompleteGeneratedBundle.ProviderUtterance(
                role, reaction, "Shoes on.", "穿鞋出门。", "shoes on", "拿起鞋子。", "慢慢说。",
                "starter", displayOrder);
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
                "schema-v1",
                8192,
                0,
                new GenerationProfile.RepairInferencePolicy(
                        "openai-compatible",
                        List.of("glm-5.2"),
                        PracticeAiReasoningEffort.NONE));
    }
}
