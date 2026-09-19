package com.zhangspaghetti.babytalk.practice.discovery.safety;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiCapability;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiOperationRunner;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiProviderManager;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller;
import com.zhangspaghetti.babytalk.practice.agentic.ResolvedProvider;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedRef;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import java.lang.reflect.Field;
import java.time.Duration;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.springframework.ai.chat.client.ChatClient;
import tools.jackson.databind.json.JsonMapper;

class AgenticCustomSceneSafetyClassifierTest {

    private static final String PROMPT_VERSION = "custom-scene-safety-classifier-v1";
    private static final String PROMPT_PATH = "config/practice-ai/prompts/custom-scene-safety-classifier-v1.txt";
    private static final String POLICY_VERSION = "health-safety-v1";
    private static final String SYSTEM_PROMPT = "SAFETY CLASSIFIER SYSTEM PROMPT";
    private static final JsonMapper JSON_MAPPER = new JsonMapper();

    @Test
    void usesDirectProviderRouteWithoutRunnerAuditOrGeneratedContentIdentity() throws Exception {
        var provider = provider("primary");
        var fixture = fixture(List.of(provider));
        when(fixture.caller().callRaw(
                eq(provider), eq(SYSTEM_PROMPT), any(String.class),
                eq(AgenticCustomSceneSafetyClassifier.ProviderResponse.class),
                eq(Duration.ofSeconds(3))))
                .thenReturn(validJson("real_health_concern", "health_concern"));

        var result = fixture.classifier().classify(request("宝宝拉肚子"));

        assertThat(result.intent()).isEqualTo(CustomSceneSafetyAssessment.Intent.REAL_HEALTH_CONCERN);
        assertThat(result.signals()).containsExactly(CustomSceneSafetyClassifier.Signal.HEALTH_CONCERN);
        assertThat(Arrays.stream(AgenticCustomSceneSafetyClassifier.class.getDeclaredFields())
                .map(Field::getType))
                .doesNotContain(PracticeAiOperationRunner.class);
        verify(fixture.manager()).route(PracticeAiCapability.CUSTOM_SCENE_SAFETY_CLASSIFIER);
        verify(fixture.registry()).promptRef(VersionedResourceRegistry.PromptKind.SAFETY_CLASSIFIER);
        verify(fixture.registry()).healthSafetyPolicyHash();

        var userPrompt = ArgumentCaptor.forClass(String.class);
        verify(fixture.caller()).callRaw(
                eq(provider), eq(SYSTEM_PROMPT), userPrompt.capture(),
                eq(AgenticCustomSceneSafetyClassifier.ProviderResponse.class),
                eq(Duration.ofSeconds(3)));
        assertThat(userPrompt.getValue()).doesNotContain("generatedContentId", "accountId", "traceId");
        assertThat(JSON_MAPPER.readTree(userPrompt.getValue()).properties()
                .stream().map(java.util.Map.Entry::getKey).toList())
                .containsExactly("displayText", "ageRange", "locale", "policyVersion");
    }

    @Test
    void firstProviderFailureStopsRouteAndNeverCallsSecondProvider() {
        var primary = provider("primary");
        var secondary = provider("secondary");
        var fixture = fixture(List.of(primary, secondary));
        when(fixture.caller().callRaw(
                eq(primary), eq(SYSTEM_PROMPT), any(String.class),
                eq(AgenticCustomSceneSafetyClassifier.ProviderResponse.class),
                eq(Duration.ofSeconds(3))))
                .thenThrow(new IllegalStateException("provider-secret-sentinel"));

        assertThatThrownBy(() -> fixture.classifier().classify(request("医生游戏")))
                .isInstanceOf(CustomSceneSafetyClassifier.UnavailableException.class)
                .hasMessage("custom scene safety classifier unavailable");

        verify(fixture.caller(), never()).callRaw(
                eq(secondary), eq(SYSTEM_PROMPT), any(String.class),
                eq(AgenticCustomSceneSafetyClassifier.ProviderResponse.class),
                eq(Duration.ofSeconds(3)));
    }

    @Test
    void allProviderFailuresBecomeCauseFreeSanitizedUnavailableException() {
        var provider = provider("primary");
        var fixture = fixture(List.of(provider));
        when(fixture.caller().callRaw(
                eq(provider), eq(SYSTEM_PROMPT), any(String.class),
                eq(AgenticCustomSceneSafetyClassifier.ProviderResponse.class),
                eq(Duration.ofSeconds(3))))
                .thenThrow(new IllegalArgumentException("provider-secret-sentinel user-secret-sentinel"));

        assertThatThrownBy(() -> fixture.classifier().classify(request("user-secret-sentinel")))
                .isInstanceOf(CustomSceneSafetyClassifier.UnavailableException.class)
                .hasMessage("custom scene safety classifier unavailable")
                .satisfies(error -> {
                    assertThat(error.getCause()).isNull();
                    assertThat(error.toString()).doesNotContain("provider-secret-sentinel", "user-secret-sentinel");
                });
    }

