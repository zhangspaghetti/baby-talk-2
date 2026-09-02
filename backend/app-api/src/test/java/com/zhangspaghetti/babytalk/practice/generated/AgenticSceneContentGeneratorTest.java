package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.agentic.diagnostics.PracticeAiContractViolation.Category;
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
import com.zhangspaghetti.babytalk.practice.generated.SceneContentGenerator.ContentConstraints;
import com.zhangspaghetti.babytalk.practice.generated.SceneContentGenerator.GeneratorRequest;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceItem;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceSanitizer;
import com.zhangspaghetti.babytalk.practice.generated.evidence.FrozenEvidenceBundle;
import com.zhangspaghetti.babytalk.practice.generated.evidence.ReplayMode;
import com.zhangspaghetti.babytalk.practice.generated.evidence.RetrievalStatus;
import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.mockito.ArgumentCaptor;
import org.springframework.ai.chat.client.ChatClient;
import tools.jackson.databind.json.JsonMapper;

class AgenticSceneContentGeneratorTest {

    private static final JsonMapper JSON_MAPPER = new JsonMapper();

    @Test
    void candidateContainsOnlyTheTenApprovedContentFields() throws Exception {
        var candidateType = Class.forName(
                "com.zhangspaghetti.babytalk.practice.generated.SceneContentGenerator$GeneratedPracticeContentCandidate");

        assertThat(Arrays.stream(candidateType.getRecordComponents())
                .map(component -> component.getName())
                .toList())
                .containsExactly(
                        "spaceTitleZh",
                        "activityTitleZh",
                        "sceneTagEn",
                        "tprActionZh",
                        "deliveryGuidanceZh",
                        "englishText",
                        "chineseText",
                        "pronunciationHint",
                        "difficulty",
                        "generationSource")
                .doesNotContain("coachTipZh", "providerTraceId", "retrievalTraceId", "modelName");
    }

    @Test
    void requestContainsOnlyApprovedTypedFields() throws Exception {
        var requestType = Class.forName(
                "com.zhangspaghetti.babytalk.practice.generated.SceneContentGenerator$GeneratorRequest");

        assertThat(Arrays.stream(requestType.getRecordComponents())
                .map(component -> component.getName())
                .toList())
                .containsExactly(
                        "generatedContentId",
                        "attemptNumber",
                        "displayText",
                        "ageRange",
                        "parentGoal",
                        "locale",
                        "evidenceBundle",
                        "generationProfile",
                        "constraints",
                        "context")
                .doesNotContain(
                        "securityText",
                        "ownerKey",
                        "ownerId",
                        "accountId",
                        "profileId",
                        "rawEvidenceChunks");
    }

    @Test
    void obsoleteDiscoveryGenerationPortIsRemoved() {
        assertThatThrownBy(() -> Class.forName(
                "com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGenerationService"))
                .isInstanceOf(ClassNotFoundException.class);
    }

