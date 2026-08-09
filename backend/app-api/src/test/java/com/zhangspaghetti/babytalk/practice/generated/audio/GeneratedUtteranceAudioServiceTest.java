package com.zhangspaghetti.babytalk.practice.generated.audio;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentQueryMapper;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Duration;
import java.util.stream.Stream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class GeneratedUtteranceAudioServiceTest {

    @Mock
    private AuthConsentSyncService authConsentSyncService;

    @Mock
    private PracticeGeneratedContentQueryMapper queryMapper;

    @Mock
    private GeneratedSpeechSynthesisPort speechSynthesisPort;

    private GeneratedUtteranceAudioService service;

    @BeforeEach
    void setUp() {
        service = new GeneratedUtteranceAudioService(
                authConsentSyncService,
                queryMapper,
                speechSynthesisPort,
                properties()
        );
        when(authConsentSyncService.requireAcceptedConsumerSession(any(), any()))
                .thenReturn(new AuthConsentSyncService.ConsumerSessionView(
                        "acct_owner", "session_owner", "install_owner", "accepted"));
    }

    @Test
    void synthesizesOnlyTheStoredApprovedEnglishForTheCurrentOwner() {
        when(queryMapper.findPlayableOwnedActiveBundleUtterance("pgc_1", "utt_1", "acct_owner"))
                .thenReturn(utterance("Look at the bubbles."));
        when(speechSynthesisPort.synthesize(any()))
                .thenReturn(new GeneratedAudioResponse(new byte[] {1, 2, 3}, "audio/mpeg", "generated-tts-v1"));

        var audio = service.synthesize("pgc_1", "utt_1", "session_owner");

        assertThat(audio.bytes()).containsExactly(1, 2, 3);
        var request = ArgumentCaptor.forClass(GeneratedSpeechSynthesisPort.GeneratedSpeechRequest.class);
        verify(speechSynthesisPort).synthesize(request.capture());
        assertThat(request.getValue().generatedContentId()).isEqualTo("pgc_1");
        assertThat(request.getValue().utteranceId()).isEqualTo("utt_1");
        assertThat(request.getValue().approvedEnglishText()).isEqualTo("Look at the bubbles.");
        verify(queryMapper).findPlayableOwnedActiveBundleUtterance("pgc_1", "utt_1", "acct_owner");
        verifyNoMoreInteractions(queryMapper);
    }

    @Test
    void crossAccountOrInactiveContentIsIndistinguishableAndNeverCallsTheProvider() {
        when(queryMapper.findPlayableOwnedActiveBundleUtterance("pgc_other", "utt_1", "acct_owner"))
                .thenReturn(null);

        assertThatThrownBy(() -> service.synthesize("pgc_other", "utt_1", "session_owner"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status().value()).isEqualTo(404);
                    assertThat(contract.code()).isEqualTo("generated_audio_not_found");
                });

        verifyNoInteractions(speechSynthesisPort);
    }

    @Test
    void utteranceMustBelongToTheActiveContentAndBeApprovedPlayable() {
        when(queryMapper.findPlayableOwnedActiveBundleUtterance("pgc_1", "utt_other", "acct_owner"))
                .thenReturn(null);

        assertThatThrownBy(() -> service.synthesize("pgc_1", "utt_other", "session_owner"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> assertThat(((ContractException) error).code()).isEqualTo("generated_audio_not_found"));

        verify(speechSynthesisPort, never()).synthesize(any());
    }

    @ParameterizedTest
    @MethodSource("invalidProviderResponses")
    void rejectsEmptyOversizedOrWrongMimeProviderOutput(GeneratedAudioResponse invalidResponse) {
        when(queryMapper.findPlayableOwnedActiveBundleUtterance("pgc_1", "utt_1", "acct_owner"))
                .thenReturn(utterance("Time for a cuddle."));
        when(speechSynthesisPort.synthesize(any()))
                .thenReturn(invalidResponse);

        assertThatThrownBy(() -> service.synthesize("pgc_1", "utt_1", "session_owner"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> assertThat(((ContractException) error).code())
                        .isEqualTo("generated_audio_invalid_response"));
    }

    private static Stream<GeneratedAudioResponse> invalidProviderResponses() {
        return Stream.of(
                new GeneratedAudioResponse(new byte[0], "audio/mpeg", "generated-tts-v1"),
                new GeneratedAudioResponse(new byte[513], "audio/mpeg", "generated-tts-v1"),
                new GeneratedAudioResponse(new byte[] {1}, "audio/wav", "generated-tts-v1")
        );
    }

    @Test
    void providerTimeoutLeavesGeneratedContentUntouched() {
        when(queryMapper.findPlayableOwnedActiveBundleUtterance("pgc_1", "utt_1", "acct_owner"))
                .thenReturn(utterance("Gentle hands."));
        when(speechSynthesisPort.synthesize(any()))
                .thenThrow(GeneratedSpeechSynthesisException.timeout(new RuntimeException("timeout")));

        assertThatThrownBy(() -> service.synthesize("pgc_1", "utt_1", "session_owner"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status().value()).isEqualTo(504);
                    assertThat(contract.code()).isEqualTo("generated_audio_timeout");
                    assertThat(contract.details()).containsEntry("retryable", true);
                });

        verify(queryMapper).findPlayableOwnedActiveBundleUtterance("pgc_1", "utt_1", "acct_owner");
        verifyNoMoreInteractions(queryMapper);
    }

    @Test
    void providerUnavailableLeavesGeneratedContentUntouched() {
        when(queryMapper.findPlayableOwnedActiveBundleUtterance("pgc_1", "utt_1", "acct_owner"))
                .thenReturn(utterance("Gentle hands."));
        when(speechSynthesisPort.synthesize(any()))
                .thenThrow(GeneratedSpeechSynthesisException.unavailable(new RuntimeException("provider unavailable")));

        assertThatThrownBy(() -> service.synthesize("pgc_1", "utt_1", "session_owner"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status().value()).isEqualTo(503);
                    assertThat(contract.code()).isEqualTo("generated_audio_unavailable");
                    assertThat(contract.details()).containsEntry("retryable", true);
                });

        verify(queryMapper).findPlayableOwnedActiveBundleUtterance("pgc_1", "utt_1", "acct_owner");
        verifyNoMoreInteractions(queryMapper);
    }

    private PracticeGeneratedContentUtteranceEntity utterance(String englishText) {
        var utterance = new PracticeGeneratedContentUtteranceEntity();
        utterance.setEnglishText(englishText);
        return utterance;
    }

    private GeneratedSpeechProperties properties() {
        return new GeneratedSpeechProperties(
                true,
                "fake",
                Duration.ofSeconds(5),
                512,
                16_384,
                "generated-tts-v1",
                "mp3",
                null,
                null,
                null,
                null,
                "default",
                java.util.Set.of()
        );
    }
}
