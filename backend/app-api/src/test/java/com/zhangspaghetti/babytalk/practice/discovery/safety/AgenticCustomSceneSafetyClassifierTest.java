package com.zhangspaghetti.babytalk.practice.discovery.safety;

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
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.springframework.ai.chat.client.ChatClient;
import tools.jackson.databind.json.JsonMapper;

class AgenticCustomSceneSafetyClassifierTest {

    private static final JsonMapper JSON_MAPPER = new JsonMapper();

    @Test
    @SuppressWarnings({"unchecked", "rawtypes"})
    void runsSafetyClassifierWithLockedPromptAndOnlyApprovedUserFields() {
        var runner = mock(PracticeAiOperationRunner.class);
        var caller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        when(registry.promptText(VersionedResourceRegistry.PromptKind.SAFETY_CLASSIFIER))
                .thenReturn("SAFETY CLASSIFIER SYSTEM PROMPT");
        var provider = new ResolvedProvider("primary", "openai-compatible", "gpt-test", mock(ChatClient.class));
        when(caller.callRaw(
                eq(provider),
                eq("SAFETY CLASSIFIER SYSTEM PROMPT"),
                any(String.class),
                any(Class.class)))
                .thenReturn("{\"intent\":\"real_health_concern\",\"signals\":[\"health_concern\"]}");
        var operationCaptor = ArgumentCaptor.forClass(OperationRequest.class);
        when(runner.execute(operationCaptor.capture())).thenAnswer(invocation -> {
            var operation = (OperationRequest) invocation.getArgument(0);
            var providerResult = operation.invocation().invoke(provider);
            return new OperationResult<>(
                    providerResult.value(),
                    UUID.fromString("20000000-0000-0000-0000-000000000001"),
                    UUID.fromString("20000000-0000-0000-0000-000000000002"),
                    "primary",
                    "gpt-test",
                    providerResult.providerTraceId());
        });

        var classifier = new AgenticCustomSceneSafetyClassifier(runner, caller, registry);
        var result = classifier.classify(new CustomSceneSafetyClassifier.ClassifierRequest(
                "宝宝拉肚子哭闹怎么办", "m7_11", "zh-CN", "health-safety-v1"));

        assertThat(result.intent()).isEqualTo(CustomSceneSafetyAssessment.Intent.REAL_HEALTH_CONCERN);
        assertThat(result.signals()).containsExactly(CustomSceneSafetyClassifier.Signal.HEALTH_CONCERN);
        var operation = (OperationRequest<CustomSceneSafetyClassifier.SemanticResult>) operationCaptor.getValue();
        assertThat(operation.capability()).isEqualTo(PracticeAiCapability.CUSTOM_SCENE_SAFETY_CLASSIFIER);
        assertThat(operation.subjectType()).isEqualTo("generated_content");
        assertThat(operation.subjectId()).matches(
                "[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}");
        assertThat(operation.subjectId()).isEqualTo(operation.generatedContentId());
        assertThat(operation.subjectId()).doesNotContain("拉肚子", "怎么办");
        assertThat(operation.promptVersion()).isEqualTo("custom-scene-safety-classifier-v1");
        assertThat(operation.promptHash()).matches("[0-9a-f]{64}");
        assertThat(operation.policyVersion()).isEqualTo("health-safety-v1");
        assertThat(operation.policyHash()).matches("[0-9a-f]{64}");

        var userPromptCaptor = ArgumentCaptor.forClass(String.class);
        verify(caller).callRaw(
                eq(provider),
                eq("SAFETY CLASSIFIER SYSTEM PROMPT"),
                userPromptCaptor.capture(),
                eq(AgenticCustomSceneSafetyClassifier.ProviderResponse.class));
        var userPayload = JSON_MAPPER.readTree(userPromptCaptor.getValue());
        assertThat(userPayload.properties().stream().map(java.util.Map.Entry::getKey).toList())
                .containsExactly("displayText", "ageRange", "locale", "policyVersion");
        assertThat(userPayload.toString()).doesNotContain(
                "account", "installation", "token", "name", "trace", "profile");
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "{}",
            "{\"intent\":null,\"signals\":[]}",
            "{\"intent\":\"other\",\"signals\":[]}",
            "{\"intent\":\"ordinary_scene\",\"signals\":[\"other\"]}",
            "{\"intent\":\"ordinary_scene\",\"signals\":[\"fictional\"],\"extra\":true}",
            "{\"intent\":\"ordinary_scene\",\"signals\":[\"fictional\",\"fictional\"]}",
            "{\"intent\":\"ordinary_scene\",\"signals\":[\"health_concern\"]}",
            "{\"intent\":\"real_health_concern\",\"signals\":[]}",
            "{\"intent\":\"uncertain\",\"signals\":[]}",
            "{\"intent\":\"real_health_concern\",\"signals\":[\"health_concern\",\"recovered\"]}",
            "{\"intent\":\"uncertain\",\"signals\":[\"ambiguous_concern\",\"fictional\"]}",
            "{\"intent\":\"ordinary_scene\",\"signals\":[]}{\"intent\":\"ordinary_scene\",\"signals\":[]}",
            "{\"intent\":\"ordinary_scene\",\"signals\":[\"fictional\"],\"intent\":\"ordinary_scene\"}"
    })
    void rejectsMalformedUnknownDuplicateAndContradictoryProviderOutput(String raw) {
        var fixture = fixture(raw);

        assertThatThrownBy(() -> fixture.classifier().classify(new CustomSceneSafetyClassifier.ClassifierRequest(
                "秘密用户原文", "m7_11", "zh-CN", "health-safety-v1")))
                .hasMessage("staged_provider_failure")
                .satisfies(error -> assertThat(error.toString()).doesNotContain("秘密用户原文", raw));
    }

    private Fixture fixture(String raw) {
        var runner = mock(PracticeAiOperationRunner.class);
        var caller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        when(registry.promptText(VersionedResourceRegistry.PromptKind.SAFETY_CLASSIFIER))
                .thenReturn("SAFETY CLASSIFIER SYSTEM PROMPT");
        var provider = new ResolvedProvider("primary", "openai-compatible", "gpt-test", mock(ChatClient.class));
        when(caller.callRaw(
                eq(provider),
                eq("SAFETY CLASSIFIER SYSTEM PROMPT"),
                any(String.class),
                any(Class.class)))
                .thenReturn(raw);
        when(runner.execute(any())).thenAnswer(invocation -> {
            var operation = (OperationRequest) invocation.getArgument(0);
            var providerResult = operation.invocation().invoke(provider);
            return new OperationResult<>(
                    providerResult.value(),
                    UUID.randomUUID(),
                    UUID.randomUUID(),
                    "primary",
                    "gpt-test",
                    providerResult.providerTraceId());
        });
        return new Fixture(new AgenticCustomSceneSafetyClassifier(runner, caller, registry));
    }

    private record Fixture(AgenticCustomSceneSafetyClassifier classifier) {
    }
}