    @Test
    @SuppressWarnings({"unchecked", "rawtypes"})
    void runsGeneratorCapabilityWithVersionedPromptAndMapsTrustedCandidate() {
        var runner = mock(PracticeAiOperationRunner.class);
        var structuredOutputCaller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        when(registry.currentGenerationProfile()).thenReturn(generationProfile());
        when(registry.promptText(VersionedResourceRegistry.PromptKind.GENERATOR))
                .thenReturn("GENERATOR SYSTEM PROMPT");
        var wire = wireResponse();
        var operationCaptor = ArgumentCaptor.forClass(OperationRequest.class);
        when(runner.execute(operationCaptor.capture())).thenReturn(new OperationResult<>(
                wire,
                UUID.fromString("20000000-0000-0000-0000-000000000001"),
                UUID.fromString("20000000-0000-0000-0000-000000000002"),
                "primary",
                "gpt-test",
                "provider-trace"));
        var generator = new AgenticSceneContentGenerator(runner, structuredOutputCaller, registry);

        var candidate = generator.generateCareMoment(request()).starter();

        assertThat(candidate).isEqualTo(new SceneContentGenerator.GeneratedPracticeContentCandidate(
                "日常照护",
                "穿鞋出门",
                "Shoes on",
                "拿起鞋子。",
                "慢慢说，等宝宝看过来。",
                "Shoes on.",
                "穿鞋出门。",
                "shoes on",
                "starter",
                "agentic_search"));
        var operation = (OperationRequest<CompleteGeneratedBundle.ProviderResponse>) operationCaptor.getValue();
        assertThat(operation.capability()).isEqualTo(PracticeAiCapability.CUSTOM_SCENE_GENERATOR);
        assertThat(operation.subjectType()).isEqualTo("generated_content");
        assertThat(operation.subjectId()).isEqualTo("pgc_generator_test");
        assertThat(operation.generatedContentId()).isEqualTo("pgc_generator_test");
        assertThat(operation.attemptNumber()).isEqualTo(2);
        assertThat(operation.evidenceBundleId())
                .isEqualTo(UUID.fromString("10000000-0000-0000-0000-000000000001"));
        assertThat(operation.promptVersion()).isEqualTo("generator-v1");
        assertThat(operation.promptHash()).isEqualTo("a".repeat(64));
        assertThat(operation.policyVersion()).isEqualTo("evidence-v1");
        assertThat(operation.policyHash()).isEqualTo("e".repeat(64));

        var provider = new ResolvedProvider(
                "primary", "openai-compatible", "gpt-test", mock(ChatClient.class));
        when(structuredOutputCaller.callRaw(
                eq(provider),
                eq("GENERATOR SYSTEM PROMPT"),
                any(String.class),
                eq(CompleteGeneratedBundle.ProviderResponse.class),
                eq(8192)))
                .thenReturn(wireJson());

        var invocationResult = operation.invocation().invoke(provider);

        assertThat(invocationResult.value()).isEqualTo(wire);
        assertThat(invocationResult.providerTraceId()).isNull();
        var userPromptCaptor = ArgumentCaptor.forClass(String.class);
        verify(structuredOutputCaller).callRaw(
                eq(provider),
                eq("GENERATOR SYSTEM PROMPT"),
                userPromptCaptor.capture(),
                eq(CompleteGeneratedBundle.ProviderResponse.class),
                eq(8192));
        var userPrompt = userPromptCaptor.getValue();
        assertThat(userPrompt)
                .contains("pgc_generator_test", "给宝宝穿鞋", "m7_11", "calmer_care", "zh-CN", "小满",
                        "caregiver", "recentPracticeCount", "7", "hesitant", "daily_care/bath_time=7")
                .contains("先轻声说。", "再停下来观察。")
                .contains(
                        "\"persistenceCodePointLimits\":{",
                        "\"spaceTitleZh\":120",
                        "\"activityTitleZh\":120",
                        "\"sceneTagEn\":120",
                        "\"englishText\":120",
                        "\"chineseText\":120",
                        "\"pronunciationHint\":120",
                        "\"tprActionZh\":240",
                        "\"deliveryGuidanceZh\":240",
                        "\"difficulty\":16")
                .doesNotContain(
                        "securityText",
                        "ownerKey",
                        "accountId",
                        "profileId",
                        "rawEvidenceChunks",
                        "retrievalTraceId",
                        "bundleHash",
                        "sanitizedSummaryHash",
                        "providerTraceId",
                        "modelName");
        assertThat(userPrompt.indexOf("先轻声说。"))
                .isLessThan(userPrompt.indexOf("再停下来观察。"));
    }

