package com.zhangspaghetti.babytalk.onboarding.conversation;

import com.zhangspaghetti.babytalk.practice.generated.audio.GeneratedUtteranceAudio;
import com.zhangspaghetti.babytalk.practice.generated.audio.GeneratedUtteranceAudioService;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Clock;
import java.time.OffsetDateTime;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public final class OnboardingConversationAudioService {

    private final OnboardingConversationStore store;
    private final OnboardingAudioCapabilityService capabilities;
    private final GeneratedUtteranceAudioService generatedAudioService;
    private final Clock clock;

    @Autowired
    public OnboardingConversationAudioService(
            OnboardingConversationStore store,
            OnboardingAudioCapabilityService capabilities,
            GeneratedUtteranceAudioService generatedAudioService
    ) {
        this(store, capabilities, generatedAudioService, Clock.systemUTC());
    }

    OnboardingConversationAudioService(
            OnboardingConversationStore store,
            OnboardingAudioCapabilityService capabilities,
            GeneratedUtteranceAudioService generatedAudioService,
            Clock clock
    ) {
        this.store = store;
        this.capabilities = capabilities;
        this.generatedAudioService = generatedAudioService;
        this.clock = clock;
    }

    public GeneratedUtteranceAudio fetch(
            String conversationId,
            String utteranceId,
            String capability
    ) {
        capabilities.requireAuthorized(capability, conversationId, utteranceId);
        var conversation = store.findByConversationId(conversationId);
        if (conversation == null
                || !"active".equals(conversation.status())
                || !utteranceId.equals(conversation.utteranceId())
                || !conversation.expiresAt().isAfter(OffsetDateTime.now(clock))) {
            throw audioNotFound();
        }
        return generatedAudioService.synthesizeApproved(
                conversation.generatedContentId(), conversation.utteranceId(), conversation.englishText());
    }

    private ContractException audioNotFound() {
        return new ContractException(
                HttpStatus.NOT_FOUND,
                "onboarding_audio_not_found",
                "未找到可播放的访客语音。");
    }
}
