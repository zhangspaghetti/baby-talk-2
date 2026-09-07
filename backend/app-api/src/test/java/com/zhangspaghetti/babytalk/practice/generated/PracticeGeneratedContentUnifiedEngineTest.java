package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiProviderManager;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneIntentClassifier;
import com.zhangspaghetti.babytalk.practice.discovery.PolicyTextMatcher;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryCustomSceneProperties;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyTestFixture;
import com.zhangspaghetti.babytalk.practice.discovery.SceneGeneratedContentValidator;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextCanonicalizer;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextSecurityConfiguration;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextSecurityPolicy;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity;
import com.zhangspaghetti.babytalk.practice.scene.GenerationSubject;
import com.zhangspaghetti.babytalk.practice.scene.ScenePersonalizationContext;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.core.io.DefaultResourceLoader;

class PracticeGeneratedContentUnifiedEngineTest {

    private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-09-02T04:00:00Z"), ZoneOffset.UTC);
    private static final PracticeGeneratedContentOwnerProperties OWNER_PROPERTIES =
            new PracticeGeneratedContentOwnerProperties("owner-v1", "x".repeat(32));

    @Test
    @SuppressWarnings("unchecked")
    void customAndPresetUseTheSameOrchestratorSeam() {
        var queries = mock(PracticeGeneratedContentQueryMapper.class);
        var commands = mock(PracticeGeneratedContentCommands.class);
        var orchestrator = mock(SceneGenerationOrchestrator.class);
        var provider = mock(ObjectProvider.class);
        when(provider.getIfAvailable()).thenReturn(null);
        when(commands.reserveDraft(any(), any())).thenAnswer(invocation ->
                new DraftReservation(invocation.getArgument(0, PracticeGeneratedContentEntity.class), true));
        when(orchestrator.execute(any())).thenAnswer(invocation -> active("pgc_unified_" +
                invocation.getArgument(0, SceneGenerationOrchestrator.GenerationExecution.class)
                        .reservedContent().inputSource()));

        var service = orchestratedService(queries, commands, orchestrator, provider);

        var custom = service.generateScene(input("custom", "洗澡后哄睡", null, null, null, null, "request-custom"));
        var preset = service.generateScene(input("preset", "给宝宝穿鞋", 11L, 22L,
                "daily_care", "bath_time", "request-preset"));

        assertThat(custom.status()).isEqualTo("active");
        assertThat(preset.status()).isEqualTo("active");
        verify(orchestrator, times(2)).execute(any());
    }

    @Test
    void profileOwnedPresetReuseIgnoresActorRoleButProviderContextKeepsFirstRole() {
        var queries = mock(PracticeGeneratedContentQueryMapper.class);
        var commands = mock(PracticeGeneratedContentCommands.class);
        var generator = mock(SceneContentGenerator.class);
        var cached = new AtomicReference<PracticeGeneratedContentEntity>();
        when(queries.findLiveByFingerprint(any(), any(), any(), any(), any(), any(), anyInt()))
                .thenAnswer(invocation -> cached.get());
        when(queries.findApprovedUtterances(any()))
                .thenAnswer(invocation -> completeApprovedUtterances(invocation.getArgument(0, String.class)));
        when(commands.reserveDraft(any(), any())).thenAnswer(invocation ->
                new DraftReservation(invocation.getArgument(0, PracticeGeneratedContentEntity.class), true));
        when(commands.startGeneration(any(), any(), anyInt(), any())).thenReturn(GenerationStartDecision.STARTED);
        when(commands.activate(any())).thenAnswer(invocation -> {
            var active = invocation.getArgument(0, PracticeGeneratedContentEntity.class);
            cached.set(active);
            return Optional.of(active);
        });
        when(generator.generateCareMoment(any())).thenReturn(GeneratedCareMomentBundle.fakeFixture(candidate()));

        var service = serviceWithGenerator(queries, commands, generator);
        var primary = service.generateScene(input("preset", "给宝宝穿鞋", 11L, 22L,
                "daily_care", "bath_time", "request-primary", "primary_caregiver"));
        var caregiver = service.generateScene(input("preset", "给宝宝穿鞋", 11L, 22L,
                "daily_care", "bath_time", "request-caregiver", "caregiver"));

        assertThat(caregiver.generatedContentId()).isEqualTo(primary.generatedContentId());
        var requestCaptor = ArgumentCaptor.forClass(SceneContentGenerator.GeneratorRequest.class);
        verify(generator).generateCareMoment(requestCaptor.capture());
        assertThat(requestCaptor.getValue().stableActivityId()).isEqualTo("bath_time");
        assertThat(primary.ownerScope()).isEqualTo("profile");
        assertThat(primary.spaceSlug()).isEqualTo("daily_care");
        assertThat(primary.activitySlug()).isEqualTo("bath_time");
    }