    @Test
    @SuppressWarnings({"unchecked", "rawtypes"})
    void matchingGeneratorInferencePolicyUsesBoundedReasoningControl() {
        var runner = mock(PracticeAiOperationRunner.class);
        var structuredOutputCaller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        var profile = generationProfileWithGeneratorInferencePolicy();
        when(registry.currentGenerationProfile()).thenReturn(profile);
        when(registry.promptText(VersionedResourceRegistry.PromptKind.GENERATOR))
                .thenReturn("GENERATOR SYSTEM PROMPT");
        var operationCaptor = ArgumentCaptor.forClass(OperationRequest.class);
        when(runner.execute(operationCaptor.capture())).thenReturn(new OperationResult<>(
                wireResponse(),
                UUID.randomUUID(),
                UUID.randomUUID(),
                "primary",
                "glm-5.2",
                null));
        var generator = new AgenticSceneContentGenerator(runner, structuredOutputCaller, registry);

        generator.generateCareMoment(request(profile, evidenceBundle()));
        var operation = (OperationRequest<CompleteGeneratedBundle.ProviderResponse>) operationCaptor.getValue();
        var provider = new ResolvedProvider(
                "primary", "openai-compatible", "glm-5.2", mock(ChatClient.class));
        when(structuredOutputCaller.callRaw(
                eq(provider),
                eq("GENERATOR SYSTEM PROMPT"),
                any(String.class),
                eq(CompleteGeneratedBundle.ProviderResponse.class),
                eq(8192),
                eq(PracticeAiReasoningEffort.NONE)))
                .thenReturn(wireJson());

        assertThat(operation.invocation().invoke(provider).value()).isEqualTo(wireResponse());
        verify(structuredOutputCaller).callRaw(
                eq(provider),
                eq("GENERATOR SYSTEM PROMPT"),
                any(String.class),
                eq(CompleteGeneratedBundle.ProviderResponse.class),
                eq(8192),
                eq(PracticeAiReasoningEffort.NONE));
    }

    @ParameterizedTest
    @CsvSource({
            "native-openai, glm-5.2",
            "openai-compatible, glm-5.2-mini"
    })
    @SuppressWarnings({"unchecked", "rawtypes"})
    void nonMatchingGeneratorInferencePolicyKeepsDefaultProviderRequest(
            String providerType,
            String modelName
    ) {
        var runner = mock(PracticeAiOperationRunner.class);
        var structuredOutputCaller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        var profile = generationProfileWithGeneratorInferencePolicy();
        when(registry.currentGenerationProfile()).thenReturn(profile);
        when(registry.promptText(VersionedResourceRegistry.PromptKind.GENERATOR))
                .thenReturn("GENERATOR SYSTEM PROMPT");
        var operationCaptor = ArgumentCaptor.forClass(OperationRequest.class);
        when(runner.execute(operationCaptor.capture())).thenReturn(new OperationResult<>(
                wireResponse(),
                UUID.randomUUID(),
                UUID.randomUUID(),
                "primary",
                modelName,
                null));
        var generator = new AgenticSceneContentGenerator(runner, structuredOutputCaller, registry);

        generator.generateCareMoment(request(profile, evidenceBundle()));
        var operation = (OperationRequest<CompleteGeneratedBundle.ProviderResponse>) operationCaptor.getValue();
        var provider = new ResolvedProvider("primary", providerType, modelName, mock(ChatClient.class));
        when(structuredOutputCaller.callRaw(
                eq(provider),
                eq("GENERATOR SYSTEM PROMPT"),
                any(String.class),
                eq(CompleteGeneratedBundle.ProviderResponse.class),
                eq(8192)))
                .thenReturn(wireJson());

        assertThat(operation.invocation().invoke(provider).value()).isEqualTo(wireResponse());
        verify(structuredOutputCaller).callRaw(
                eq(provider),
                eq("GENERATOR SYSTEM PROMPT"),
                any(String.class),
                eq(CompleteGeneratedBundle.ProviderResponse.class),
                eq(8192));
    }

