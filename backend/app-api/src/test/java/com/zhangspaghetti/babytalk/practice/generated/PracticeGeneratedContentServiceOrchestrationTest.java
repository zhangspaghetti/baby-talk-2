package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiProviderManager;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.discovery.PolicyTextMatcher;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryCustomSceneProperties;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyTestFixture;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextCanonicalizer;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextSecurityConfiguration;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextSecurityPolicy;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.core.io.DefaultResourceLoader;

class PracticeGeneratedContentServiceOrchestrationTest {

    @Test
    @SuppressWarnings("unchecked")
    void delegatesNewDraftToBoundedOrchestratorWithoutLegacyDailyStart() {
        var queries = mock(PracticeGeneratedContentQueryMapper.class);
        var commands = mock(PracticeGeneratedContentCommands.class);
        var orchestrator = mock(CustomSceneGenerationOrchestrator.class);
        var registry = new VersionedResourceRegistry(new DefaultResourceLoader());
        var providerManager = mock(ObjectProvider.class);
        when(providerManager.getIfAvailable()).thenReturn(null);
        when(commands.reserveDraft(any(), any())).thenAnswer(invocation ->
                new DraftReservation(invocation.getArgument(0, PracticeGeneratedContentEntity.class), true));
        var active = new PracticeGeneratedContentEntity();
        active.setStatus("active");
        var executionCaptor = ArgumentCaptor.forClass(CustomSceneGenerationOrchestrator.GenerationExecution.class);
        when(orchestrator.execute(executionCaptor.capture())).thenReturn(active);

        var policy = PracticeDiscoveryPolicyTestFixture.properties();
        var canonicalizer = new SceneTextCanonicalizer();
        var service = new PracticeGeneratedContentService(
                queries,
                commands,
                orchestrator,
                registry,
                providerManager,
                new PracticeDiscoveryCustomSceneProperties(
                        true, Duration.ofSeconds(5), "legacy-prompt", "legacy-strategy", "fake",
                        null, null, null, null, null, null, 3),
                policy,
                new PracticeGeneratedContentOwnerProperties("owner-v1", "x".repeat(32)),
                new PracticeGeneratedContentKeyFactory(
                        new PracticeGeneratedContentOwnerProperties("owner-v1", "x".repeat(32))),
                canonicalizer,
                new SceneTextSecurityPolicy(
                        policy,
                        new PolicyTextMatcher(canonicalizer),
                        SceneTextSecurityConfiguration.configuredSpoofChecker()),
                new PolicyTextMatcher(canonicalizer));

        var result = service.generateCustomScene(new PracticeGeneratedContentService.CustomSceneDiscoveryRequest(
                "onboarding", "custom_scene", "install_test", null, null, "m7_11", "calmer_care", "zh-CN", "出门前穿鞋"));

        assertThat(result).isSameAs(active);
        var execution = executionCaptor.getValue();
        assertThat(execution.reservedContent().generationAttemptLimit()).isEqualTo(3);
        assertThat(execution.reservedContent().generationProfileVersion())
                .isEqualTo(registry.currentGenerationProfile().version());
        assertThat(execution.reservedContent().rubricVersion()).isEqualTo(registry.qualityRubric().version());
        assertThat(execution.reservedContent().evidencePolicyVersion())
                .isEqualTo(registry.minimumEvidencePolicy().version());
        verify(commands, never()).startGeneration(any(), any(), anyInt(), any());
    }
}