    @Test
    void unifiedRowsPersistProfileSourceAndStablePresetRoutesWithoutPresetText() {
        var queries = mock(PracticeGeneratedContentQueryMapper.class);
        var commands = mock(PracticeGeneratedContentCommands.class);
        var generator = mock(SceneContentGenerator.class);
        var drafts = new ArrayList<PracticeGeneratedContentEntity>();
        when(commands.reserveDraft(any(), any())).thenAnswer(invocation -> {
            var draft = invocation.getArgument(0, PracticeGeneratedContentEntity.class);
            drafts.add(draft);
            return new DraftReservation(draft, true);
        });
        when(commands.startGeneration(any(), any(), anyInt(), any())).thenReturn(GenerationStartDecision.STARTED);
        when(commands.activate(any())).thenAnswer(invocation ->
                Optional.of(invocation.getArgument(0, PracticeGeneratedContentEntity.class)));
        when(generator.generateCareMoment(any())).thenReturn(GeneratedCareMomentBundle.fakeFixture(candidate()));

        var service = serviceWithGenerator(queries, commands, generator);
        var custom = service.generateScene(input("custom", "洗澡后哄睡", null, null,
                null, null, "request-custom"));
        var preset = service.generateScene(input("preset", "受控预置生成文案", 11L, 22L,
                "daily_care", "bath_time", "request-preset"));

        assertThat(custom.mode()).isEqualTo("scene_generation");
        assertThat(custom.inputSource()).isEqualTo("custom");
        assertThat(custom.ownerScope()).isEqualTo("profile");
        assertThat(custom.accountId()).isEqualTo("owner-account");
        assertThat(custom.profileId()).isEqualTo("profile-1");
        assertThat(custom.profileVersion()).isEqualTo(4);
        assertThat(custom.householdContextVersion()).isEqualTo("2026-W36");
        assertThat(custom.installationRefHash()).isNull();
        assertThat(custom.spaceSlug()).startsWith("gen_scene_");

        assertThat(preset.mode()).isEqualTo("scene_generation");
        assertThat(preset.inputSource()).isEqualTo("preset");
        assertThat(preset.presetActivityId()).isEqualTo(11L);
        assertThat(preset.presetSceneVersionId()).isEqualTo(22L);
        assertThat(preset.spaceSlug()).isEqualTo("daily_care");
        assertThat(preset.activitySlug()).isEqualTo("bath_time");
        assertThat(preset.normalizedSceneText()).isNull();
        assertThat(drafts).filteredOn(row -> "preset".equals(row.inputSource()))
                .singleElement()
                .satisfies(row -> assertThat(row.normalizedSceneText())
                        .isEqualTo("preset:11:22")
                        .doesNotContain("受控预置生成文案"));
    }

    @Test
    void mixedSourceIdentityFailsBeforeReservation() {
        var queries = mock(PracticeGeneratedContentQueryMapper.class);
        var commands = mock(PracticeGeneratedContentCommands.class);
        var service = serviceWithGenerator(queries, commands, mock(SceneContentGenerator.class));

        assertThatThrownBy(() -> service.generateScene(input(
                "custom", "洗澡后哄睡", 11L, 22L, "daily_care", "bath_time", "request-mixed")))
                .isInstanceOf(com.zhangspaghetti.babytalk.web.ContractException.class)
                .satisfies(error -> assertThat(
                        ((com.zhangspaghetti.babytalk.web.ContractException) error).code())
                        .isEqualTo("invalid_scene_input"));
    }

    private PracticeGeneratedContentService serviceWithGenerator(
            PracticeGeneratedContentQueryMapper queries,
            PracticeGeneratedContentCommands commands,
            SceneContentGenerator generator
    ) {
        var policy = PracticeDiscoveryPolicyTestFixture.properties();
        var properties = PracticeDiscoveryCustomSceneProperties.enabledForTest("fake");
        var canonicalizer = new SceneTextCanonicalizer();
        return new PracticeGeneratedContentService(
                queries,
                commands,
                generator,
                validator(policy),
                properties,
                policy,
                CLOCK,
                OWNER_PROPERTIES);
    }

