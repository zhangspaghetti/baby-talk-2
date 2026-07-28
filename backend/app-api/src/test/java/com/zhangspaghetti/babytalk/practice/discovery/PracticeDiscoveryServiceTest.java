package com.zhangspaghetti.babytalk.practice.discovery;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentService;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryRequest;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryResponse.MomentResponse;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryResponse.SceneResponse;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryResponse.StarterUtteranceResponse;
import com.zhangspaghetti.babytalk.practice.catalog.PracticeCatalogService;
import com.zhangspaghetti.babytalk.practice.catalog.model.PracticeActivityRow;
import com.zhangspaghetti.babytalk.practice.catalog.model.PracticePhraseRow;
import com.zhangspaghetti.babytalk.practice.catalog.model.PracticeSpaceRow;
import com.zhangspaghetti.babytalk.practice.catalog.model.StarterPhraseSourcePolicy;
import com.zhangspaghetti.babytalk.profile.BabyProfileMapper;
import com.zhangspaghetti.babytalk.profile.model.BabyProfileRow;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.lang.reflect.Constructor;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class PracticeDiscoveryServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-03T02:00:00Z");
    private static final OffsetDateTime NOW_DB = OffsetDateTime.ofInstant(NOW, ZoneOffset.UTC);

    @Mock
    private PracticeCatalogService catalogMapper;

    @Mock
    private AuthConsentSyncService authConsentSyncService;

    @Mock
    private BabyProfileMapper babyProfileMapper;

    @Mock
    private PracticeGeneratedContentService generatedContentService;

    private PracticeDiscoveryService service;

    @BeforeEach
    void setUp() {
        service = new PracticeDiscoveryService(
                catalogMapper,
                authConsentSyncService,
                babyProfileMapper,
                generatedContentService
        );
    }

    @Test
    void returnsSceneMomentStarterFromCatalogRows() {
        seedDefaultCatalog();

        var response = service.discover(draftRequest("calmer_care", 6), null);

        assertThat(response.source()).isEqualTo("catalog");
        assertThat(response.scenes()).isNotEmpty();
        assertThat(response.moments()).isNotEmpty();
        assertThat(response.starter()).isNotNull();
        assertThat(response.starter().sceneId()).isEqualTo("daily_care");
        assertThat(response.starter().spaceId()).isEqualTo("daily_care");
        assertThat(response.starter().momentId()).isEqualTo("bath_time");
        assertThat(response.starter().activityId()).isEqualTo("bath_time");
        assertThat(response.starter().utteranceId()).isEqualTo("bath_time_warm_water");
        assertThat(response.starter().phraseId()).isEqualTo("bath_time_warm_water");
        assertThat(response.trace().candidateCount()).isEqualTo(3);
        assertThat(response.trace().returnedCount()).isEqualTo(3);
    }

    @Test
    void deterministicRankingForSameRequestAndCatalog() {
        seedDefaultCatalog();

        var first = service.discover(draftRequest("calmer_care", 6), null);
        var second = service.discover(draftRequest("calmer_care", 6), null);

        assertThat(first.scenes()).isEqualTo(second.scenes());
        assertThat(first.moments()).isEqualTo(second.moments());
        assertThat(first.starter()).isEqualTo(second.starter());
        assertThat(first.discoveryTraceId()).isNotEqualTo(second.discoveryTraceId());
        assertThat(first.discoveryTraceId()).startsWith("disc_");
    }

    @Test
    void deterministicFallbackWhenPreferredRankingIsSparse() {
        when(catalogMapper.findSpaces("zh-CN", 50)).thenReturn(List.of(space("family_rhythm", 2)));
        when(catalogMapper.findActivitiesBySpace("family_rhythm", "zh-CN", 50))
                .thenReturn(List.of(activity("bedtime_routine", "family_rhythm", 1, "seed")));
        when(catalogMapper.findStarterPhrase("bedtime_routine", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY))
                .thenReturn(Optional.of(phrase("bedtime_good_night", "bedtime_routine", 1, "seed")));

        var response = service.discover(draftRequest("calmer_care", 6), null);

        assertThat(response.starter().activityId()).isEqualTo("bedtime_routine");
        assertThat(response.trace().fallbackReason()).isEqualTo("fallback_first_catalog");
    }

    @Test
    void noDuplicateScenesMomentsOrStarters() {
        when(catalogMapper.findSpaces("zh-CN", 50))
                .thenReturn(List.of(space("daily_care", 1), space("daily_care", 1)));
        when(catalogMapper.findActivitiesBySpace("daily_care", "zh-CN", 50))
                .thenReturn(List.of(
                        activity("bath_time", "daily_care", 1, "seed"),
                        activity("bath_time", "daily_care", 1, "seed")));
        when(catalogMapper.findStarterPhrase("bath_time", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY))
                .thenReturn(Optional.of(phrase("bath_time_warm_water", "bath_time", 1, "seed")));

        var response = service.discover(draftRequest("calmer_care", 6), null);

        assertThat(response.scenes()).extracting(SceneResponse::sceneId)
                .containsExactly("daily_care");
        assertThat(response.moments()).extracting(MomentResponse::momentId)
                .containsExactly("bath_time");
        assertThat(response.moments().get(0).starterUtterances())
                .extracting(StarterUtteranceResponse::phraseId)
                .containsExactly("bath_time_warm_water");
    }

    @Test
    void starterPhraseComesFromCatalogRowsAndSeedMapsToCatalogSource() {
        seedDefaultCatalog();

        var response = service.discover(draftRequest("calmer_care", 6), null);
        var utterance = response.moments().get(0).starterUtterances().get(0);

        assertThat(utterance.english()).isEqualTo("Warm water.");
        assertThat(utterance.chinese()).isEqualTo("水暖暖的。");
        assertThat(utterance.pronunciation()).isEqualTo("wɔːrm ˈwɔː.t̬ɚ");
        assertThat(utterance.difficulty()).isEqualTo("starter");
        assertThat(utterance.source()).isEqualTo("catalog");
        assertThat(response.starter().source()).isEqualTo("catalog");
    }

    @Test
    void llmRowsAreExcluded() {
        when(catalogMapper.findSpaces("zh-CN", 50)).thenReturn(List.of(space("daily_care", 1)));
        when(catalogMapper.findActivitiesBySpace("daily_care", "zh-CN", 50))
                .thenReturn(List.of(
                        activity("generated_activity", "daily_care", 1, "llm"),
                        activity("bath_time", "daily_care", 2, "seed")));
        when(catalogMapper.findStarterPhrase("bath_time", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY))
                .thenReturn(Optional.of(phrase("bath_time_warm_water", "bath_time", 1, "seed")));

        var response = service.discover(draftRequest("calmer_care", 6), null);

        assertThat(response.moments()).extracting(MomentResponse::activityId)
                .containsExactly("bath_time");
        verify(catalogMapper, never()).findStarterPhrase("generated_activity", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY);
        verify(catalogMapper, never()).findStarterPhrase(any(), any());
    }

    @Test
    void seedStarterPhraseIsUsedWhenLlmStarterWouldShadowLegacyStarterLookup() {
        when(catalogMapper.findSpaces("zh-CN", 50)).thenReturn(List.of(space("daily_care", 1)));
        when(catalogMapper.findActivitiesBySpace("daily_care", "zh-CN", 50))
                .thenReturn(List.of(activity("bath_time", "daily_care", 1, "seed")));
        when(catalogMapper.findStarterPhrase("bath_time", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY))
                .thenReturn(Optional.of(phrase("bath_time_warm_water", "bath_time", 1, "seed")));

        var response = service.discover(draftRequest("calmer_care", 6), null);

        assertThat(response.starter().phraseId()).isEqualTo("bath_time_warm_water");
        assertThat(response.moments().get(0).starterUtterances().get(0).source()).isEqualTo("catalog");
        verify(catalogMapper).findStarterPhrase("bath_time", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY);
        verify(catalogMapper, never()).findStarterPhrase("bath_time", "zh-CN");
    }

    @Test
    void traceReportsCandidateCountBeforeLimitAndReturnedCountAfterLimit() {
        seedDefaultCatalog();

        var response = service.discover(draftRequest("calmer_care", 1), null);

        assertThat(response.trace().candidateCount()).isEqualTo(3);
        assertThat(response.trace().returnedCount()).isEqualTo(1);
    }

    @Test
    void draftDiscoveryStillRequiresInstallationId() {
        assertThatThrownBy(() -> service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                "catalog",
                null,
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
                null,
                null
        ), null))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(contract.code()).isEqualTo("invalid_installation_id");
                });
    }

    @Test
    void draftDiscoveryStillRejectsUnsafeInstallationId() {
        assertThatThrownBy(() -> service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                "catalog",
                "_bad",
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
                null,
                null
        ), null))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(contract.code()).isEqualTo("invalid_installation_id");
                });
    }

    @Test
    void profileModeUsesSavedAgeRangeAndParentGoal() {
        seedDefaultCatalog();
        when(authConsentSyncService.requireAcceptedConsumerSession("sess_1", "读取宝宝档案场景发现"))
                .thenReturn(new AuthConsentSyncService.ConsumerSessionView("acct_1", "sess_1", "install_1", "accepted"));
        when(babyProfileMapper.findByAccountId("acct_1"))
                .thenReturn(profile("babyprof_1", "m18_23", "calmer_care"));

        var response = service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                "catalog",
                "install_1",
                "babyprof_1",
                null,
                null,
                "zh-CN",
                6,
                null,
                null
        ), "sess_1");

        assertThat(response.profileMode()).isEqualTo("authenticated_profile");
        assertThat(response.starter().activityId()).isEqualTo("bath_time");
        verify(babyProfileMapper).findByAccountId("acct_1");
    }

    @Test
    void profileBackedDiscoverySucceedsWithoutInstallationId() {
        seedDefaultCatalog();
        when(authConsentSyncService.requireAcceptedConsumerSession("sess_1", "读取宝宝档案场景发现"))
                .thenReturn(new AuthConsentSyncService.ConsumerSessionView("acct_1", "sess_1", "install_1", "accepted"));
        when(babyProfileMapper.findByAccountId("acct_1"))
                .thenReturn(profile("babyprof_1", "m18_23", "calmer_care"));

        var response = service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                "catalog",
                null,
                "babyprof_1",
                null,
                null,
                "zh-CN",
                6,
                null,
                null
        ), "sess_1");

        assertThat(response.profileMode()).isEqualTo("authenticated_profile");
        assertThat(response.starter().activityId()).isEqualTo("bath_time");
        verify(babyProfileMapper).findByAccountId("acct_1");
    }

    @Test
    void profileBackedDiscoveryRejectsUnsafeInstallationIdIfProvided() {
        when(authConsentSyncService.requireAcceptedConsumerSession("sess_1", "读取宝宝档案场景发现"))
                .thenReturn(new AuthConsentSyncService.ConsumerSessionView("acct_1", "sess_1", "install_1", "accepted"));
        when(babyProfileMapper.findByAccountId("acct_1"))
                .thenReturn(profile("babyprof_1", "m18_23", "calmer_care"));

        assertThatThrownBy(() -> service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                "catalog",
                "_bad",
                "babyprof_1",
                null,
                null,
                "zh-CN",
                6,
                null,
                null
        ), "sess_1"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(contract.code()).isEqualTo("invalid_installation_id");
                });
    }

    @Test
    void babyProfileIdWithoutSessionRequiresAuthentication() {
        assertThatThrownBy(() -> service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                "catalog",
                null,
                "babyprof_1",
                null,
                null,
                "zh-CN",
                6,
                null,
                null
        ), null))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.UNAUTHORIZED);
                    assertThat(contract.code()).isEqualTo("consumer_authentication_required");
                });
    }

    @Test
    void profileModeRejectsMissingSavedAgeRangeEvenWhenRequestProvidesOne() {
        when(authConsentSyncService.requireAcceptedConsumerSession("sess_1", "读取宝宝档案场景发现"))
                .thenReturn(new AuthConsentSyncService.ConsumerSessionView("acct_1", "sess_1", "install_1", "accepted"));
        when(babyProfileMapper.findByAccountId("acct_1"))
                .thenReturn(profile("babyprof_1", null, "calmer_care"));

        assertThatThrownBy(() -> service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                "catalog",
                "install_1",
                "babyprof_1",
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
                null,
                null
        ), "sess_1"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(contract.code()).isEqualTo("invalid_age_range");
                });
    }

    @Test
    void profileModeAllowsRequestParentGoalWhenSavedParentGoalMissing() {
        seedDefaultCatalog();
        when(authConsentSyncService.requireAcceptedConsumerSession("sess_1", "读取宝宝档案场景发现"))
                .thenReturn(new AuthConsentSyncService.ConsumerSessionView("acct_1", "sess_1", "install_1", "accepted"));
        when(babyProfileMapper.findByAccountId("acct_1"))
                .thenReturn(profile("babyprof_1", "m7_11", null));

        var response = service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                "catalog",
                "install_1",
                "babyprof_1",
                null,
                "calmer_care",
                "zh-CN",
                6,
                null,
                null
        ), "sess_1");

        assertThat(response.profileMode()).isEqualTo("authenticated_profile");
        assertThat(response.starter().source()).isEqualTo("catalog");
    }

    @Test
    void requestAgeOrGoalCannotSilentlyOverrideSavedValues() {
        when(authConsentSyncService.requireAcceptedConsumerSession("sess_1", "读取宝宝档案场景发现"))
                .thenReturn(new AuthConsentSyncService.ConsumerSessionView("acct_1", "sess_1", "install_1", "accepted"));
        when(babyProfileMapper.findByAccountId("acct_1"))
                .thenReturn(profile("babyprof_1", "m18_23", "calmer_care"));

        assertThatThrownBy(() -> service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                "catalog",
                "install_1",
                "babyprof_1",
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
                null,
                null
        ), "sess_1"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(contract.code()).isEqualTo("profile_context_mismatch");
                });
    }

    @Test
    void customSceneModeHydratesGeneratedRow() {
        var generated = generatedRow("pgc_service_generated");
        stubApprovedBundle(generated);
        when(generatedContentService.generateCustomScene(any()))
                .thenReturn(generated);

        var response = service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                "custom_scene",
                "install_1",
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
                null,
                "洗澡后哄睡"
        ), null);

        assertThat(response.source()).isEqualTo("generated");
        assertThat(response.generatedContentId()).isEqualTo("pgc_service_generated");
        assertThat(response.starter().source()).isEqualTo("generated");
        assertThat(response.starter().sceneId()).startsWith("gen_scene_");
        assertThat(response.starter().activityId()).startsWith("gen_activity_");
        assertThat(response.starter().phraseId()).startsWith("gen_phrase_");
        assertThat(response.scenes().get(0).reasonCode()).isEqualTo("custom_scene_match");
        verify(catalogMapper, never()).findSpaces(any(), eq(50));
    }

    @Test
    void customSceneCoachTipConcatenatesPersistedFieldsDirectly() {
        assertThat(discoverGeneratedCoachTip("看着宝宝。", "慢慢说一遍。"))
                .isEqualTo("看着宝宝。 慢慢说一遍。");
        assertThat(discoverGeneratedCoachTip("轻声说。", "轻声说。"))
                .isEqualTo("轻声说。 轻声说。");
    }

    @Test
    void acceptedAuthenticatedCustomSceneUsesAccountOwnerWithoutBabyProfileIdOrInstallationId() {
        when(authConsentSyncService.requireAcceptedConsumerSession("sess_accepted", "生成自定义练习场景"))
                .thenReturn(new AuthConsentSyncService.ConsumerSessionView(
                        "acct_custom_scene_owner",
                        "sess_accepted",
                        "install_1",
                        "accepted"
                ));
        var generated = generatedRow("pgc_service_generated_account");
        stubApprovedBundle(generated);
        when(generatedContentService.generateCustomScene(any()))
                .thenReturn(generated);
        var captor = ArgumentCaptor.forClass(PracticeGeneratedContentService.CustomSceneDiscoveryRequest.class);

        var response = service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                "custom_scene",
                null,
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
                null,
                "洗澡后哄睡"
        ), "sess_accepted");

        assertThat(response.profileMode()).isEqualTo("authenticated_request");
        verify(generatedContentService).generateCustomScene(captor.capture());
        assertThat(captor.getValue().accountId()).isEqualTo("acct_custom_scene_owner");
        assertThat(captor.getValue().profileId()).isNull();
        assertThat(captor.getValue().installationId()).isNull();
    }

    @Test
    void disabledCustomSceneFailsBeforeJwtConsentOrProfileLookup() {
        var failure = new ContractException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "generation_unavailable",
                "自定义场景生成当前不可用。"
        );
        doThrow(failure).when(generatedContentService).requireCustomSceneGenerationAvailable();

        assertThatThrownBy(() -> service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                "custom_scene",
                "install_1",
                "babyprof_1",
                null,
                null,
                "zh-CN",
                6,
                null,
                "洗澡后哄睡"
        ), "sess_disabled"))
                .isSameAs(failure);

        verify(generatedContentService).requireCustomSceneGenerationAvailable();
        verify(generatedContentService, never()).generateCustomScene(any());
        verifyNoInteractions(authConsentSyncService, babyProfileMapper);
    }

    @Test
    void authenticatedCustomScenePropagatesConsentRequiredInsteadOfUsingInstallationScope() {
        var failure = new ContractException(
                HttpStatus.CONFLICT,
                "consent_required",
                "当前账号尚未完成同意。"
        );
        when(authConsentSyncService.requireAcceptedConsumerSession("sess_required", "生成自定义练习场景"))
                .thenThrow(failure);

        assertThatThrownBy(() -> service.discover(customSceneRequest("_bad"), "sess_required"))
                .isSameAs(failure);
        verify(generatedContentService, never()).generateCustomScene(any());
    }

    @Test
    void authenticatedCustomScenePropagatesConsentRevokedInsteadOfUsingInstallationScope() {
        var failure = new ContractException(
                HttpStatus.FORBIDDEN,
                "consent_revoked",
                "同意已撤回。"
        );
        when(authConsentSyncService.requireAcceptedConsumerSession("sess_revoked", "生成自定义练习场景"))
                .thenThrow(failure);

        assertThatThrownBy(() -> service.discover(customSceneRequest(), "sess_revoked"))
                .isSameAs(failure);
        verify(generatedContentService, never()).generateCustomScene(any());
    }

    @Test
    void invalidOrMissingSurfaceRejected() {
        assertThatThrownBy(() -> service.discover(new PracticeDiscoveryRequest(
                null,
                "catalog",
                "install_1",
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
                null,
                null
        ), null))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(contract.code()).isEqualTo("invalid_discovery_surface");
                });

        assertThatThrownBy(() -> service.discover(new PracticeDiscoveryRequest(
                "daily_practice",
                "catalog",
                "install_1",
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
                null,
                null
        ), null))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(contract.code()).isEqualTo("invalid_discovery_surface");
                });
    }

    @Test
    void invalidOrMissingModeRejected() {
        assertThatThrownBy(() -> service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                null,
                "install_1",
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
                null,
                null
        ), null))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(contract.code()).isEqualTo("invalid_discovery_mode");
                });

        assertThatThrownBy(() -> service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                "surprise",
                "install_1",
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
                null,
                null
        ), null))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(contract.code()).isEqualTo("invalid_discovery_mode");
                });
    }

    @Test
    void serviceConstructorDoesNotDependOnAiOrMentorTypes() {
        assertThat(List.of(PracticeDiscoveryService.class.getDeclaredConstructors()).stream()
                .map(Constructor::getParameterTypes)
                .flatMap(Arrays::stream)
                .toList())
                .extracting(Class::getName)
                .noneMatch(name -> name.contains("Mentor")
                        || name.contains("SpringAi")
                        || name.contains("PalaceSearch")
                        || name.contains("PracticeGenerateController"));
    }

    private void seedDefaultCatalog() {
        when(catalogMapper.findSpaces("zh-CN", 50)).thenReturn(List.of(
                space("daily_care", 1),
                space("family_rhythm", 2)
        ));
        when(catalogMapper.findActivitiesBySpace("daily_care", "zh-CN", 50)).thenReturn(List.of(
                activity("bath_time", "daily_care", 1, "seed"),
                activity("diaper_change", "daily_care", 2, "seed")
        ));
        when(catalogMapper.findActivitiesBySpace("family_rhythm", "zh-CN", 50))
                .thenReturn(List.of(activity("bedtime_routine", "family_rhythm", 1, "seed")));
        when(catalogMapper.findStarterPhrase("bath_time", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY))
                .thenReturn(Optional.of(phrase("bath_time_warm_water", "bath_time", 1, "seed")));
        when(catalogMapper.findStarterPhrase("diaper_change", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY))
                .thenReturn(Optional.of(phrase("diaper_change_clean_diaper", "diaper_change", 1, "seed")));
        when(catalogMapper.findStarterPhrase("bedtime_routine", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY))
                .thenReturn(Optional.of(phrase("bedtime_good_night", "bedtime_routine", 1, "seed")));
    }

    private PracticeDiscoveryRequest draftRequest(String parentGoal, Integer limit) {
        return new PracticeDiscoveryRequest(
                "onboarding",
                "catalog",
                "install_1",
                null,
                "m7_11",
                parentGoal,
                "zh-CN",
                limit,
                "trace_1",
                null
        );
    }

    private PracticeDiscoveryRequest customSceneRequest() {
        return customSceneRequest(null);
    }

    private PracticeDiscoveryRequest customSceneRequest(String installationId) {
        return new PracticeDiscoveryRequest(
                "onboarding",
                "custom_scene",
                installationId,
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
                null,
                "洗澡后哄睡"
        );
    }

    private PracticeGeneratedContentEntity generatedRow(String generatedContentId) {
        var row = new PracticeGeneratedContentEntity();
        row.setGeneratedContentId(generatedContentId);
        row.setOwnerScope("installation");
        row.setOwnerKey("owner_service_generated");
        row.setOwnerKeyVersion("v1");
        row.setInstallationRefHash("install_1");
        row.setSurface("onboarding");
        row.setMode("custom_scene");
        row.setRequestFingerprint("fp_service_generated");
        row.setAgeRange("m7_11");
        row.setParentGoal("calmer_care");
        row.setLocale("zh-CN");
        row.setSpaceSlug("gen_scene_abc1234567890");
        row.setActivitySlug("gen_activity_abc1234567890");
        row.setPhraseSlug("gen_phrase_abc1234567890");
        row.setSpaceTitleZh("日常照护");
        row.setActivityTitleZh("洗澡安抚");
        row.setSceneTagEn("Bath care");
        row.setTprActionZh("看着宝宝");
        row.setDeliveryGuidanceZh("慢慢说一遍。");
        row.setEnglishText("Warm water.");
        row.setChineseText("水暖暖的。");
        row.setPronunciationHint("warm water");
        row.setDifficulty("starter");
        row.setGenerationSource("agentic_search");
        row.setStatus("active");
        row.setContentVersion(1);
        row.setGenerationStartedAt(NOW_DB);
        row.setCreatedAt(NOW_DB);
        row.setUpdatedAt(NOW_DB);
        return row;
    }

    private String discoverGeneratedCoachTip(String tprActionZh, String deliveryGuidanceZh) {
        var row = generatedRow("pgc_service_generated_tip");
        row.setTprActionZh(tprActionZh);
        row.setDeliveryGuidanceZh(deliveryGuidanceZh);
        stubApprovedBundle(row);
        when(generatedContentService.generateCustomScene(any())).thenReturn(row);
        var response = service.discover(new PracticeDiscoveryRequest(
                "onboarding",
                "custom_scene",
                "install_1",
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
                null,
                "洗澡后哄睡"
        ), null);
        return response.moments().get(0).coachTip();
    }

    private void stubApprovedBundle(PracticeGeneratedContentEntity row) {
        when(generatedContentService.findApprovedUtterances(row.generatedContentId()))
                .thenReturn(List.of(
                        approvedUtterance(row, "starter", null, 1,
                                row.englishText(), row.chineseText(), row.pronunciationHint(),
                                row.tprActionZh(), row.deliveryGuidanceZh()),
                        approvedUtterance(row, "reaction_support", "cooperating", 2,
                                "We can do this together.", "我们一起做。", "we can do this together",
                                "一起做动作。", "轻声邀请。"),
                        approvedUtterance(row, "reaction_support", "hesitant", 3,
                                "You can try slowly.", "你可以慢慢试。", "you can try slowly",
                                "把物品放近。", "留出等待。"),
                        approvedUtterance(row, "reaction_support", "resisting", 4,
                                "It is okay to pause.", "可以先停一下。", "it is okay to pause",
                                "手掌向外停一停。", "接住拒绝。"),
                        approvedUtterance(row, "reaction_support", "no_response", 5,
                                "I will wait with you.", "我陪你等一等。", "i will wait with you",
                                "安静停留。", "不重复追问。"),
                        approvedUtterance(row, "reaction_support", "other", 6,
                                "We can take a pause.", "我们先停一会儿。", "we can take a pause",
                                "做深呼吸动作。", "平静收束。")));
    }

    private PracticeGeneratedContentUtteranceEntity approvedUtterance(
            PracticeGeneratedContentEntity row,
            String role,
            String reaction,
            int displayOrder,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String tprActionZh,
            String deliveryGuidanceZh
    ) {
        var utterance = new PracticeGeneratedContentUtteranceEntity();
        utterance.setUtteranceId(row.generatedContentId() + "_" + displayOrder);
        utterance.setGeneratedContentId(row.generatedContentId());
        utterance.setRole(role);
        utterance.setReactionType(reaction);
        utterance.setEnglishText(englishText);
        utterance.setChineseText(chineseText);
        utterance.setPronunciationHint(pronunciationHint);
        utterance.setTprActionZh(tprActionZh);
        utterance.setDeliveryGuidanceZh(deliveryGuidanceZh);
        utterance.setDifficulty("starter");
        utterance.setDisplayOrder(displayOrder);
        utterance.setApprovalStatus("approved");
        utterance.setApprovedContentVersion(row.contentVersion());
        utterance.setBundleSchemaVersion("custom-scene-generated-output-v1");
        utterance.setProviderOrigin("provider_generated");
        utterance.setProviderName("test-provider");
        utterance.setProviderModelName("test-model");
        utterance.setProviderAttemptNumber(1);
        utterance.setCreatedAt(NOW_DB);
        return utterance;
    }

    private PracticeSpaceRow space(String spaceId, int sortOrder) {
        return new PracticeSpaceRow(
                sortOrder,
                spaceId,
                switch (spaceId) {
                    case "daily_care" -> "日常照护";
                    case "family_rhythm" -> "家庭节奏";
                    default -> "测试空间";
                },
                "description",
                sortOrder
        );
    }

    private PracticeActivityRow activity(
            String activityId,
            String spaceId,
            int sortOrder,
            String source
    ) {
        return new PracticeActivityRow(
                sortOrder,
                activityId,
                spaceId,
                switch (activityId) {
                    case "bath_time" -> "洗澡时间";
                    case "diaper_change" -> "换尿布";
                    case "bedtime_routine" -> "睡前流程";
                    default -> "测试活动";
                },
                switch (activityId) {
                    case "bath_time" -> "Bath time";
                    case "diaper_change" -> "Diaper change";
                    case "bedtime_routine" -> "Bedtime routine";
                    default -> "Test";
                },
                "coach tip",
                sortOrder,
                source
        );
    }

    private PracticePhraseRow phrase(
            String phraseId,
            String activityId,
            int step,
            String source
    ) {
        return new PracticePhraseRow(
                step,
                phraseId,
                activityId,
                step,
                switch (phraseId) {
                    case "bath_time_warm_water" -> "Warm water.";
                    case "diaper_change_clean_diaper" -> "Clean diaper.";
                    case "bedtime_good_night" -> "Good night.";
                    default -> "Hello.";
                },
                switch (phraseId) {
                    case "bath_time_warm_water" -> "水暖暖的。";
                    case "diaper_change_clean_diaper" -> "干净尿布。";
                    case "bedtime_good_night" -> "晚安。";
                    default -> "你好。";
                },
                "wɔːrm ˈwɔː.t̬ɚ",
                "starter",
                null,
                source
        );
    }

    private BabyProfileRow profile(String profileId, String ageRange, String parentGoal) {
        return new BabyProfileRow(
                profileId,
                "acct_1",
                "小满",
                ageRange,
                parentGoal,
                null,
                null,
                null,
                null,
                null,
                null,
                "draft",
                null,
                1,
                NOW_DB,
                NOW_DB
        );
    }
}
