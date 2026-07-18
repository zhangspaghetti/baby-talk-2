package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
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
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.ContentConstraints;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratorRequest;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceItem;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceSanitizer;
import com.zhangspaghetti.babytalk.practice.generated.evidence.FrozenEvidenceBundle;
import com.zhangspaghetti.babytalk.practice.generated.evidence.ReplayMode;
import com.zhangspaghetti.babytalk.practice.generated.evidence.RetrievalStatus;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.ai.chat.client.ChatClient;

class AgenticCustomSceneGeneratorTest {

    @Test
    void candidateContainsOnlyTheTenApprovedContentFields() throws Exception {
        var candidateType = Class.forName(
                "com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator$GeneratedPracticeContentCandidate");

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
                "com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator$GeneratorRequest");

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
                        "constraints")
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
        var generator = new AgenticCustomSceneGenerator(runner, structuredOutputCaller, registry);

        var candidate = generator.generate(request());

        assertThat(candidate).isEqualTo(new CustomSceneGenerator.GeneratedPracticeContentCandidate(
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
        var operation = (OperationRequest<AgenticCustomSceneGenerator.GeneratorWireResponse>) operationCaptor.getValue();
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
        when(structuredOutputCaller.call(
                eq(provider),
                eq("GENERATOR SYSTEM PROMPT"),
                any(String.class),
                eq(AgenticCustomSceneGenerator.GeneratorWireResponse.class)))
                .thenReturn(wire);

        var invocationResult = operation.invocation().invoke(provider);

        assertThat(invocationResult.value()).isEqualTo(wire);
        assertThat(invocationResult.providerTraceId()).isNull();
        var userPromptCaptor = ArgumentCaptor.forClass(String.class);
        verify(structuredOutputCaller).call(
                eq(provider),
                eq("GENERATOR SYSTEM PROMPT"),
                userPromptCaptor.capture(),
                eq(AgenticCustomSceneGenerator.GeneratorWireResponse.class));
        var userPrompt = userPromptCaptor.getValue();
        assertThat(userPrompt)
                .contains("pgc_generator_test", "给宝宝穿鞋", "m7_11", "calmer_care", "zh-CN")
                .contains("先轻声说。", "再停下来观察。")
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
    void structuredOutputInvalidIsNotRecoveredInsideGeneratorCallback() {
        var runner = mock(PracticeAiOperationRunner.class);
        var structuredOutputCaller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
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
        var generator = new AgenticCustomSceneGenerator(runner, structuredOutputCaller, registry);
        generator.generate(request());
        var operation = (OperationRequest<AgenticCustomSceneGenerator.GeneratorWireResponse>) operationCaptor.getValue();
        var provider = new ResolvedProvider(
                "primary", "openai-compatible", "gpt-test", mock(ChatClient.class));
        var failure = new PracticeAiStructuredOutputCaller.StructuredOutputInvalidException();
        when(structuredOutputCaller.call(
                eq(provider),
                eq("GENERATOR SYSTEM PROMPT"),
                any(String.class),
                eq(AgenticCustomSceneGenerator.GeneratorWireResponse.class)))
                .thenThrow(failure);

        assertThatThrownBy(() -> operation.invocation().invoke(provider))
                .isSameAs(failure)
                .hasMessage("structured_output_invalid");
    }

    @Test
    void wireResponseCannotCarryTrustedGenerationSourceOrProviderMetadata() {
        assertThat(Arrays.stream(AgenticCustomSceneGenerator.GeneratorWireResponse.class.getRecordComponents())
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
                        "difficulty")
                .doesNotContain(
                        "generationSource",
                        "providerTraceId",
                        "retrievalTraceId",
                        "modelName");
    }

    @Test
    void wireResponseRejectsMissingRequiredSchemaField() {
        assertThatThrownBy(() -> new AgenticCustomSceneGenerator.GeneratorWireResponse(
                "日常照护",
                "穿鞋出门",
                "Shoes on",
                "拿起鞋子。",
                null,
                "Shoes on.",
                "穿鞋出门。",
                null,
                "starter"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("deliveryGuidanceZh must be non-blank");
    }

    private GeneratorRequest request() {
        return new GeneratorRequest(
                "pgc_generator_test",
                2,
                "给宝宝穿鞋",
                "m7_11",
                "calmer_care",
                "zh-CN",
                evidenceBundle(),
                generationProfile(),
                ContentConstraints.defaults());
    }

    private FrozenEvidenceBundle evidenceBundle() {
        var firstSummary = "先轻声说。";
        var secondSummary = "再停下来观察。";
        return new FrozenEvidenceBundle(
                UUID.fromString("10000000-0000-0000-0000-000000000001"),
                "pgc_generator_test",
                2,
                UUID.fromString("10000000-0000-0000-0000-000000000002"),
                RetrievalStatus.REUSED,
                null,
                "evidence-v1",
                "e".repeat(64),
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
        return new GenerationProfile(
                "profile-v1",
                "f".repeat(64),
                new VersionedRef("generator-v1", "a".repeat(64), "generator-v1.txt"),
                new VersionedRef("judge-v1", "c".repeat(64), "judge-v1.txt"),
                new VersionedRef("repair-v1", "d".repeat(64), "repair-v1.txt"),
                new VersionedRef("rubric-v1", "r".repeat(64), "rubric-v1.yml"),
                new VersionedRef("evidence-v1", "e".repeat(64), "evidence-v1.yml"),
                new VersionedRef("baseline-v1", "b".repeat(64), "baseline-v1.yml"),
                "strategy-v1",
                "safety-v1",
                "schema-v1");
    }

    private AgenticCustomSceneGenerator.GeneratorWireResponse wireResponse() {
        return new AgenticCustomSceneGenerator.GeneratorWireResponse(
                "日常照护",
                "穿鞋出门",
                "Shoes on",
                "拿起鞋子。",
                "慢慢说，等宝宝看过来。",
                "Shoes on.",
                "穿鞋出门。",
                "shoes on",
                "starter");
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
