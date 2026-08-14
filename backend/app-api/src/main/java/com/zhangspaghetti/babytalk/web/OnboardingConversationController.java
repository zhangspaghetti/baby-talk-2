package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.onboarding.conversation.OnboardingConversationService;
import com.zhangspaghetti.babytalk.onboarding.conversation.dto.GuestOnboardingConversationRequest;
import java.util.Map;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/onboarding/conversations")
public class OnboardingConversationController {

    private final OnboardingConversationService service;

    public OnboardingConversationController(OnboardingConversationService service) {
        this.service = service;
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
}