    @Test
    void overlongTrustedProvenanceLeavesGeneratorForDeterministicGate() {
        var runner = mock(PracticeAiOperationRunner.class);
        var caller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        when(registry.currentGenerationProfile()).thenReturn(generationProfile());
        when(registry.promptText(VersionedResourceRegistry.PromptKind.GENERATOR))
                .thenReturn("GENERATOR SYSTEM PROMPT");
        when(runner.execute(any())).thenReturn(new OperationResult<>(
                wireResponse(),
                UUID.randomUUID(),
                UUID.randomUUID(),
                "p".repeat(CompleteGeneratedBundle.PROVIDER_NAME_MAX_CODE_POINTS + 1),
                "m".repeat(CompleteGeneratedBundle.MODEL_NAME_MAX_CODE_POINTS + 1),
                null));
        var generator = new AgenticSceneContentGenerator(runner, caller, registry);

        var provenance = generator.generateCareMoment(request())
                .completeBundle().utterances().get(0).providerProvenance();

        assertThat(provenance.providerName()).hasSize(65);
        assertThat(provenance.modelName()).hasSize(97);
    }

    @Test
    @SuppressWarnings({"unchecked", "rawtypes"})
    void structuredOutputInvalidIsNotRecoveredInsideGeneratorCallback() {
        var runner = mock(PracticeAiOperationRunner.class);
        var structuredOutputCaller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        when(registry.currentGenerationProfile()).thenReturn(generationProfile());
        when(registry.promptText(VersionedResourceRegistry.PromptKind.GENERATOR))
                .thenReturn("GENERATOR SYSTEM PROMPT");
        var operationCaptor = ArgumentCaptor.forClass(OperationRequest.class);
        when(runner.execute(operationCaptor.capture())).thenReturn(new OperationResult<>(
                wireResponse(),
                UUID.fromString("20000000-0000-0000-0000-000000000001"),
                UUID.fromString("20000000-0000-0000-0000-000000000002"),
                "primary",
                "gpt-test",
                null));
        var generator = new AgenticSceneContentGenerator(runner, structuredOutputCaller, registry);
        generator.generateCareMoment(request());
        var operation = (OperationRequest<CompleteGeneratedBundle.ProviderResponse>) operationCaptor.getValue();
        var provider = new ResolvedProvider(
                "primary", "openai-compatible", "gpt-test", mock(ChatClient.class));
        var failure = new PracticeAiStructuredOutputCaller.StructuredOutputInvalidException();
        when(structuredOutputCaller.callRaw(
                eq(provider),
                eq("GENERATOR SYSTEM PROMPT"),
                any(String.class),
                eq(CompleteGeneratedBundle.ProviderResponse.class),
                eq(8192)))
                .thenThrow(failure);

        assertThatThrownBy(() -> operation.invocation().invoke(provider))
                .hasMessage("staged_provider_failure")
                .satisfies(error -> assertThat(error.getCause()).isSameAs(failure));
    }

    @Test
    void wireResponseCannotCarryTrustedGenerationSourceOrProviderMetadata() {
        assertThat(Arrays.stream(CompleteGeneratedBundle.ProviderResponse.class.getRecordComponents())
                .map(component -> component.getName())
                .toList())
                .containsExactly(
                        "schemaVersion",
                        "scene",
                        "utterances")
                .doesNotContain(
                        "generationSource",
                        "providerTraceId",
                        "retrievalTraceId",
                        "modelName");
    }

