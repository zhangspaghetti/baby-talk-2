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
    private final OnboardingConversationTurnStore turnStore;
    private final OnboardingAudioCapabilityService capabilities;
    private final GeneratedUtteranceAudioService generatedAudioService;
    private final Clock clock;

    @Autowired
    public OnboardingConversationAudioService(
            OnboardingConversationStore store,
            OnboardingConversationTurnStore turnStore,
            OnboardingAudioCapabilityService capabilities,
            GeneratedUtteranceAudioService generatedAudioService
    ) {
        this(store, turnStore, capabilities, generatedAudioService, Clock.systemUTC());
    }

    OnboardingConversationAudioService(
            OnboardingConversationStore store,
            OnboardingConversationTurnStore turnStore,
            OnboardingAudioCapabilityService capabilities,
            GeneratedUtteranceAudioService generatedAudioService,
            Clock clock
    ) {
        this.store = store;
        this.turnStore = turnStore;
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
                || !conversation.expiresAt().isAfter(OffsetDateTime.now(clock))) {
            throw audioNotFound();
        }
        if (!utteranceId.equals(conversation.utteranceId())) {
            var turn = turnStore.findByUtterance(conversationId, utteranceId);
            if (turn == null || !turn.expiresAt().isAfter(OffsetDateTime.now(clock))) {
                throw audioNotFound();
            }
            return generatedAudioService.synthesizeApproved(
                    turn.generatedContentId(), turn.utteranceId(), turn.englishText());
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
