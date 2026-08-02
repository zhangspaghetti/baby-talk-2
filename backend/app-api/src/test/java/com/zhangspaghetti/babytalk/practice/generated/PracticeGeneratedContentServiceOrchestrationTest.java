package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiProviderManager;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.discovery.PolicyTextMatcher;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGeneratedContentValidator;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryCustomSceneProperties;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyTestFixture;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextCanonicalizer;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextSecurityConfiguration;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextSecurityPolicy;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
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
                mock(CustomSceneGenerator.class),
                mock(CustomSceneGeneratedContentValidator.class),
                orchestrator,
                registry,
                providerManager,
                new PracticeDiscoveryCustomSceneProperties(
                        true, Duration.ofSeconds(5), "legacy-prompt", "legacy-strategy", "agentic",
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

    @Test
    @SuppressWarnings("unchecked")
    void fakeModeDelegatesNewDraftToTheSameBoundedOrchestratorWithoutProviderManager() {
        var queries = mock(PracticeGeneratedContentQueryMapper.class);
        var commands = mock(PracticeGeneratedContentCommands.class);
        var orchestrator = mock(CustomSceneGenerationOrchestrator.class);
        when(commands.reserveDraft(any(), any())).thenAnswer(invocation ->
                new DraftReservation(invocation.getArgument(0, PracticeGeneratedContentEntity.class), true));
        var active = new PracticeGeneratedContentEntity();
        active.setStatus("active");
        when(orchestrator.execute(any())).thenReturn(active);

        var service = orchestratedService(queries, commands, orchestrator, "fake");

        assertThat(service.generateCustomScene(request())).isSameAs(active);
        verify(orchestrator).execute(any());
        verify(commands, never()).startGeneration(any(), any(), anyInt(), any());
    }

    @Test
    @SuppressWarnings("unchecked")
    void activeResultWithSameOwnerFingerprintProfileAndEpochReusesWithoutOrchestratorExecution() {
        var queries = mock(PracticeGeneratedContentQueryMapper.class);
        var commands = mock(PracticeGeneratedContentCommands.class);
        var orchestrator = mock(CustomSceneGenerationOrchestrator.class);
        var active = new PracticeGeneratedContentEntity();
        active.setGeneratedContentId("pgc_supported_active");
        active.setStatus("active");
        active.setOwnerScope("account");
        when(queries.findLiveByFingerprint(any(), any(), any(), any(), any(), any(), anyInt()))
                .thenReturn(active);
        when(queries.findApprovedUtterances("pgc_supported_active"))
                .thenReturn(completeApprovedUtterances("pgc_supported_active"));

        var service = orchestratedService(queries, commands, orchestrator);

        assertThat(service.generateCustomScene(request())).isSameAs(active);
        var owner = new PracticeGeneratedContentOwnerProperties("owner-v1", "x".repeat(32));
        var keyFactory = new PracticeGeneratedContentKeyFactory(owner);
        var expectedFingerprint = keyFactory.requestFingerprint(
                keyFactory.ownerKey("installation", "install_test"),
                new PracticeGeneratedContentKeyFactory.RequestFingerprintMaterial(
                        "onboarding", "custom_scene", "出门前穿鞋", "m7_11", "calmer_care", "zh-CN",
                        "custom-scene-generation-v4", "custom-scene-quality-v1", "custom-scene-evidence-v1", 1));
        verify(queries).findLiveByFingerprint(
                eq(keyFactory.ownerKey("installation", "install_test")), eq("owner-v1"),
                eq("onboarding"), eq("custom_scene"), eq(expectedFingerprint),
                eq("custom-scene-generation-v4"), eq(1));
        verify(orchestrator, never()).execute(any());
        verify(commands, never()).reserveDraft(any(), any());
    }

    @Test
    void unsupportedLegacyActiveIsQuarantinedBeforeFingerprintReuse() {
        var queries = mock(PracticeGeneratedContentQueryMapper.class);
        var commands = mock(PracticeGeneratedContentCommands.class);
        var orchestrator = mock(CustomSceneGenerationOrchestrator.class);
        var legacy = active("pgc_legacy_reuse");
        when(queries.findLiveByFingerprint(any(), any(), any(), any(), any(), any(), anyInt()))
                .thenReturn(legacy);
        when(queries.findApprovedUtterances("pgc_legacy_reuse")).thenReturn(List.of());
        var service = orchestratedService(queries, commands, orchestrator);

        assertThatThrownBy(() -> service.generateCustomScene(request()))
                .isInstanceOf(com.zhangspaghetti.babytalk.web.ContractException.class)
                .satisfies(error -> {
                    var contract = (com.zhangspaghetti.babytalk.web.ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                    assertThat(contract.code()).isEqualTo("generation_unavailable");
                    assertThat(contract.details())
                            .containsEntry("reason", "legacy_active_bundle_unsupported")
                            .containsEntry("retryable", true);
                });
        verify(commands).quarantineUnsupportedActive(eq("pgc_legacy_reuse"), any(), any());
        verify(orchestrator, never()).execute(any());
    }

    @Test
    void unsupportedLegacyActiveIsQuarantinedBeforeDirectRead() {
        var queries = mock(PracticeGeneratedContentQueryMapper.class);
        var commands = mock(PracticeGeneratedContentCommands.class);
        var legacy = active("pgc_legacy_read");
        when(queries.findActiveByGeneratedContentId(eq("pgc_legacy_read"), any(), any())).thenReturn(legacy);
        when(queries.findApprovedUtterances("pgc_legacy_read")).thenReturn(List.of());
        var service = orchestratedService(queries, commands, mock(CustomSceneGenerationOrchestrator.class));

        assertThatThrownBy(() -> service.findActiveOrPromotedByGeneratedContentId("pgc_legacy_read"))
                .isInstanceOf(com.zhangspaghetti.babytalk.web.ContractException.class)
                .satisfies(error -> {
                    var contract = (com.zhangspaghetti.babytalk.web.ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                    assertThat(contract.details()).containsEntry("reason", "legacy_active_bundle_unsupported");
                });
        verify(commands).quarantineUnsupportedActive(eq("pgc_legacy_read"), any(), any());
    }

    @Test
    @SuppressWarnings("unchecked")
    void qualityAttemptAndJudgeRejectsNormalizeToNonRetryableInvalidOutput() {
        var queries = mock(PracticeGeneratedContentQueryMapper.class);
        var commands = mock(PracticeGeneratedContentCommands.class);
        var orchestrator = mock(CustomSceneGenerationOrchestrator.class);
        when(commands.reserveDraft(any(), any())).thenAnswer(invocation ->
                new DraftReservation(invocation.getArgument(0, PracticeGeneratedContentEntity.class), true));
        var rejected = terminal("rejected", "generation_invalid_output", false);
        when(orchestrator.execute(any())).thenReturn(rejected);
        var service = orchestratedService(queries, commands, orchestrator);

        assertThatThrownBy(() -> service.generateCustomScene(request()))
                .isInstanceOf(com.zhangspaghetti.babytalk.web.ContractException.class)
                .satisfies(error -> {
                    var contract = (com.zhangspaghetti.babytalk.web.ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_GATEWAY);
                    assertThat(contract.code()).isEqualTo("generation_invalid_output");
                    assertThat(contract.details())
                            .containsEntry("retryable", false)
                            .containsEntry("suggestCatalogFallback", true);
                });
    }

    @Test
    @SuppressWarnings("unchecked")
    void activationFallbackReusesWinnerByGenerationProfileInsteadOfLegacyPromptVersion() {
        var queries = mock(PracticeGeneratedContentQueryMapper.class);
        var commands = mock(PracticeGeneratedContentCommands.class);
        var generator = mock(CustomSceneGenerator.class);
        var validator = mock(CustomSceneGeneratedContentValidator.class);
        var registry = new VersionedResourceRegistry(new DefaultResourceLoader());
        var providerManager = mock(ObjectProvider.class);
        when(providerManager.getIfAvailable()).thenReturn(null);
        when(commands.reserveDraft(any(), any())).thenAnswer(invocation ->
                new DraftReservation(invocation.getArgument(0, PracticeGeneratedContentEntity.class), true));
        when(commands.startGeneration(any(), any(), anyInt(), any()))
                .thenReturn(GenerationStartDecision.STARTED);
        var candidate = new CustomSceneGenerator.GeneratedPracticeContentCandidate(
                "日常照护", "穿鞋出门", "Shoes on", "拿起鞋子。", "慢慢说。",
                "Shoes on.", "穿鞋出门。", "shoes on", "starter", "fake");
        when(generator.generateCareMoment(any())).thenReturn(GeneratedCareMomentBundle.fakeFixture(candidate));
        when(validator.normalizeAndValidate(any(), any(), any())).thenReturn(candidate);
        when(commands.activate(any())).thenReturn(java.util.Optional.empty());
        var winner = new PracticeGeneratedContentEntity();
        winner.setGeneratedContentId("pgc_activation_winner");
        winner.setStatus("active");
        winner.setGenerationProfileVersion(registry.currentGenerationProfile().version());
        when(queries.findActiveByFingerprint(any(), any(), any(), any(), any(), any(), anyInt(), any()))
                .thenReturn(winner);
        when(queries.findApprovedUtterances("pgc_activation_winner"))
                .thenReturn(completeApprovedUtterances("pgc_activation_winner"));

        var policy = PracticeDiscoveryPolicyTestFixture.properties();
        var canonicalizer = new SceneTextCanonicalizer();
        var owner = new PracticeGeneratedContentOwnerProperties("owner-v1", "x".repeat(32));
        var service = new PracticeGeneratedContentService(
                queries,
                commands,
                generator,
                validator,
                null,
                registry,
                providerManager,
                new PracticeDiscoveryCustomSceneProperties(
                        true, Duration.ofSeconds(5), "legacy-prompt", "legacy-strategy", "fake",
                        null, null, null, null, null, null, 3),
                policy,
                owner,
                new PracticeGeneratedContentKeyFactory(owner),
                canonicalizer,
                new SceneTextSecurityPolicy(
                        policy,
                        new PolicyTextMatcher(canonicalizer),
                        SceneTextSecurityConfiguration.configuredSpoofChecker()),
                new PolicyTextMatcher(canonicalizer));

        assertThat(service.generateCustomScene(request())).isSameAs(winner);
        assertThat(registry.currentGenerationProfile().version()).isNotEqualTo("legacy-prompt");
        verify(queries).findActiveByFingerprint(
                any(), eq("owner-v1"), eq("onboarding"), eq("custom_scene"), any(),
                eq(registry.currentGenerationProfile().version()), eq(1), any());
    }

    @Test
    @SuppressWarnings("unchecked")
    void orchestratorTerminalsUsePersistedCodeRetryabilityForPublicSemantics() {
        var queries = mock(PracticeGeneratedContentQueryMapper.class);
        var commands = mock(PracticeGeneratedContentCommands.class);
        var orchestrator = mock(CustomSceneGenerationOrchestrator.class);
        when(commands.reserveDraft(any(), any())).thenAnswer(invocation ->
                new DraftReservation(invocation.getArgument(0, PracticeGeneratedContentEntity.class), true));
        when(orchestrator.execute(any()))
                .thenReturn(terminal("expired", "generation_timeout", true))
                .thenReturn(terminal("expired", "insufficient_evidence", true))
                .thenReturn(terminal("expired", "generation_interrupted", true))
                .thenReturn(terminal("expired", "generation_unavailable", false));
        var service = orchestratedService(queries, commands, orchestrator);

        assertThatThrownBy(() -> service.generateCustomScene(request()))
                .isInstanceOf(com.zhangspaghetti.babytalk.web.ContractException.class)
                .satisfies(error -> {
                    var contract = (com.zhangspaghetti.babytalk.web.ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.GATEWAY_TIMEOUT);
                    assertThat(contract.code()).isEqualTo("generation_timeout");
                    assertThat(contract.details()).containsEntry("retryable", true);
                });
        assertThatThrownBy(() -> service.generateCustomScene(request()))
                .isInstanceOf(com.zhangspaghetti.babytalk.web.ContractException.class)
                .satisfies(error -> {
                    var contract = (com.zhangspaghetti.babytalk.web.ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                    assertThat(contract.code()).isEqualTo("generation_unavailable");
                    assertThat(contract.details())
                            .containsEntry("reason", "insufficient_evidence")
                            .containsEntry("retryable", true);
                });
        assertThatThrownBy(() -> service.generateCustomScene(request()))
                .isInstanceOf(com.zhangspaghetti.babytalk.web.ContractException.class)
                .satisfies(error -> {
                    var contract = (com.zhangspaghetti.babytalk.web.ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                    assertThat(contract.code()).isEqualTo("generation_unavailable");
                    assertThat(contract.details())
                            .containsEntry("reason", "generation_interrupted")
                            .containsEntry("retryable", true);
                });
        assertThatThrownBy(() -> service.generateCustomScene(request()))
                .isInstanceOf(com.zhangspaghetti.babytalk.web.ContractException.class)
                .satisfies(error -> {
                    var contract = (com.zhangspaghetti.babytalk.web.ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                    assertThat(contract.code()).isEqualTo("generation_unavailable");
                    assertThat(contract.details())
                            .containsEntry("reason", "generation_unavailable")
                            .containsEntry("retryable", false);
                });
    }

    @SuppressWarnings("unchecked")
    private PracticeGeneratedContentService orchestratedService(
            PracticeGeneratedContentQueryMapper queries,
            PracticeGeneratedContentCommands commands,
            CustomSceneGenerationOrchestrator orchestrator
    ) {
        return orchestratedService(queries, commands, orchestrator, "agentic");
    }

    @SuppressWarnings("unchecked")
    private PracticeGeneratedContentService orchestratedService(
            PracticeGeneratedContentQueryMapper queries,
            PracticeGeneratedContentCommands commands,
            CustomSceneGenerationOrchestrator orchestrator,
            String providerMode
    ) {
        var registry = new VersionedResourceRegistry(new DefaultResourceLoader());
        var providerManager = mock(ObjectProvider.class);
        when(providerManager.getIfAvailable()).thenReturn(null);
        var policy = PracticeDiscoveryPolicyTestFixture.properties();
        var canonicalizer = new SceneTextCanonicalizer();
        var owner = new PracticeGeneratedContentOwnerProperties("owner-v1", "x".repeat(32));
        return new PracticeGeneratedContentService(
                queries,
                commands,
                mock(CustomSceneGenerator.class),
                mock(CustomSceneGeneratedContentValidator.class),
                orchestrator,
                registry,
                providerManager,
                new PracticeDiscoveryCustomSceneProperties(
                        true, Duration.ofSeconds(5), "legacy-prompt", "legacy-strategy", providerMode,
                        null, null, null, null, null, null, 3),
                policy,
                owner,
                new PracticeGeneratedContentKeyFactory(owner),
                canonicalizer,
                new SceneTextSecurityPolicy(
                        policy,
                        new PolicyTextMatcher(canonicalizer),
                        SceneTextSecurityConfiguration.configuredSpoofChecker()),
                new PolicyTextMatcher(canonicalizer));
    }

    private PracticeGeneratedContentService.CustomSceneDiscoveryRequest request() {
        return new PracticeGeneratedContentService.CustomSceneDiscoveryRequest(
                "onboarding", "custom_scene", "install_test", null, null,
                "m7_11", "calmer_care", "zh-CN", "出门前穿鞋");
    }

    private PracticeGeneratedContentEntity terminal(String status, String code, boolean retryable) {
        var result = new PracticeGeneratedContentEntity();
        result.setStatus(status);
        result.setGenerationErrorCode(code);
        result.setGenerationErrorRetryable(retryable);
        return result;
    }

    private PracticeGeneratedContentEntity active(String generatedContentId) {
        var active = new PracticeGeneratedContentEntity();
        active.setGeneratedContentId(generatedContentId);
        active.setStatus("active");
        active.setOwnerScope("account");
        return active;
    }

    private List<PracticeGeneratedContentUtteranceEntity> completeApprovedUtterances(String generatedContentId) {
        var rows = new ArrayList<PracticeGeneratedContentUtteranceEntity>();
        rows.add(utterance(generatedContentId, "starter", null, 1));
        rows.add(utterance(generatedContentId, "reaction_support", "cooperating", 2));
        rows.add(utterance(generatedContentId, "reaction_support", "hesitant", 3));
        rows.add(utterance(generatedContentId, "reaction_support", "resisting", 4));
        rows.add(utterance(generatedContentId, "reaction_support", "no_response", 5));
        rows.add(utterance(generatedContentId, "reaction_support", "other", 6));
        return List.copyOf(rows);
    }

    private PracticeGeneratedContentUtteranceEntity utterance(
            String generatedContentId,
            String role,
            String reaction,
            int displayOrder
    ) {
        var row = new PracticeGeneratedContentUtteranceEntity();
        row.setGeneratedContentId(generatedContentId);
        row.setRole(role);
        row.setReactionType(reaction);
        row.setEnglishText("Shoes on.");
        row.setChineseText("穿鞋出门。");
        row.setPronunciationHint("shoes on");
        row.setTprActionZh("拿起鞋子。 ");
        row.setDeliveryGuidanceZh("慢慢说，等宝宝回应。 ");
        row.setDifficulty("starter");
        row.setDisplayOrder(displayOrder);
        row.setProviderOrigin("provider_generated");
        row.setProviderName("primary");
        row.setProviderModelName("gpt-test");
        row.setProviderAttemptNumber(1);
        return row;
    }
}
