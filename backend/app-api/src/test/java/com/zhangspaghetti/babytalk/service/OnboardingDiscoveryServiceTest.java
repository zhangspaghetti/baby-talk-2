package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.web.ContractException;
import com.zhangspaghetti.babytalk.service.PracticeCatalogRepository.StarterPhraseSourcePolicy;
import java.lang.reflect.Constructor;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class OnboardingDiscoveryServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-03T02:00:00Z");

    @Mock
    private PracticeCatalogRepository catalogRepository;

    @Mock
    private AuthConsentSyncService authConsentSyncService;

    @Mock
    private OnboardingProfileRepository onboardingProfileRepository;

    private OnboardingDiscoveryService service;

    @BeforeEach
    void setUp() {
        service = new OnboardingDiscoveryService(
                catalogRepository,
                authConsentSyncService,
                onboardingProfileRepository
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
        when(catalogRepository.findSpaces("zh-CN", 50)).thenReturn(List.of(space("family_rhythm", 2)));
        when(catalogRepository.findActivitiesBySpace("family_rhythm", "zh-CN", 50))
                .thenReturn(List.of(activity("bedtime_routine", "family_rhythm", 1, "seed")));
        when(catalogRepository.findStarterPhrase("bedtime_routine", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY))
                .thenReturn(Optional.of(phrase("bedtime_good_night", "bedtime_routine", 1, "seed")));

        var response = service.discover(draftRequest("calmer_care", 6), null);

        assertThat(response.starter().activityId()).isEqualTo("bedtime_routine");
        assertThat(response.trace().fallbackReason()).isEqualTo("fallback_first_catalog");
    }

    @Test
    void noDuplicateScenesMomentsOrStarters() {
        when(catalogRepository.findSpaces("zh-CN", 50))
                .thenReturn(List.of(space("daily_care", 1), space("daily_care", 1)));
        when(catalogRepository.findActivitiesBySpace("daily_care", "zh-CN", 50))
                .thenReturn(List.of(
                        activity("bath_time", "daily_care", 1, "seed"),
                        activity("bath_time", "daily_care", 1, "seed")));
        when(catalogRepository.findStarterPhrase("bath_time", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY))
                .thenReturn(Optional.of(phrase("bath_time_warm_water", "bath_time", 1, "seed")));

        var response = service.discover(draftRequest("calmer_care", 6), null);

        assertThat(response.scenes()).extracting(OnboardingDiscoveryService.SceneResponse::sceneId)
                .containsExactly("daily_care");
        assertThat(response.moments()).extracting(OnboardingDiscoveryService.MomentResponse::momentId)
                .containsExactly("bath_time");
        assertThat(response.moments().get(0).starterUtterances())
                .extracting(OnboardingDiscoveryService.StarterUtteranceResponse::phraseId)
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
        when(catalogRepository.findSpaces("zh-CN", 50)).thenReturn(List.of(space("daily_care", 1)));
        when(catalogRepository.findActivitiesBySpace("daily_care", "zh-CN", 50))
                .thenReturn(List.of(
                        activity("generated_activity", "daily_care", 1, "llm"),
                        activity("bath_time", "daily_care", 2, "seed")));
        when(catalogRepository.findStarterPhrase("bath_time", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY))
                .thenReturn(Optional.of(phrase("bath_time_warm_water", "bath_time", 1, "seed")));

        var response = service.discover(draftRequest("calmer_care", 6), null);

        assertThat(response.moments()).extracting(OnboardingDiscoveryService.MomentResponse::activityId)
                .containsExactly("bath_time");
        verify(catalogRepository, never()).findStarterPhrase("generated_activity", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY);
        verify(catalogRepository, never()).findStarterPhrase(any(), any());
    }

    @Test
    void seedStarterPhraseIsUsedWhenLlmStarterWouldShadowLegacyStarterLookup() {
        when(catalogRepository.findSpaces("zh-CN", 50)).thenReturn(List.of(space("daily_care", 1)));
        when(catalogRepository.findActivitiesBySpace("daily_care", "zh-CN", 50))
                .thenReturn(List.of(activity("bath_time", "daily_care", 1, "seed")));
        when(catalogRepository.findStarterPhrase("bath_time", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY))
                .thenReturn(Optional.of(phrase("bath_time_warm_water", "bath_time", 1, "seed")));

        var response = service.discover(draftRequest("calmer_care", 6), null);

        assertThat(response.starter().phraseId()).isEqualTo("bath_time_warm_water");
        assertThat(response.moments().get(0).starterUtterances().get(0).source()).isEqualTo("catalog");
        verify(catalogRepository).findStarterPhrase("bath_time", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY);
        verify(catalogRepository, never()).findStarterPhrase("bath_time", "zh-CN");
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
        assertThatThrownBy(() -> service.discover(new OnboardingDiscoveryService.OnboardingDiscoveryRequest(
                "catalog",
                null,
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
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
        assertThatThrownBy(() -> service.discover(new OnboardingDiscoveryService.OnboardingDiscoveryRequest(
                "catalog",
                "_bad",
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
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
        when(onboardingProfileRepository.findByAccountId("acct_1"))
                .thenReturn(Optional.of(profile("babyprof_1", "m18_23", "calmer_care")));

        var response = service.discover(new OnboardingDiscoveryService.OnboardingDiscoveryRequest(
                "catalog",
                "install_1",
                "babyprof_1",
                null,
                null,
                "zh-CN",
                6,
                null
        ), "sess_1");

        assertThat(response.profileMode()).isEqualTo("authenticated_profile");
        assertThat(response.starter().activityId()).isEqualTo("bath_time");
        verify(onboardingProfileRepository).findByAccountId("acct_1");
    }

    @Test
    void profileBackedDiscoverySucceedsWithoutInstallationId() {
        seedDefaultCatalog();
        when(authConsentSyncService.requireAcceptedConsumerSession("sess_1", "读取宝宝档案场景发现"))
                .thenReturn(new AuthConsentSyncService.ConsumerSessionView("acct_1", "sess_1", "install_1", "accepted"));
        when(onboardingProfileRepository.findByAccountId("acct_1"))
                .thenReturn(Optional.of(profile("babyprof_1", "m18_23", "calmer_care")));

        var response = service.discover(new OnboardingDiscoveryService.OnboardingDiscoveryRequest(
                "catalog",
                null,
                "babyprof_1",
                null,
                null,
                "zh-CN",
                6,
                null
        ), "sess_1");

        assertThat(response.profileMode()).isEqualTo("authenticated_profile");
        assertThat(response.starter().activityId()).isEqualTo("bath_time");
        verify(onboardingProfileRepository).findByAccountId("acct_1");
    }

    @Test
    void profileBackedDiscoveryRejectsUnsafeInstallationIdIfProvided() {
        assertThatThrownBy(() -> service.discover(new OnboardingDiscoveryService.OnboardingDiscoveryRequest(
                "catalog",
                "_bad",
                "babyprof_1",
                null,
                null,
                "zh-CN",
                6,
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
        assertThatThrownBy(() -> service.discover(new OnboardingDiscoveryService.OnboardingDiscoveryRequest(
                "catalog",
                null,
                "babyprof_1",
                null,
                null,
                "zh-CN",
                6,
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
        when(onboardingProfileRepository.findByAccountId("acct_1"))
                .thenReturn(Optional.of(profile("babyprof_1", null, "calmer_care")));

        assertThatThrownBy(() -> service.discover(new OnboardingDiscoveryService.OnboardingDiscoveryRequest(
                "catalog",
                "install_1",
                "babyprof_1",
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
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
        when(onboardingProfileRepository.findByAccountId("acct_1"))
                .thenReturn(Optional.of(profile("babyprof_1", "m7_11", null)));

        var response = service.discover(new OnboardingDiscoveryService.OnboardingDiscoveryRequest(
                "catalog",
                "install_1",
                "babyprof_1",
                null,
                "calmer_care",
                "zh-CN",
                6,
                null
        ), "sess_1");

        assertThat(response.profileMode()).isEqualTo("authenticated_profile");
        assertThat(response.starter().source()).isEqualTo("catalog");
    }

    @Test
    void requestAgeOrGoalCannotSilentlyOverrideSavedValues() {
        when(authConsentSyncService.requireAcceptedConsumerSession("sess_1", "读取宝宝档案场景发现"))
                .thenReturn(new AuthConsentSyncService.ConsumerSessionView("acct_1", "sess_1", "install_1", "accepted"));
        when(onboardingProfileRepository.findByAccountId("acct_1"))
                .thenReturn(Optional.of(profile("babyprof_1", "m18_23", "calmer_care")));

        assertThatThrownBy(() -> service.discover(new OnboardingDiscoveryService.OnboardingDiscoveryRequest(
                "catalog",
                "install_1",
                "babyprof_1",
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
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
    void customSceneNotImplementedInB2() {
        assertThatThrownBy(() -> service.discover(new OnboardingDiscoveryService.OnboardingDiscoveryRequest(
                "custom_scene",
                "install_1",
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                6,
                null
        ), null))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.NOT_IMPLEMENTED);
                    assertThat(contract.code()).isEqualTo("custom_scene_not_implemented");
                    assertThat(contract.details()).containsEntry("supportedModes", List.of("catalog"));
                });
    }

    @Test
    void serviceConstructorDoesNotDependOnAiOrMentorTypes() {
        assertThat(List.of(OnboardingDiscoveryService.class.getDeclaredConstructors()).stream()
                .map(Constructor::getParameterTypes)
                .flatMap(Arrays::stream)
                .toList())
                .extracting(Class::getName)
                .noneMatch(name -> name.contains("Mentor")
                        || name.contains("SpringAi")
                        || name.contains("PalaceSearch")
                        || name.contains("PracticeGenerate"));
    }

    private void seedDefaultCatalog() {
        when(catalogRepository.findSpaces("zh-CN", 50)).thenReturn(List.of(
                space("daily_care", 1),
                space("family_rhythm", 2)
        ));
        when(catalogRepository.findActivitiesBySpace("daily_care", "zh-CN", 50)).thenReturn(List.of(
                activity("bath_time", "daily_care", 1, "seed"),
                activity("diaper_change", "daily_care", 2, "seed")
        ));
        when(catalogRepository.findActivitiesBySpace("family_rhythm", "zh-CN", 50))
                .thenReturn(List.of(activity("bedtime_routine", "family_rhythm", 1, "seed")));
        when(catalogRepository.findStarterPhrase("bath_time", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY))
                .thenReturn(Optional.of(phrase("bath_time_warm_water", "bath_time", 1, "seed")));
        when(catalogRepository.findStarterPhrase("diaper_change", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY))
                .thenReturn(Optional.of(phrase("diaper_change_clean_diaper", "diaper_change", 1, "seed")));
        when(catalogRepository.findStarterPhrase("bedtime_routine", "zh-CN", StarterPhraseSourcePolicy.SEED_ONLY))
                .thenReturn(Optional.of(phrase("bedtime_good_night", "bedtime_routine", 1, "seed")));
    }

    private OnboardingDiscoveryService.OnboardingDiscoveryRequest draftRequest(String parentGoal, Integer limit) {
        return new OnboardingDiscoveryService.OnboardingDiscoveryRequest(
                "catalog",
                "install_1",
                null,
                "m7_11",
                parentGoal,
                "zh-CN",
                limit,
                "trace_1"
        );
    }

    private PracticeCatalogRepository.PracticeSpaceRow space(String spaceId, int sortOrder) {
        return new PracticeCatalogRepository.PracticeSpaceRow(
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

    private PracticeCatalogRepository.PracticeActivityRow activity(
            String activityId,
            String spaceId,
            int sortOrder,
            String source
    ) {
        return new PracticeCatalogRepository.PracticeActivityRow(
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

    private PracticeCatalogRepository.PracticePhraseRow phrase(
            String phraseId,
            String activityId,
            int step,
            String source
    ) {
        return new PracticeCatalogRepository.PracticePhraseRow(
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

    private OnboardingProfileRepository.ProfileRow profile(String profileId, String ageRange, String parentGoal) {
        return new OnboardingProfileRepository.ProfileRow(
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
                NOW,
                NOW
        );
    }
}
