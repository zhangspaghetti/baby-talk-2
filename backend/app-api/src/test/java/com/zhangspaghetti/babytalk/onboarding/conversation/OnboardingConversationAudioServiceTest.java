package com.zhangspaghetti.babytalk.onboarding.conversation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentService;
import com.zhangspaghetti.babytalk.practice.generated.audio.GeneratedUtteranceAudio;
import com.zhangspaghetti.babytalk.practice.generated.audio.GeneratedUtteranceAudioService;
import com.zhangspaghetti.babytalk.practice.generated.audio.GeneratedSpeechConfigurationIdentity;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

class OnboardingConversationAudioServiceTest {

    private static final Clock CLOCK = Clock.fixed(
            Instant.parse("2026-08-14T10:00:00Z"), ZoneOffset.UTC);
    private final OnboardingConversationStore store = mock(OnboardingConversationStore.class);
    private final OnboardingConversationTurnStore turns = mock(OnboardingConversationTurnStore.class);
    private final OnboardingAudioCapabilityService capabilities = mock(OnboardingAudioCapabilityService.class);
    private final GeneratedUtteranceAudioService generatedAudio = mock(GeneratedUtteranceAudioService.class);
    private final PracticeGeneratedContentService generatedContent = mock(PracticeGeneratedContentService.class);
    private final OnboardingConversationAudioService service = new OnboardingConversationAudioService(
            store, turns, capabilities, generatedAudio, generatedContent, CLOCK);

    @Test
    void audioUsesEpochCheckedGeneratedAudioEntryForConversationUtterance() {
        when(store.findByConversationId("onbc_test_1234")).thenReturn(conversation("generated-current"));
        when(generatedContent.findActiveOrPromotedByGeneratedContentId("generated-current"))
                .thenReturn(java.util.Optional.of(currentContent("generated-current")));
        var expected = new GeneratedUtteranceAudio(new byte[] {1}, "audio/mpeg", "generated-tts-v1",
                new GeneratedSpeechConfigurationIdentity("fake", "fake-model", "default", "a".repeat(64)));
        when(generatedAudio.synthesizeOnboardingApproved("generated-current", "utterance-current"))
                .thenReturn(expected);

        var result = service.fetch("onbc_test_1234", "utterance-current", "capability");

        assertThat(result).isSameAs(expected);
        verify(generatedAudio).synthesizeOnboardingApproved("generated-current", "utterance-current");
    }

    @Test
    void staleConversationAudioFailsBeforeTtsAndDoesNotReturnStoredEnglish() {
        when(store.findByConversationId("onbc_test_1234")).thenReturn(conversation("generated-legacy"));
        when(generatedContent.findActiveOrPromotedByGeneratedContentId("generated-legacy"))
                .thenReturn(java.util.Optional.empty());
        org.assertj.core.api.Assertions.assertThatThrownBy(() ->
                service.fetch("onbc_test_1234", "utterance-current", "capability"))
                .isInstanceOf(com.zhangspaghetti.babytalk.web.ContractException.class)
                .satisfies(error -> assertThat(((com.zhangspaghetti.babytalk.web.ContractException) error).code())
                        .isEqualTo("onboarding_audio_not_found"));
        verify(generatedContent).findActiveOrPromotedByGeneratedContentId("generated-legacy");
        verify(generatedAudio, never()).synthesizeOnboardingApproved(any(), any());
    }

    private com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity currentContent(
            String generatedContentId) {
        var content = new com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity();
        content.setGeneratedContentId(generatedContentId);
        content.setStatus("active");
        content.setContentRefreshEpoch(2);
        return content;
    }

    private OnboardingConversationStore.StoredConversation conversation(String generatedContentId) {
        return new OnboardingConversationStore.StoredConversation(
                "onbc_test_1234", "installation_hash", "create-event", "ocf_hash",
                "2026-08-14.1", "care.bedtime_soothing", "babytalk.care", "bedtime", 1,
                "{\"parentTonePreference\":\"short_gentle\"}", "zh-CN", "evening",
                generatedContentId, "utterance-current", "Old English.", "旧句。", "old", null,
                "active", OffsetDateTime.now(CLOCK).plusHours(1),
                OffsetDateTime.now(CLOCK).minusMinutes(1), OffsetDateTime.now(CLOCK),
                "owner_" + "b".repeat(64));
    }
}