    @Test
    void refusesUnverifiedPromptMetadataWithoutFallbackOrProviderCall() {
        var provider = provider("primary");
        var fixture = fixture(List.of(provider));
        when(fixture.registry().promptRef(VersionedResourceRegistry.PromptKind.SAFETY_CLASSIFIER))
                .thenReturn(null);

        assertThatThrownBy(() -> fixture.classifier().classify(request("普通场景")))
                .isInstanceOf(CustomSceneSafetyClassifier.UnavailableException.class)
                .hasMessage("custom scene safety classifier unavailable");
        verify(fixture.manager(), never()).route(PracticeAiCapability.CUSTOM_SCENE_SAFETY_CLASSIFIER);
        verifyNoInteractions(fixture.caller());
    }

    @Test
    void refusesUnverifiedPolicyHashWithoutHashFallback() {
        var provider = provider("primary");
        var fixture = fixture(List.of(provider));
        when(fixture.registry().healthSafetyPolicyHash()).thenReturn(null);

        assertThatThrownBy(() -> fixture.classifier().classify(request("普通场景")))
                .isInstanceOf(CustomSceneSafetyClassifier.UnavailableException.class)
                .hasMessage("custom scene safety classifier unavailable");
        verify(fixture.manager(), never()).route(PracticeAiCapability.CUSTOM_SCENE_SAFETY_CLASSIFIER);
        verifyNoInteractions(fixture.caller());
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "{\"intent\":\"ordinary_scene\",\"signals\":[\"fictional\"]}",
            "{\"intent\":\"ordinary_scene\",\"signals\":[\"recovered\"]}",
            "{\"intent\":\"real_health_concern\",\"signals\":[\"health_concern\",\"prompt_assessment\"]}",
            "{\"intent\":\"uncertain\",\"signals\":[\"ambiguous_concern\"]}"
    })
    void acceptsOnlyContractualIntentSignalCombinations(String raw) {
        var provider = provider("primary");
        var fixture = fixture(List.of(provider));
        when(fixture.caller().callRaw(
                eq(provider), eq(SYSTEM_PROMPT), any(String.class),
                eq(AgenticCustomSceneSafetyClassifier.ProviderResponse.class),
                eq(Duration.ofSeconds(3))))
                .thenReturn(raw);

        assertThat(fixture.classifier().classify(request("scene"))).isNotNull();
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
            "{\"intent\":\"ordinary_scene\",\"signals\":[]}{\"intent\":\"ordinary_scene\",\"signals\":[]}",
            "{\"intent\":\"ordinary_scene\",\"signals\":[\"fictional\"],\"intent\":\"ordinary_scene\"}"
    })
    void malformedOrContradictoryProviderOutputFailsClosed(String raw) {
        var provider = provider("primary");
        var fixture = fixture(List.of(provider));
        when(fixture.caller().callRaw(
                eq(provider), eq(SYSTEM_PROMPT), any(String.class),
                eq(AgenticCustomSceneSafetyClassifier.ProviderResponse.class),
                eq(Duration.ofSeconds(3))))
                .thenReturn(raw);

        assertThatThrownBy(() -> fixture.classifier().classify(request("秘密用户原文")))
                .isInstanceOf(CustomSceneSafetyClassifier.UnavailableException.class)
                .satisfies(error -> assertThat(error.toString()).doesNotContain("秘密用户原文", raw));
    }

    private ConfiguredFixture fixture(List<ResolvedProvider> providers) {
        var manager = mock(PracticeAiProviderManager.class);
        when(manager.route(PracticeAiCapability.CUSTOM_SCENE_SAFETY_CLASSIFIER)).thenReturn(providers);
        var caller = mock(PracticeAiStructuredOutputCaller.class);
        var registry = mock(VersionedResourceRegistry.class);
        when(registry.promptText(VersionedResourceRegistry.PromptKind.SAFETY_CLASSIFIER))
                .thenReturn(SYSTEM_PROMPT);
        when(registry.promptRef(VersionedResourceRegistry.PromptKind.SAFETY_CLASSIFIER))
                .thenReturn(new VersionedRef(PROMPT_VERSION, "a".repeat(64), PROMPT_PATH));
        when(registry.healthSafetyPolicyHash()).thenReturn("b".repeat(64));
        return new ConfiguredFixture(
                new AgenticCustomSceneSafetyClassifier(manager, caller, registry), manager, caller, registry);
    }

    private ResolvedProvider provider(String name) {
        return new ResolvedProvider(name, "openai-compatible", name + "-model", mock(ChatClient.class));
    }

    private CustomSceneSafetyClassifier.ClassifierRequest request(String displayText) {
        return new CustomSceneSafetyClassifier.ClassifierRequest(
                displayText, "m7_11", "zh-CN", POLICY_VERSION);
    }

    private String validJson(String intent, String... signals) {
        return "{\"intent\":\"" + intent + "\",\"signals\":[\""
                + String.join("\",\"", signals) + "\"]}";
    }

    private record ConfiguredFixture(
            AgenticCustomSceneSafetyClassifier classifier,
            PracticeAiProviderManager manager,
            PracticeAiStructuredOutputCaller caller,
            VersionedResourceRegistry registry
    ) {
    }
}
