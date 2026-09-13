package com.zhangspaghetti.babytalk.onboarding.conversation;

import com.zhangspaghetti.babytalk.practice.generated.audio.GeneratedUtteranceAudio;
import com.zhangspaghetti.babytalk.practice.generated.audio.GeneratedUtteranceAudioService;
import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentEpoch;
import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentService;
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
    private final PracticeGeneratedContentService generatedContent;
    private final Clock clock;

    @Autowired
    public OnboardingConversationAudioService(
            OnboardingConversationStore store,
            OnboardingConversationTurnStore turnStore,
            OnboardingAudioCapabilityService capabilities,
            GeneratedUtteranceAudioService generatedAudioService,
            PracticeGeneratedContentService generatedContent
    ) {
        this(store, turnStore, capabilities, generatedAudioService, generatedContent, Clock.systemUTC());
    }

    OnboardingConversationAudioService(
            OnboardingConversationStore store,
            OnboardingConversationTurnStore turnStore,
            OnboardingAudioCapabilityService capabilities,
            GeneratedUtteranceAudioService generatedAudioService,
            PracticeGeneratedContentService generatedContent,
            Clock clock
    ) {
        this.store = store;
        this.turnStore = turnStore;
        this.capabilities = capabilities;
        this.generatedAudioService = generatedAudioService;
        this.generatedContent = generatedContent;
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
        requireCurrentGeneratedContent(conversation.generatedContentId());
        if (!utteranceId.equals(conversation.utteranceId())) {
            var turn = turnStore.findByUtterance(conversationId, utteranceId);
            if (turn == null || !turn.expiresAt().isAfter(OffsetDateTime.now(clock))) {
                throw audioNotFound();
            }
            requireCurrentGeneratedContent(turn.generatedContentId());
            return generatedAudioService.synthesizeOnboardingApproved(
                    turn.generatedContentId(), turn.utteranceId());
        }
        return generatedAudioService.synthesizeOnboardingApproved(
                conversation.generatedContentId(), conversation.utteranceId());
    }

    private void requireCurrentGeneratedContent(String generatedContentId) {
        try {
            var content = generatedContent == null ? null
                    : generatedContent.findActiveOrPromotedByGeneratedContentId(generatedContentId).orElse(null);
            if (content == null
                    || content.contentRefreshEpoch() != PracticeGeneratedContentEpoch.CURRENT
                    || !("active".equals(content.status()) || "promoted".equals(content.status()))) {
                throw audioNotFound();
            }
        } catch (ContractException exception) {
            throw audioNotFound();
        } catch (RuntimeException exception) {
            throw audioNotFound();
        }
    }

    private ContractException audioNotFound() {
        return new ContractException(
                HttpStatus.NOT_FOUND,
                "onboarding_audio_not_found",
                "未找到可播放的访客语音。");
    }
}