    @Test
    void wireResponseRejectsMissingRequiredBranch() {
        assertThatThrownBy(() -> new CompleteGeneratedBundle.ProviderUtterances(
                wireUtterance(CompleteGeneratedBundle.UtteranceRole.STARTER, null, 1),
                wireUtterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                        CompleteGeneratedBundle.Reaction.COOPERATING, 2),
                wireUtterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                        CompleteGeneratedBundle.Reaction.HESITANT, 3),
                wireUtterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                        CompleteGeneratedBundle.Reaction.RESISTING, 4),
                wireUtterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                        CompleteGeneratedBundle.Reaction.NO_RESPONSE, 5),
                null))
                .isInstanceOf(CompleteGeneratedBundle.ContractViolationException.class)
                .satisfies(failure -> assertThat(
                        ((CompleteGeneratedBundle.ContractViolationException) failure).category())
                        .isEqualTo(Category.BRANCH_COMPLETENESS));
    }

    @Test
    void profileVersionMismatchFailsClosedBeforeOperationOrProviderCall() {
        var runner = mock(PracticeAiOperationRunner.class);
        var structuredOutputCaller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        when(registry.currentGenerationProfile()).thenReturn(generationProfile(
                "profile-v2",
                new VersionedRef("generator-v1", "a".repeat(64), "generator-v1.txt"),
                new VersionedRef("evidence-v1", "e".repeat(64), "evidence-v1.yml")));
        var generator = new AgenticSceneContentGenerator(runner, structuredOutputCaller, registry);

        assertThatThrownBy(() -> generator.generateCareMoment(request()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("generator request generation profile must match current registry profile");
        verifyNoInteractions(runner, structuredOutputCaller);
    }

    @Test
    void generatorPromptHashMismatchFailsClosedBeforeOperationOrProviderCall() {
        var runner = mock(PracticeAiOperationRunner.class);
        var structuredOutputCaller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        when(registry.currentGenerationProfile()).thenReturn(generationProfile(
                "profile-v1",
                new VersionedRef("generator-v1", "9".repeat(64), "generator-v1.txt"),
                new VersionedRef("evidence-v1", "e".repeat(64), "evidence-v1.yml")));
        var generator = new AgenticSceneContentGenerator(runner, structuredOutputCaller, registry);

        assertThatThrownBy(() -> generator.generateCareMoment(request()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("generator request generation profile must match current registry profile");
        verifyNoInteractions(runner, structuredOutputCaller);
    }

    @Test
    void evidencePolicyVersionMismatchFailsClosedBeforeOperationOrProviderCall() {
        assertEvidencePolicyMismatchFailsClosed(evidenceBundle("evidence-v2", "e".repeat(64)));
    }

    @Test
    void evidencePolicyHashMismatchFailsClosedBeforeOperationOrProviderCall() {
        assertEvidencePolicyMismatchFailsClosed(evidenceBundle("evidence-v1", "9".repeat(64)));
    }

    private void assertEvidencePolicyMismatchFailsClosed(FrozenEvidenceBundle evidenceBundle) {
        var runner = mock(PracticeAiOperationRunner.class);
        var structuredOutputCaller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        when(registry.currentGenerationProfile()).thenReturn(generationProfile());
        var generator = new AgenticSceneContentGenerator(runner, structuredOutputCaller, registry);

        assertThatThrownBy(() -> generator.generateCareMoment(request(generationProfile(), evidenceBundle)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("generator evidence policy must match generation profile");
        verifyNoInteractions(runner, structuredOutputCaller);
    }

    private GeneratorRequest request() {
        return request(generationProfile(), evidenceBundle());
    }

    private GeneratorRequest request(GenerationProfile generationProfile, FrozenEvidenceBundle evidenceBundle) {
        return new GeneratorRequest(
                "pgc_generator_test",
                2,
                "给宝宝穿鞋",
                "m7_11",
                "calmer_care",
                "zh-CN",
                evidenceBundle,
                generationProfile,
                ContentConstraints.defaults(),
                new GenerationRequestContext(
                        "小满",
                        "m7_11",
                        "calmer_care",
                        "zh-CN",
                        "caregiver",
                        7,
                        "hesitant",
                        "daily_care/bath_time=7"));
    }

    private FrozenEvidenceBundle evidenceBundle() {
        return evidenceBundle("evidence-v1", "e".repeat(64));
    }

    private FrozenEvidenceBundle evidenceBundle(String policyVersion, String policyHash) {
        var firstSummary = "先轻声说。";
        var secondSummary = "再停下来观察。";
        return new FrozenEvidenceBundle(
                UUID.fromString("10000000-0000-0000-0000-000000000001"),
                "pgc_generator_test",
                2,
                UUID.fromString("10000000-0000-0000-0000-000000000002"),
                RetrievalStatus.REUSED,
                null,
                policyVersion,
                policyHash,
                EvidenceSanitizer.VERSION,
                "b".repeat(64),
                List.of(
                        evidenceItem("evidence-1", "low_pressure_delivery", firstSummary),
                        evidenceItem("evidence-2", "age_guidance", secondSummary)),
                OffsetDateTime.parse("2026-07-18T00:00:00Z"));
    }

    private EvidenceItem evidenceItem(String id, String claimType, String summary) {
        return new EvidenceItem(
                id,
                ReplayMode.SNAPSHOT,
                "baseline",
                "baseline-v1",
                "strategy-v1",
                claimType,
                summary,
                sha256(summary),
                0.9d);
    }

    private GenerationProfile generationProfile() {
        return generationProfile(
                "profile-v1",
                new VersionedRef("generator-v1", "a".repeat(64), "generator-v1.txt"),
                new VersionedRef("evidence-v1", "e".repeat(64), "evidence-v1.yml"));
    }

    private GenerationProfile generationProfile(
            String profileVersion,
            VersionedRef generatorPrompt,
            VersionedRef evidencePolicy
    ) {
        return new GenerationProfile(
                profileVersion,
                "f".repeat(64),
                generatorPrompt,
                new VersionedRef("judge-v1", "c".repeat(64), "judge-v1.txt"),
                new VersionedRef("repair-v1", "d".repeat(64), "repair-v1.txt"),
                new VersionedRef("rubric-v1", "r".repeat(64), "rubric-v1.yml"),
                evidencePolicy,
                new VersionedRef("baseline-v1", "b".repeat(64), "baseline-v1.yml"),
                "strategy-v1",
                "safety-v1",
                "schema-v1");
    }

    private CompleteGeneratedBundle.ProviderResponse wireResponse() {
        return new CompleteGeneratedBundle.ProviderResponse(
                CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION,
                new CompleteGeneratedBundle.SceneMetadata("日常照护", "穿鞋出门", "Shoes on"),
                new CompleteGeneratedBundle.ProviderUtterances(
                        wireUtterance(CompleteGeneratedBundle.UtteranceRole.STARTER, null, 1),
                        wireUtterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.COOPERATING, 2),
                        wireUtterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.HESITANT, 3),
                        wireUtterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.RESISTING, 4),
                        wireUtterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.NO_RESPONSE, 5),
                        wireUtterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.OTHER, 6)));
    }

    private GenerationProfile generationProfileWithGeneratorInferencePolicy() {
        var profile = generationProfile();
        return new GenerationProfile(
                profile.version(),
                profile.contentHash(),
                profile.generatorPrompt(),
                profile.judgePrompt(),
                profile.repairPrompt(),
                profile.rubric(),
                profile.evidencePolicy(),
                profile.baselineEvidence(),
                profile.strategyVersion(),
                profile.contentSafetyPolicyVersion(),
                profile.generatedOutputSchemaVersion(),
                profile.minimumCompleteBundleOutputTokens(),
                profile.minimumQualityJudgeOutputTokens(),
                profile.repairInferencePolicy(),
                new GenerationProfile.InferencePolicy(
                        "openai-compatible",
                        List.of("glm-5.2"),
                        PracticeAiReasoningEffort.NONE));
    }

    private String wireJson() {
        return JSON_MAPPER.writeValueAsString(wireResponse());
    }

    private CompleteGeneratedBundle.ProviderUtterance wireUtterance(
            CompleteGeneratedBundle.UtteranceRole role,
            CompleteGeneratedBundle.Reaction reaction,
            int displayOrder
    ) {
        return new CompleteGeneratedBundle.ProviderUtterance(
                role, reaction, "Shoes on.", "穿鞋出门。", "shoes on", "拿起鞋子。",
                "慢慢说，等宝宝看过来。", "starter", displayOrder);
    }

    private String sha256(String value) {
        try {
            var digest = MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8));
            var hash = new StringBuilder(digest.length * 2);
            for (byte item : digest) {
                hash.append(String.format("%02x", item));
            }
            return hash.toString();
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException(exception);
        }
    }
}
