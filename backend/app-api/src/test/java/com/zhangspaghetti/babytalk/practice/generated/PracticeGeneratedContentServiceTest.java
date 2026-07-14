package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGeneratedContentValidator;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGenerationService;
import com.zhangspaghetti.babytalk.practice.discovery.FakeCustomSceneGenerationService;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryCustomSceneProperties;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyProperties;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyTestFixture;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.lang.reflect.Modifier;
import java.util.Arrays;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class PracticeGeneratedContentServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-03T05:00:00Z");
    private static final OffsetDateTime NOW_DB = OffsetDateTime.ofInstant(NOW, ZoneOffset.UTC);
    private static final Clock CLOCK = Clock.fixed(NOW, ZoneOffset.UTC);

    @Mock
    private PracticeGeneratedContentMapper mapper;

    @Test
    void writeServiceIsRequiredAndNonAtomicDirectFallbackDoesNotExist() throws Exception {
        assertThat(Arrays.stream(PracticeGeneratedContentService.class.getDeclaredConstructors())
                .filter(constructor -> Modifier.isPublic(constructor.getModifiers()))
                .flatMap(constructor -> Arrays.stream(constructor.getParameterTypes())))
                .contains(PracticeGeneratedContentWriteService.class);
        assertThat(Modifier.isFinal(PracticeGeneratedContentService.class
                .getDeclaredField("writeService")
                .getModifiers())).isTrue();
        assertThat(Arrays.stream(PracticeGeneratedContentService.class.getDeclaredMethods())
                .map(method -> method.getName()))
                .doesNotContain("setWriteService", "reserveDraftDirect");
    }

    @Test
    void fakeGeneratorSuccessActivatesDraftAndReturnsPersistedRow() {
        var service = serviceWithFakeProvider();
        stubReserveInserted();
        stubActivateDraft();

        var row = service.generateCustomScene(request("洗澡后哄睡"));

        assertThat(row.status()).isEqualTo("active");
        assertThat(row.spaceSlug()).startsWith("gen_scene_");
        assertThat(row.activitySlug()).startsWith("gen_activity_");
        assertThat(row.phraseSlug()).startsWith("gen_phrase_");
        assertThat(row.englishText()).isEqualTo("Sleepy baby.");
        assertThat(row.chineseText()).isEqualTo("宝宝困了。");
        assertThat(row.generationSource()).isEqualTo("fake");
        assertThat(row.createdAt()).isInstanceOf(java.time.OffsetDateTime.class);
        assertThat(row.normalizedSceneText()).isNull();
        assertThat(row.retentionExpiresAt()).isEqualTo(NOW_DB.plusDays(30));
        verify(mapper).activateDraft(any());
    }

    @Test
    void providerReceivesOnlyCanonicalSceneText() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        when(generator.generateCustomSceneStarter(any())).thenReturn(shoesCandidate());
        var service = serviceWithGenerator(generator);
        stubReserveInserted();
        stubActivateDraft();
        var requestCaptor = ArgumentCaptor.forClass(CustomSceneGenerationService.CustomSceneGenerationRequest.class);

        service.generateCustomScene(request("  宝宝　不肯\n穿鞋  "));

        verify(generator).generateCustomSceneStarter(requestCaptor.capture());
        assertThat(requestCaptor.getValue().canonicalSceneText()).isEqualTo("宝宝 不肯 穿鞋");
        var componentNames = Arrays.stream(requestCaptor.getValue().getClass().getRecordComponents())
                .map(java.lang.reflect.RecordComponent::getName)
                .toList();
        assertThat(componentNames).doesNotContain("customSceneText");
    }

    @Test
    void canonicalEquivalentSceneInputsReuseOneFingerprint() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        var generatorCalls = new java.util.concurrent.atomic.AtomicInteger();
        when(generator.generateCustomSceneStarter(any())).thenAnswer(invocation -> {
            generatorCalls.incrementAndGet();
            return candidate();
        });
        var service = serviceWithGenerator(generator);
        var active = new java.util.concurrent.atomic.AtomicReference<PracticeGeneratedContentEntity>();
        when(mapper.findLiveByFingerprint(any(), any(), any(), any(), any(), any(), any(), any()))
                .thenAnswer(invocation -> active.get());
        when(mapper.insertDraftIgnoringLiveConflict(any()))
                .thenAnswer(invocation -> invocation.getArgument(0));
        when(mapper.activateDraft(any())).thenAnswer(invocation -> {
            active.set(invocation.getArgument(0));
            return 1;
        });
        when(mapper.findActiveOrPromotedByGeneratedContentId(any(), any(), any()))
                .thenAnswer(invocation -> active.get());

        var first = service.generateCustomScene(request("洗澡  后哄睡"));
        var second = service.generateCustomScene(request("洗澡　后哄睡"));

        assertThat(second.generatedContentId()).isEqualTo(first.generatedContentId());
        assertThat(generatorCalls.get()).isEqualTo(1);
    }

    @Test
    void sameSceneForDifferentOwnersDoesNotShareFingerprint() {
        var service = serviceWithFakeProvider();
        stubReserveInserted();
        stubActivateDraft();

        var first = service.generateCustomScene(requestForInstallation("install-a", "宝宝不肯穿鞋"));
        var second = service.generateCustomScene(requestForInstallation("install-b", "宝宝不肯穿鞋"));

        assertThat(second.requestFingerprint()).isNotEqualTo(first.requestFingerprint());
    }

    @org.junit.jupiter.params.ParameterizedTest
    @org.junit.jupiter.params.provider.ValueSource(strings = {
            "给宝宝剪指甲时总是乱动",
            "擦鼻涕时宝宝一直躲",
            "上安全座椅时宝宝哭",
            "给宝宝涂防晒",
            "量体温时宝宝不肯配合",
            "洗手时宝宝一直玩水"
    })
    void acceptsSafeUnlistedCareScenesBeforeProviderSelection(String sceneText) {
        var service = serviceWithFakeProvider();
        stubReserveInserted();

        var exception = org.junit.jupiter.api.Assertions.assertThrows(ContractException.class,
                () -> service.generateCustomScene(request(sceneText)));

        assertThat(exception.code()).isEqualTo("generation_unavailable");
        assertThat(exception.details()).containsEntry("reason", "fake_scene_not_supported");
        assertThat(exception.details()).doesNotContainEntry("reason", "non_caregiving_scene");
    }

    @Test
    void rejectsClearlyUnsupportedNonCareRequest() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        var service = serviceWithGenerator(generator);

        var exception = org.junit.jupiter.api.Assertions.assertThrows(ContractException.class,
                () -> service.generateCustomScene(request("帮我完成编程作业和考试答案")));

        assertThat(exception.code()).isEqualTo("unsupported_custom_scene_text");
        verifyNoInteractions(generator);
    }

    @Test
    void existingActiveRowReturnsWithoutGeneratorCall() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        var service = serviceWithGenerator(generator);
        var active = activeRow("pgc_existing_active", "洗澡后哄睡");
        stubReserveExisting(active);

        var row = service.generateCustomScene(request("洗澡后哄睡"));

        assertThat(row.generatedContentId()).isEqualTo("pgc_existing_active");
        verify(generator, never()).generateCustomSceneStarter(any());
        verify(mapper, never()).countRecentGenerationAttempts(any(), any(), any(), any(), any());
        verify(mapper, never()).activateDraft(any());
    }

    @Test
    void existingDraftReturnsGenerationInProgressWithoutGeneratorCall() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        var service = serviceWithGenerator(generator);
        stubReserveExistingDraft();

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.CONFLICT);
                    assertThat(contract.code()).isEqualTo("generation_in_progress");
                });
        verify(generator, never()).generateCustomSceneStarter(any());
        verify(mapper, never()).countRecentGenerationAttempts(any(), any(), any(), any(), any());
        verify(mapper, never()).activateDraft(any());
    }

    @Test
    void unsafeGeneratedOutputRejectedAndNeverActivated() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        when(generator.generateCustomSceneStarter(any())).thenReturn(unsafeCandidate());
        var service = serviceWithGenerator(generator);
        stubReserveInserted();

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY);
                    assertThat(contract.code()).isEqualTo("generated_content_rejected");
                });
        verify(mapper).rejectDraft(any(), org.mockito.Mockito.eq("generated_content_rejected"), any(), any());
        verify(mapper, never()).activateDraft(any());
    }

    @Test
    void disabledProviderReturns503AndFallbackHint() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        var service = serviceWithPropertiesAndGenerator(properties(
                PracticeDiscoveryCustomSceneProperties.DEFAULT_PROMPT_VERSION,
                PracticeDiscoveryCustomSceneProperties.DEFAULT_STRATEGY_VERSION,
                "disabled"
        ), generator);

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                    assertThat(contract.code()).isEqualTo("generation_unavailable");
                    assertThat(contract.details()).containsEntry("retryable", false);
                    assertThat(contract.details()).containsEntry("suggestCatalogFallback", true);
                    assertThat(contract.details()).containsEntry("reason", "provider_disabled");
                });
        verifyNoInteractions(mapper, generator);
    }

    @Test
    void agenticPlaceholderReturnsNonRetryableBeforeReservation() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        var service = serviceWithPropertiesAndGenerator(properties(
                PracticeDiscoveryCustomSceneProperties.DEFAULT_PROMPT_VERSION,
                PracticeDiscoveryCustomSceneProperties.DEFAULT_STRATEGY_VERSION,
                "agentic"
        ), generator);

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.code()).isEqualTo("generation_unavailable");
                    assertThat(contract.details())
                            .containsEntry("retryable", false)
                            .containsEntry("reason", "agentic_not_implemented");
                });
        verifyNoInteractions(mapper, generator);
    }

    @Test
    void defaultDisabledFeatureFlagReturns503WithoutNetworkProvider() {
        var properties = new PracticeDiscoveryCustomSceneProperties(
                false,
                Duration.ofSeconds(5),
                null,
                null,
                "fake",
                null,
                null,
                null,
                null,
                null,
                null
        );
        var service = new PracticeGeneratedContentService(
                mapper,
                new PracticeGeneratedContentWriteService(mapper),
                new FakeCustomSceneGenerationService(properties),
                validator(),
                properties,
                PracticeDiscoveryPolicyTestFixture.properties(),
                CLOCK,
                ownerProperties("test-owner-key-secret-test-owner-key")
        );

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                    assertThat(contract.code()).isEqualTo("generation_unavailable");
                    assertThat(contract.details()).containsEntry("retryable", false);
                    assertThat(contract.details()).containsEntry("suggestCatalogFallback", true);
                    assertThat(contract.details()).containsEntry("reason", "provider_disabled");
                });
        verify(mapper, never()).insertDraftIgnoringLiveConflict(any());
        verify(mapper, never()).rejectDraft(any(), org.mockito.Mockito.eq("provider_disabled"), any(), any());
        verify(mapper, never()).countRecentGenerationAttempts(any(), any(), any(), any(), any());
        verify(mapper, never()).activateDraft(any());
    }

    @Test
    void timeoutReturns504AndFallbackHint() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        when(generator.generateCustomSceneStarter(any()))
                .thenThrow(new CustomSceneGenerationService.GenerationTimeoutException(Duration.ofSeconds(5)));
        var service = serviceWithGenerator(generator);
        stubReserveInserted();

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.GATEWAY_TIMEOUT);
                    assertThat(contract.code()).isEqualTo("generation_timeout");
                    assertThat(contract.details()).containsEntry("retryable", true);
                    assertThat(contract.details()).containsEntry("suggestCatalogFallback", true);
                });
        verify(mapper).expireDraft(any(), org.mockito.Mockito.eq("generation_timeout"), any(), any());
        verify(mapper, never()).activateDraft(any());
    }

    @Test
    void transientProviderUnavailableExpiresDraftAndReturnsRetryable() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        when(generator.generateCustomSceneStarter(any()))
                .thenThrow(new CustomSceneGenerationService.GenerationUnavailableException(
                        CustomSceneGenerationService.GenerationUnavailableReason.PROVIDER_UNAVAILABLE));
        var service = serviceWithGenerator(generator);
        stubReserveInserted();

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.code()).isEqualTo("generation_unavailable");
                    assertThat(contract.details())
                            .containsEntry("retryable", true)
                            .containsEntry("reason", "provider_unavailable");
                });
        verify(mapper).expireDraft(any(), org.mockito.Mockito.eq("provider_unavailable"), any(), any());
        verify(mapper, never()).rejectDraft(any(), any(), any(), any());
    }

    @Test
    void unexpectedProviderRuntimeExpiresDraftAndReturnsSanitizedRetryableUnavailable() {
        var providerFailure = new RuntimeException("sdk leaked provider payload");
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        when(generator.generateCustomSceneStarter(any())).thenThrow(providerFailure);
        var service = serviceWithGenerator(generator);
        stubReserveInserted();

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                    assertThat(contract.code()).isEqualTo("generation_unavailable");
                    assertThat(contract.details())
                            .containsEntry("retryable", true)
                            .containsEntry("reason", "provider_failure");
                    assertThat(contract.getMessage()).doesNotContain("sdk leaked", "洗澡后哄睡");
                    assertThat(contract.getCause()).isSameAs(providerFailure);
                });
        verify(mapper).expireDraft(any(), org.mockito.Mockito.eq("provider_failure"), any(), any());
        verify(mapper, never()).activateDraft(any());
    }

    @Test
    void unexpectedActivationRuntimeExpiresDraftAndReturnsSanitizedRetryableUnavailable() {
        var activationFailure = new RuntimeException("database activation internals");
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        when(generator.generateCustomSceneStarter(any())).thenReturn(candidate());
        when(mapper.activateDraft(any())).thenThrow(activationFailure);
        var service = serviceWithGenerator(generator);
        stubReserveInserted();

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.code()).isEqualTo("generation_unavailable");
                    assertThat(contract.details())
                            .containsEntry("retryable", true)
                            .containsEntry("reason", "activation_failure");
                    assertThat(contract.getMessage()).doesNotContain("database activation internals", "洗澡后哄睡");
                    assertThat(contract.getCause()).isSameAs(activationFailure);
                });
        verify(mapper).expireDraft(any(), org.mockito.Mockito.eq("activation_failure"), any(), any());
    }

    @Test
    void cleanupFailureDoesNotMaskOriginalProviderFailure() {
        var providerFailure = new RuntimeException("original provider failure");
        var cleanupFailure = new RuntimeException("cleanup storage failure");
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        when(generator.generateCustomSceneStarter(any())).thenThrow(providerFailure);
        when(mapper.expireDraft(any(), any(), any(), any())).thenThrow(cleanupFailure);
        var service = serviceWithGenerator(generator);
        stubReserveInserted();

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    assertThat(error.getCause()).isSameAs(providerFailure);
                    assertThat(providerFailure.getSuppressed()).containsExactly(cleanupFailure);
                    assertThat(error.getMessage()).doesNotContain("original provider", "cleanup storage", "洗澡后哄睡");
                });
    }

    @Test
    void timeoutCleanupFailureDoesNotMaskTimeoutContract() {
        var timeout = new CustomSceneGenerationService.GenerationTimeoutException(Duration.ofSeconds(5));
        var cleanupFailure = new RuntimeException("cleanup storage failure");
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        when(generator.generateCustomSceneStarter(any())).thenThrow(timeout);
        when(mapper.expireDraft(any(), any(), any(), any())).thenThrow(cleanupFailure);
        var service = serviceWithGenerator(generator);
        stubReserveInserted();

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.code()).isEqualTo("generation_timeout");
                    assertThat(contract.getCause()).isSameAs(timeout);
                    assertThat(timeout.getSuppressed()).containsExactly(cleanupFailure);
                });
    }

    @Test
    void unavailableCleanupFailureDoesNotMaskRetryableContract() {
        var unavailable = new CustomSceneGenerationService.GenerationUnavailableException(
                CustomSceneGenerationService.GenerationUnavailableReason.PROVIDER_UNAVAILABLE);
        var cleanupFailure = new RuntimeException("cleanup storage failure");
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        when(generator.generateCustomSceneStarter(any())).thenThrow(unavailable);
        when(mapper.expireDraft(any(), any(), any(), any())).thenThrow(cleanupFailure);
        var service = serviceWithGenerator(generator);
        stubReserveInserted();

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.code()).isEqualTo("generation_unavailable");
                    assertThat(contract.details()).containsEntry("retryable", true);
                    assertThat(contract.getCause()).isSameAs(unavailable);
                    assertThat(unavailable.getSuppressed()).containsExactly(cleanupFailure);
                });
    }

    @Test
    void rejectedOutputCleanupFailureDoesNotMaskStableContract() {
        var cleanupFailure = new RuntimeException("cleanup storage failure");
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        when(generator.generateCustomSceneStarter(any())).thenReturn(unsafeCandidate());
        when(mapper.rejectDraft(any(), any(), any(), any())).thenThrow(cleanupFailure);
        var service = serviceWithGenerator(generator);
        stubReserveInserted();

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.code()).isEqualTo("generated_content_rejected");
                    assertThat(contract.getCause())
                            .isInstanceOf(CustomSceneGeneratedContentValidator.RejectedGeneratedContentException.class);
                    assertThat(contract.getCause().getSuppressed()).containsExactly(cleanupFailure);
                });
    }

    @Test
    void invalidOutputCleanupFailureDoesNotMaskStableContract() {
        var cleanupFailure = new RuntimeException("cleanup storage failure");
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        when(generator.generateCustomSceneStarter(any())).thenReturn(invalidCandidate());
        when(mapper.rejectDraft(any(), any(), any(), any())).thenThrow(cleanupFailure);
        var service = serviceWithGenerator(generator);
        stubReserveInserted();

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.code()).isEqualTo("generation_invalid_output");
                    assertThat(contract.getCause())
                            .isInstanceOf(CustomSceneGeneratedContentValidator.InvalidGeneratedContentException.class);
                    assertThat(contract.getCause().getSuppressed()).containsExactly(cleanupFailure);
                });
    }

    @Test
    void timeoutCapIsPassedToTypedGeneratorRequest() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        var properties = new PracticeDiscoveryCustomSceneProperties(
                true,
                Duration.ofSeconds(5),
                null,
                null,
                "fake",
                null,
                null,
                null,
                null,
                null,
                null
        );
        var service = new PracticeGeneratedContentService(
                mapper,
                new PracticeGeneratedContentWriteService(mapper),
                generator,
                validator(),
                properties,
                PracticeDiscoveryPolicyTestFixture.properties(),
                CLOCK,
                ownerProperties("test-owner-key-secret-test-owner-key")
        );
        stubReserveInserted();
        when(generator.generateCustomSceneStarter(any()))
                .thenThrow(new CustomSceneGenerationService.GenerationTimeoutException(properties.timeout()));
        var requestCaptor = ArgumentCaptor.forClass(CustomSceneGenerationService.CustomSceneGenerationRequest.class);

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> assertThat(((ContractException) error).code()).isEqualTo("generation_timeout"));

        verify(generator).generateCustomSceneStarter(requestCaptor.capture());
        assertThat(requestCaptor.getValue().timeout()).isEqualTo(Duration.ofSeconds(5));
        verify(mapper).expireDraft(any(), org.mockito.Mockito.eq("generation_timeout"), any(), any());
    }

    @Test
    void timeoutLongerThanFiveSecondsIsRejectedByProperties() {
        assertThatThrownBy(() -> new PracticeDiscoveryCustomSceneProperties(
                true,
                Duration.ofSeconds(6),
                null,
                null,
                "fake",
                null,
                null,
                null,
                null,
                null,
                null
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("must not exceed PT5S");
    }

    @Test
    void invalidGeneratedOutputReturns502() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        when(generator.generateCustomSceneStarter(any())).thenReturn(invalidCandidate());
        var service = serviceWithGenerator(generator);
        stubReserveInserted();

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_GATEWAY);
                    assertThat(contract.code()).isEqualTo("generation_invalid_output");
                });
        verify(mapper).rejectDraft(any(), org.mockito.Mockito.eq("generation_invalid_output"), any(), any());
        verify(mapper, never()).activateDraft(any());
    }

    @Test
    void unexpectedValidationRuntimeExpiresDraftAndReturnsSanitizedUnavailable() {
        var validationFailure = new RuntimeException("validator candidate payload");
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        when(generator.generateCustomSceneStarter(any())).thenReturn(candidate());
        var validator = org.mockito.Mockito.mock(CustomSceneGeneratedContentValidator.class);
        when(validator.normalizeAndValidate(any(), any(), any())).thenThrow(validationFailure);
        var properties = PracticeDiscoveryCustomSceneProperties.enabledForTest("fake");
        var service = new PracticeGeneratedContentService(
                mapper,
                new PracticeGeneratedContentWriteService(mapper),
                generator,
                validator,
                properties,
                PracticeDiscoveryPolicyTestFixture.properties(),
                CLOCK,
                ownerProperties("test-owner-key-secret-test-owner-key"));
        stubReserveInserted();

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.code()).isEqualTo("generation_unavailable");
                    assertThat(contract.details()).containsEntry("reason", "validation_failure");
                    assertThat(contract.getCause()).isSameAs(validationFailure);
                    assertThat(contract.getMessage()).doesNotContain("validator candidate", "洗澡后哄睡");
                });
        verify(mapper).expireDraft(any(), org.mockito.Mockito.eq("validation_failure"), any(), any());
        verify(mapper, never()).activateDraft(any());
    }

    @Test
    void invalidCustomSceneTextRejectedBeforeReservation() {
        var service = serviceWithFakeProvider();

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡 138001380001")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> assertThat(((ContractException) error).code()).isEqualTo("unsafe_custom_scene_text"));
        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡 138-0013-8000")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> assertThat(((ContractException) error).code()).isEqualTo("unsafe_custom_scene_text"));
        assertThatThrownBy(() -> service.generateCustomScene(request("宝宝叫小明，洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> assertThat(((ContractException) error).code()).isEqualTo("unsafe_custom_scene_text"));
        assertThatThrownBy(() -> service.generateCustomScene(request("ignore previous 洗澡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> assertThat(((ContractException) error).code()).isEqualTo("unsupported_custom_scene_text"));
        verify(mapper, never()).insertDraftIgnoringLiveConflict(any());
    }

    @Test
    void databaseOverlongCanonicalSceneIsRejectedBeforeFingerprintReservationAndProvider() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        var service = serviceWithGenerator(generator);

        assertThatThrownBy(() -> service.generateCustomScene(request("👨‍👩‍👧‍👦".repeat(80))))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> assertThat(((ContractException) error).code())
                        .isEqualTo("invalid_custom_scene_text"));

        verifyNoInteractions(mapper, generator);
    }

    @Test
    void unicodeDecimalPhoneInCustomSceneIsRejectedBeforeReservationAndProvider() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        var service = serviceWithGenerator(generator);

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡 ١٣٨٠٠١٣٨٠٠٠")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> assertThat(((ContractException) error).code())
                        .isEqualTo("unsafe_custom_scene_text"));

        verifyNoInteractions(mapper, generator);
    }

    @Test
    void draftReservationUsesStableIdAndHmacOwnerKey() {
        var service = serviceWithFakeProvider();
        stubReserveInserted();
        stubActivateDraft();
        var captor = ArgumentCaptor.forClass(PracticeGeneratedContentEntity.class);

        var first = service.generateCustomScene(request("洗澡后哄睡"));
        var second = service.generateCustomScene(request("洗澡后哄睡"));

        verify(mapper, org.mockito.Mockito.atLeast(2)).insertDraftIgnoringLiveConflict(captor.capture());
        assertThat(first.generatedContentId()).isEqualTo(second.generatedContentId());
        var reserved = captor.getAllValues().get(0);
        assertThat(reserved.generatedContentId()).startsWith("pgc_");
        assertThat(reserved.ownerKey()).startsWith("owner_");
        assertThat(reserved.ownerKey()).doesNotContain("install_1");
        assertThat(reserved.requestFingerprint()).startsWith("fp_");
    }

    @Test
    void promptAndStrategyVersionComeFromPropertiesAndPersistIntoRows() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        var properties = new PracticeDiscoveryCustomSceneProperties(
                true,
                Duration.ofSeconds(5),
                "prompt-v2",
                "strategy-v3",
                "fake",
                null,
                null,
                null,
                null,
                null,
                null
        );
        var service = new PracticeGeneratedContentService(
                mapper,
                new PracticeGeneratedContentWriteService(mapper),
                generator,
                validator(),
                properties,
                PracticeDiscoveryPolicyTestFixture.properties(),
                CLOCK,
                ownerProperties("test-owner-key-secret-test-owner-key")
        );
        stubReserveInserted();
        stubActivateDraft();
        when(generator.generateCustomSceneStarter(any())).thenReturn(candidate());
        var draftCaptor = ArgumentCaptor.forClass(PracticeGeneratedContentEntity.class);
        var requestCaptor = ArgumentCaptor.forClass(CustomSceneGenerationService.CustomSceneGenerationRequest.class);
        var activeCaptor = ArgumentCaptor.forClass(PracticeGeneratedContentEntity.class);

        var row = service.generateCustomScene(request("洗澡后哄睡"));

        verify(mapper).insertDraftIgnoringLiveConflict(draftCaptor.capture());
        verify(generator).generateCustomSceneStarter(requestCaptor.capture());
        verify(mapper).activateDraft(activeCaptor.capture());
        assertThat(draftCaptor.getValue().promptVersion()).isEqualTo("prompt-v2");
        assertThat(draftCaptor.getValue().strategyVersion()).isEqualTo("strategy-v3");
        assertThat(requestCaptor.getValue().promptVersion()).isEqualTo("prompt-v2");
        assertThat(requestCaptor.getValue().strategyVersion()).isEqualTo("strategy-v3");
        assertThat(activeCaptor.getValue().promptVersion()).isEqualTo("prompt-v2");
        assertThat(activeCaptor.getValue().strategyVersion()).isEqualTo("strategy-v3");
        assertThat(row.promptVersion()).isEqualTo("prompt-v2");
        assertThat(row.strategyVersion()).isEqualTo("strategy-v3");
    }

    @Test
    void promptAndStrategyVersionParticipateInFingerprintAndIdempotentId() {
        var serviceV1 = serviceWithProperties(properties("prompt-v1", "strategy-v1", "fake"));
        var serviceV2 = serviceWithProperties(properties("prompt-v2", "strategy-v1", "fake"));
        stubReserveInserted();
        stubActivateDraft();
        var captor = ArgumentCaptor.forClass(PracticeGeneratedContentEntity.class);

        serviceV1.generateCustomScene(request("洗澡后哄睡"));
        serviceV2.generateCustomScene(request("洗澡后哄睡"));

        verify(mapper, org.mockito.Mockito.times(2)).insertDraftIgnoringLiveConflict(captor.capture());
        var first = captor.getAllValues().get(0);
        var second = captor.getAllValues().get(1);
        assertThat(first.promptVersion()).isEqualTo("prompt-v1");
        assertThat(second.promptVersion()).isEqualTo("prompt-v2");
        assertThat(first.requestFingerprint()).isNotEqualTo(second.requestFingerprint());
        assertThat(first.generatedContentId()).isNotEqualTo(second.generatedContentId());
    }

    @Test
    void generatedSlugsDoNotExposeCustomSceneText() {
        var service = serviceWithFakeProvider();
        stubReserveInserted();
        stubActivateDraft();
        var captor = ArgumentCaptor.forClass(PracticeGeneratedContentEntity.class);

        service.generateCustomScene(request("洗澡后哄睡"));

        verify(mapper).activateDraft(captor.capture());
        var activated = captor.getValue();
        assertThat(activated.spaceSlug()).doesNotContain("洗澡", "哄睡");
        assertThat(activated.activitySlug()).doesNotContain("洗澡", "哄睡");
        assertThat(activated.phraseSlug()).doesNotContain("洗澡", "哄睡");
        assertThat(activated.spaceSlug()).startsWith("gen_scene_");
        assertThat(activated.activitySlug()).startsWith("gen_activity_");
        assertThat(activated.phraseSlug()).startsWith("gen_phrase_");
    }

    @Test
    void inactiveGeneratedContentIdConflictRetriesWithSuffix() {
        var service = serviceWithFakeProvider();
        when(mapper.insertDraftIgnoringLiveConflict(any()))
                .thenThrow(new DuplicateKeyException("inactive primary key"))
                .thenAnswer(invocation -> invocation.getArgument(0));
        stubActivateDraft();
        var captor = ArgumentCaptor.forClass(PracticeGeneratedContentEntity.class);

        var row = service.generateCustomScene(request("洗澡后哄睡"));

        verify(mapper, org.mockito.Mockito.times(2)).insertDraftIgnoringLiveConflict(captor.capture());
        assertThat(captor.getAllValues().get(1).generatedContentId()).contains("_");
        assertThat(row.status()).isEqualTo("active");
    }

    @Test
    void expiredExistingDraftIsExpiredThenRetriedWithoutGeneratorCallForTheOldDraft() {
        var service = serviceWithFakeProvider();
        var expired = expiredDraft(draftRow("pgc_expired_draft"));
        when(mapper.insertDraftIgnoringLiveConflict(any()))
                .thenAnswer(invocation -> invocation.getArgument(0));
        when(mapper.findLiveByFingerprint(any(), any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(expired);
        stubActivateDraft();

        var row = service.generateCustomScene(request("洗澡后哄睡"));

        verify(mapper).expireDraft(any(), org.mockito.Mockito.eq("draft_expired"), any(), any());
        assertThat(row.status()).isEqualTo("active");
    }

    @Test
    void rateLimitedExpiredDraftDoesNotWriteCleanupBeforeRejection() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        var service = serviceWithGenerator(generator);
        when(mapper.findLiveByFingerprint(any(), any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(expiredDraft(draftRow("pgc_expired_rate_limited")));
        when(mapper.countRecentGenerationAttempts(any(), any(), any(), any(), any())).thenReturn(3);

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> assertThat(((ContractException) error).code())
                        .isEqualTo("custom_scene_rate_limited"));

        verify(mapper, never()).expireDraft(any(), any(), any(), any());
        verify(mapper, never()).insertDraftIgnoringLiveConflict(any());
        verifyNoInteractions(generator);
    }

    @Test
    void installationBurstRateLimitDoesNotReserveDraftOrCallGenerator() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        var service = serviceWithGenerator(generator);
        when(mapper.countRecentGenerationAttempts(any(), any(), any(), any(), any())).thenReturn(4);

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                    assertThat(contract.code()).isEqualTo("custom_scene_rate_limited");
                    assertThat(contract.details()).containsEntry("scope", "installation");
                    assertThat(contract.details()).containsEntry("limit", 3);
                    assertThat(contract.details()).containsEntry("window", "burst");
                    assertThat(contract.details()).containsEntry("windowSeconds", 600L);
                    assertThat(contract.details()).containsEntry("retryAfterSeconds", 600L);
                    assertThat(contract.details().toString())
                            .doesNotContain("owner_")
                            .doesNotContain("install_1")
                            .doesNotContain("洗澡后哄睡");
                });
        verify(mapper, never()).insertDraftIgnoringLiveConflict(any());
        verify(mapper, never()).expireDraft(any(), org.mockito.Mockito.eq("rate_limited"), any(), any());
        verify(generator, never()).generateCustomSceneStarter(any());
        verify(mapper, never()).activateDraft(any());
    }

    @Test
    void installationDailyRateLimitUsesDailyCapAfterBurstPasses() {
        var service = serviceWithFakeProvider();
        when(mapper.countRecentGenerationAttempts(any(), any(), any(), any(), any()))
                .thenReturn(1, 11);

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                    assertThat(contract.code()).isEqualTo("custom_scene_rate_limited");
                    assertThat(contract.details()).containsEntry("scope", "installation");
                    assertThat(contract.details()).containsEntry("limit", 10);
                    assertThat(contract.details()).containsEntry("window", "daily");
                    assertThat(contract.details()).containsEntry("windowSeconds", 86_400L);
                    assertThat(contract.details()).containsEntry("retryAfterSeconds", 86_400L);
                });
        verify(mapper, never()).insertDraftIgnoringLiveConflict(any());
        verify(mapper, never()).expireDraft(any(), org.mockito.Mockito.eq("rate_limited"), any(), any());
        verify(mapper, never()).activateDraft(any());
    }

    @Test
    void accountOwnerUsesLargerBurstCapThanInstallation() {
        var service = serviceWithFakeProvider();
        when(mapper.countRecentGenerationAttempts(any(), any(), any(), any(), any())).thenReturn(6);

        assertThatThrownBy(() -> service.generateCustomScene(accountRequest("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                    assertThat(contract.code()).isEqualTo("custom_scene_rate_limited");
                    assertThat(contract.details()).containsEntry("scope", "account");
                    assertThat(contract.details()).containsEntry("limit", 5);
                    assertThat(contract.details()).containsEntry("window", "burst");
                });
        verify(mapper, never()).insertDraftIgnoringLiveConflict(any());
        verify(mapper, never()).expireDraft(any(), org.mockito.Mockito.eq("rate_limited"), any(), any());
        verify(mapper, never()).activateDraft(any());
    }

    @Test
    void profileOwnerUsesAccountProfileCapsAndProfileScope() {
        var service = serviceWithFakeProvider();
        when(mapper.countRecentGenerationAttempts(any(), any(), any(), any(), any())).thenReturn(6);

        assertThatThrownBy(() -> service.generateCustomScene(profileRequest("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                    assertThat(contract.code()).isEqualTo("custom_scene_rate_limited");
                    assertThat(contract.details()).containsEntry("scope", "profile");
                    assertThat(contract.details()).containsEntry("limit", 5);
                    assertThat(contract.details()).containsEntry("window", "burst");
                });
        verify(mapper, never()).insertDraftIgnoringLiveConflict(any());
        verify(mapper, never()).expireDraft(any(), org.mockito.Mockito.eq("rate_limited"), any(), any());
        verify(mapper, never()).activateDraft(any());
    }

    @Test
    void disabledCustomSceneAllowsMissingOwnerSecretWithoutDatabaseAccess() {
        var generator = org.mockito.Mockito.mock(CustomSceneGenerationService.class);
        var disabledProperties = new PracticeDiscoveryCustomSceneProperties(
                true,
                PracticeDiscoveryCustomSceneProperties.DEFAULT_TIMEOUT,
                PracticeDiscoveryCustomSceneProperties.DEFAULT_PROMPT_VERSION,
                PracticeDiscoveryCustomSceneProperties.DEFAULT_STRATEGY_VERSION,
                "disabled",
                null,
                null,
                null,
                null,
                null,
                null
        );
        var service = new PracticeGeneratedContentService(
                mapper,
                new PracticeGeneratedContentWriteService(mapper),
                generator,
                validator(),
                disabledProperties,
                PracticeDiscoveryPolicyTestFixture.properties(),
                CLOCK,
                ownerProperties(" ")
        );

        assertThatThrownBy(() -> service.generateCustomScene(request("洗澡后哄睡")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> assertThat(((ContractException) error).code())
                        .isEqualTo("generation_unavailable"));

        verifyNoInteractions(mapper, generator);
    }

    private PracticeGeneratedContentService serviceWithFakeProvider() {
        return serviceWithProperties(properties(
                PracticeDiscoveryCustomSceneProperties.DEFAULT_PROMPT_VERSION,
                PracticeDiscoveryCustomSceneProperties.DEFAULT_STRATEGY_VERSION,
                "fake"
        ));
    }

    private CustomSceneGeneratedContentValidator validator() {
        var policy = PracticeDiscoveryPolicyTestFixture.properties();
        return new CustomSceneGeneratedContentValidator(
                policy,
                new com.zhangspaghetti.babytalk.practice.discovery.CustomSceneIntentClassifier(policy));
    }

    private PracticeGeneratedContentOwnerProperties ownerProperties(String secret) {
        return new PracticeGeneratedContentOwnerProperties("v1", secret);
    }

    private PracticeGeneratedContentService serviceWithProperties(PracticeDiscoveryCustomSceneProperties properties) {
        return new PracticeGeneratedContentService(
                mapper,
                new PracticeGeneratedContentWriteService(mapper),
                new FakeCustomSceneGenerationService(properties),
                validator(),
                properties,
                PracticeDiscoveryPolicyTestFixture.properties(),
                CLOCK,
                ownerProperties("test-owner-key-secret-test-owner-key")
        );
    }

    private PracticeGeneratedContentService serviceWithGenerator(CustomSceneGenerationService generator) {
        return serviceWithPropertiesAndGenerator(
                properties(
                        PracticeDiscoveryCustomSceneProperties.DEFAULT_PROMPT_VERSION,
                        PracticeDiscoveryCustomSceneProperties.DEFAULT_STRATEGY_VERSION,
                        "fake"
                ),
                generator
        );
    }

    private PracticeGeneratedContentService serviceWithPropertiesAndGenerator(
            PracticeDiscoveryCustomSceneProperties properties,
            CustomSceneGenerationService generator
    ) {
        return new PracticeGeneratedContentService(
                mapper,
                new PracticeGeneratedContentWriteService(mapper),
                generator,
                validator(),
                properties,
                PracticeDiscoveryPolicyTestFixture.properties(),
                CLOCK,
                ownerProperties("test-owner-key-secret-test-owner-key")
        );
    }

    private PracticeDiscoveryCustomSceneProperties properties(
            String promptVersion,
            String strategyVersion,
            String fakeMode
    ) {
        return new PracticeDiscoveryCustomSceneProperties(
                true,
                Duration.ofSeconds(5),
                promptVersion,
                strategyVersion,
                fakeMode,
                null,
                null,
                null,
                null,
                null,
                null
        );
    }

    private PracticeGeneratedContentService.CustomSceneDiscoveryRequest request(String customSceneText) {
        return requestForInstallation("install_1", customSceneText);
    }

    private PracticeGeneratedContentService.CustomSceneDiscoveryRequest requestForInstallation(
            String installationId,
            String customSceneText
    ) {
        return new PracticeGeneratedContentService.CustomSceneDiscoveryRequest(
                "onboarding",
                "custom_scene",
                installationId,
                null,
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                customSceneText
        );
    }

    private PracticeGeneratedContentService.CustomSceneDiscoveryRequest accountRequest(String customSceneText) {
        return new PracticeGeneratedContentService.CustomSceneDiscoveryRequest(
                "onboarding",
                "custom_scene",
                null,
                "acct_rate_limit",
                null,
                "m7_11",
                "calmer_care",
                "zh-CN",
                customSceneText
        );
    }

    private PracticeGeneratedContentService.CustomSceneDiscoveryRequest profileRequest(String customSceneText) {
        return new PracticeGeneratedContentService.CustomSceneDiscoveryRequest(
                "onboarding",
                "custom_scene",
                null,
                "acct_rate_limit",
                "profile_rate_limit",
                "m7_11",
                "calmer_care",
                "zh-CN",
                customSceneText
        );
    }

    private void stubReserveInserted() {
        when(mapper.insertDraftIgnoringLiveConflict(any()))
                .thenAnswer(invocation -> invocation.getArgument(0));
    }

    private void stubReserveExisting(PracticeGeneratedContentEntity existing) {
        when(mapper.findLiveByFingerprint(any(), any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(existing);
    }

    private void stubReserveExistingDraft() {
        when(mapper.findLiveByFingerprint(any(), any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(draftRow("pgc_existing_draft"));
    }

    private void stubActivateDraft() {
        var active = new java.util.concurrent.atomic.AtomicReference<PracticeGeneratedContentEntity>();
        when(mapper.activateDraft(any()))
                .thenAnswer(invocation -> {
                    active.set(invocation.getArgument(0));
                    return 1;
                });
        when(mapper.findActiveOrPromotedByGeneratedContentId(any(), any(), any()))
                .thenAnswer(invocation -> active.get());
    }

    private PracticeGeneratedContentService.DraftReservation inserted(
            PracticeGeneratedContentEntity row
    ) {
        return new PracticeGeneratedContentService.DraftReservation(row, true);
    }

    private PracticeGeneratedContentService.DraftReservation existing(
            PracticeGeneratedContentEntity row
    ) {
        return new PracticeGeneratedContentService.DraftReservation(row, false);
    }

    private PracticeGeneratedContentEntity expiredDraft(
            PracticeGeneratedContentEntity row
    ) {
        return new PracticeGeneratedContentEntity(
                row.generatedContentId(),
                row.ownerScope(),
                row.ownerKey(),
                row.accountId(),
                row.installationRefHash(),
                row.profileId(),
                row.surface(),
                row.mode(),
                row.requestFingerprint(),
                row.normalizedSceneText(),
                row.ageRange(),
                row.parentGoal(),
                row.locale(),
                row.spaceSlug(),
                row.activitySlug(),
                row.phraseSlug(),
                row.spaceTitleZh(),
                row.activityTitleZh(),
                row.sceneTagEn(),
                row.coachTipZh(),
                row.englishText(),
                row.chineseText(),
                row.pronunciationHint(),
                row.difficulty(),
                row.generationSource(),
                row.status(),
                row.providerTraceId(),
                row.retrievalTraceId(),
                row.modelName(),
                row.promptVersion(),
                row.strategyVersion(),
                row.contentVersion(),
                row.generationErrorCode(),
                row.generationStartedAt(),
                NOW_DB.minusSeconds(1),
                row.createdAt(),
                row.updatedAt()
        );
    }

    private PracticeGeneratedContentEntity draftRow(String generatedContentId) {
        return new PracticeGeneratedContentEntity(
                generatedContentId,
                "installation",
                "owner_existing_draft",
                null,
                "install_1",
                null,
                "onboarding",
                "custom_scene",
                "fp_existing_draft",
                "洗澡后哄睡",
                "m7_11",
                "calmer_care",
                "zh-CN",
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                "draft",
                null,
                null,
                null,
                PracticeDiscoveryCustomSceneProperties.DEFAULT_PROMPT_VERSION,
                PracticeDiscoveryCustomSceneProperties.DEFAULT_STRATEGY_VERSION,
                1,
                null,
                NOW_DB,
                NOW_DB.plusSeconds(300),
                NOW_DB,
                NOW_DB
        );
    }

    private PracticeGeneratedContentEntity activeRow(
            String generatedContentId,
            String normalizedSceneText
    ) {
        return new PracticeGeneratedContentEntity(
                generatedContentId,
                "installation",
                "owner_existing_active",
                null,
                "install_1",
                null,
                "onboarding",
                "custom_scene",
                "fp_existing_active",
                normalizedSceneText,
                "m7_11",
                "calmer_care",
                "zh-CN",
                "gen_scene_existing",
                "gen_activity_existing",
                "gen_phrase_existing",
                "日常照护",
                "洗澡安抚",
                "Bath care",
                "看着宝宝，慢慢说一遍。",
                "Warm water.",
                "水暖暖的。",
                "warm water",
                "starter",
                "fake",
                "active",
                "fake_provider_trace",
                null,
                "fake-custom-scene",
                PracticeDiscoveryCustomSceneProperties.DEFAULT_PROMPT_VERSION,
                PracticeDiscoveryCustomSceneProperties.DEFAULT_STRATEGY_VERSION,
                1,
                null,
                NOW_DB,
                null,
                NOW_DB,
                NOW_DB
        );
    }

    private CustomSceneGenerationService.GeneratedPracticeContentCandidate candidate() {
        return new CustomSceneGenerationService.GeneratedPracticeContentCandidate(
                "日常照护",
                "洗澡安抚",
                "Bath care",
                "看着宝宝，慢慢说一遍。",
                "Warm water.",
                "水暖暖的。",
                "warm water",
                "starter",
                "fake",
                "fake_provider_trace",
                null,
                "fake-custom-scene"
        );
    }

    private CustomSceneGenerationService.GeneratedPracticeContentCandidate shoesCandidate() {
        return new CustomSceneGenerationService.GeneratedPracticeContentCandidate(
                "出门准备",
                "穿鞋出门",
                "Shoes on",
                "拿起鞋子，慢慢说一遍。",
                "Shoes on.",
                "穿鞋出门。",
                "shoes on",
                "starter",
                "fake",
                "fake_provider_trace",
                null,
                "fake-custom-scene"
        );
    }

    private CustomSceneGenerationService.GeneratedPracticeContentCandidate unsafeCandidate() {
        return new CustomSceneGenerationService.GeneratedPracticeContentCandidate(
                "学习任务",
                "答题打分",
                "Lesson quiz",
                "让孩子答对后再给分。",
                "Take the quiz.",
                "开始测验。",
                "take the quiz",
                "starter",
                "fake",
                "test_provider_trace",
                null,
                "test-custom-scene"
        );
    }

    private CustomSceneGenerationService.GeneratedPracticeContentCandidate invalidCandidate() {
        return new CustomSceneGenerationService.GeneratedPracticeContentCandidate(
                "日常照护",
                "洗澡安抚",
                "Bath care",
                "看着宝宝，慢慢说一遍。",
                "This sentence has far too many words for a starter.",
                "水暖暖的。",
                "warm water",
                "advanced",
                "fake",
                "test_provider_trace",
                null,
                "test-custom-scene"
        );
    }
}