    @SuppressWarnings("unchecked")
    private PracticeGeneratedContentService orchestratedService(
            PracticeGeneratedContentQueryMapper queries,
            PracticeGeneratedContentCommands commands,
            SceneGenerationOrchestrator orchestrator,
            ObjectProvider<PracticeAiProviderManager> provider
    ) {
        var policy = PracticeDiscoveryPolicyTestFixture.properties();
        var canonicalizer = new SceneTextCanonicalizer();
        return new PracticeGeneratedContentService(
                queries,
                commands,
                mock(SceneContentGenerator.class),
                mock(SceneGeneratedContentValidator.class),
                orchestrator,
                new VersionedResourceRegistry(new DefaultResourceLoader()),
                provider,
                PracticeDiscoveryCustomSceneProperties.enabledForTest("fake"),
                policy,
                OWNER_PROPERTIES,
                new PracticeGeneratedContentKeyFactory(OWNER_PROPERTIES),
                canonicalizer,
                new SceneTextSecurityPolicy(policy, new PolicyTextMatcher(canonicalizer),
                        SceneTextSecurityConfiguration.configuredSpoofChecker()),
                new PolicyTextMatcher(canonicalizer));
    }

    private SceneGeneratedContentValidator validator(
            com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyProperties policy
    ) {
        return new SceneGeneratedContentValidator(policy, new CustomSceneIntentClassifier(policy));
    }

    private SceneGenerationInput input(
            String source,
            String resolvedText,
            Long activityId,
            Long versionId,
            String stableSpaceId,
            String stableActivityId,
            String clientRequestId
    ) {
        return input(source, resolvedText, activityId, versionId, stableSpaceId, stableActivityId,
                clientRequestId, "primary_caregiver");
    }

    private SceneGenerationInput input(
            String source,
            String resolvedText,
            Long activityId,
            Long versionId,
            String stableSpaceId,
            String stableActivityId,
            String clientRequestId,
            String actorRole
    ) {
        var subject = new GenerationSubject(
                "actor-" + actorRole,
                "owner-account",
                "profile-1",
                4,
                "小米",
                "m7_11",
                "calmer_care",
                "household-1",
                actorRole);
        var personalization = new ScenePersonalizationContext(
                "小米",
                "m7_11",
                "calmer_care",
                "zh-CN",
                actorRole,
                7,
                "hesitant",
                "daily_care/bath_time=7",
                "2026-W36");
        return new SceneGenerationInput(
                source,
                resolvedText,
                subject,
                personalization,
                activityId,
                versionId,
                stableSpaceId,
                stableActivityId,
                "zh-CN",
                "installation-" + actorRole,
                clientRequestId);
    }

    private PracticeGeneratedContentEntity active(String id) {
        var row = new PracticeGeneratedContentEntity();
        row.setGeneratedContentId(id);
        row.setStatus("active");
        return row;
    }

    private SceneContentGenerator.GeneratedPracticeContentCandidate candidate() {
        return new SceneContentGenerator.GeneratedPracticeContentCandidate(
                "日常照护", "穿鞋出门", "Shoes on", "拿起鞋子。", "慢慢说。",
                "Shoes on.", "穿鞋出门。", "shoes on", "starter", "fake");
    }

    private List<PracticeGeneratedContentUtteranceEntity> completeApprovedUtterances(String generatedContentId) {
        var rows = new ArrayList<PracticeGeneratedContentUtteranceEntity>();
        rows.add(utterance(generatedContentId, "starter", null, 1));
        rows.add(utterance(generatedContentId, "reaction_support", "cooperating", 2));
        rows.add(utterance(generatedContentId, "reaction_support", "hesitant", 3));
        rows.add(utterance(generatedContentId, "reaction_support", "resisting", 4));
        rows.add(utterance(generatedContentId, "reaction_support", "no_response", 5));
        rows.add(utterance(generatedContentId, "reaction_support", "other", 6));
        return rows;
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
        row.setEnglishText("We do it together.");
        row.setChineseText("我们一起做。");
        row.setPronunciationHint("we do it together");
        row.setTprActionZh("一起做。");
        row.setDeliveryGuidanceZh("慢慢说。");
        row.setDifficulty("starter");
        row.setDisplayOrder(displayOrder);
        row.setApprovalStatus("approved");
        row.setApprovedContentVersion(1);
        row.setBundleSchemaVersion("custom-scene-generated-output-v1");
        row.setProviderOrigin("provider_generated");
        row.setProviderName("provider");
        row.setProviderModelName("model");
        row.setProviderAttemptNumber(1);
        return row;
    }
}
