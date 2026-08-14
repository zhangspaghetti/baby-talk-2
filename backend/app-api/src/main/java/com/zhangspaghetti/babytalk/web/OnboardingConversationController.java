package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.onboarding.conversation.OnboardingConversationService;
import com.zhangspaghetti.babytalk.onboarding.conversation.OnboardingConversationTurnService;
import com.zhangspaghetti.babytalk.onboarding.conversation.dto.GuestOnboardingConversationRequest;
import com.zhangspaghetti.babytalk.onboarding.conversation.dto.GuestOnboardingTurnRequest;
import java.util.Map;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/onboarding/conversations")
public class OnboardingConversationController {

    private final OnboardingConversationService service;
    private final OnboardingConversationTurnService turnService;

    public OnboardingConversationController(
            OnboardingConversationService service,
            OnboardingConversationTurnService turnService
    ) {
        this.service = service;
        this.turnService = turnService;
    }

    @PostMapping
    public OnboardingConversationService.Conversation create(
            @RequestBody GuestOnboardingConversationRequest request
    ) {
        var scene = request.generationScene();
        return service.create(new OnboardingConversationService.CreateRequest(
                request.installationId(), request.localEventId(), request.careEntryId(),
                request.registryRevision(),
                scene == null ? null : new OnboardingConversationService.GenerationScene(
                        scene.namespace(), scene.key(), scene.version() == null ? 0 : scene.version(),
                        scene.facets() == null ? Map.of() : scene.facets()),
                request.locale(), request.timeBand(), request.babyNickname()));
    }

    @PostMapping("/{conversationId}/turns")
    public OnboardingConversationTurnService.Turn next(
            @PathVariable String conversationId,
            @RequestBody GuestOnboardingTurnRequest request
    ) {
        var scene = request.generationScene();
        return turnService.next(conversationId, new OnboardingConversationTurnService.NextRequest(
                request.localEventId(), request.previousUtteranceId(), request.parentAction(),
                request.reactionProvided(), request.reaction(), request.reactionText(),
                scene == null ? null : new OnboardingConversationTurnService.GenerationScene(
                        scene.namespace(), scene.key(), scene.version() == null ? 0 : scene.version(),
                        scene.facets() == null ? Map.of() : scene.facets())));
    }
}
