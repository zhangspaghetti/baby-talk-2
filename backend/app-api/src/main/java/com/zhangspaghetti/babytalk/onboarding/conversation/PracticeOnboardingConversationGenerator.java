package com.zhangspaghetti.babytalk.onboarding.conversation;

import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentService;
import java.util.Map;
import org.springframework.stereotype.Component;

@Component
public class PracticeOnboardingConversationGenerator implements OnboardingConversationGenerator {

    private static final Map<String, String> SERVER_SCENES = Map.of(
            "bedtime", "宝宝准备睡觉，需要温柔安抚",
            "feeding", "宝宝正在进食，需要简短陪伴",
            "post_cry", "宝宝刚哭过，需要温柔安抚",
            "diaper_change", "宝宝正在换尿布，需要简短陪伴");

    private final PracticeGeneratedContentService generatedContentService;

    public PracticeOnboardingConversationGenerator(PracticeGeneratedContentService generatedContentService) {
        this.generatedContentService = generatedContentService;
    }

    @Override
    public GeneratedUtterance generate(GenerationRequest request) {
        var safeScene = SERVER_SCENES.get(request.sceneKey());
        if (safeScene == null) {
            throw new IllegalArgumentException("unsupported server-owned onboarding scene");
        }
        var generated = generatedContentService.generateCustomScene(
                new PracticeGeneratedContentService.CustomSceneDiscoveryRequest(
                        "onboarding", "first_utterance", request.installationId(), null, null,
                        "12_18m", "daily_care", request.locale(), safeScene, request.localEventId()));
        var starter = generatedContentService.findApprovedUtterances(generated.generatedContentId()).stream()
                .filter(utterance -> "starter".equals(utterance.role()))
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("generated onboarding starter is unavailable"));
        return new GeneratedUtterance(
                generated.generatedContentId(), starter.utteranceId(), starter.englishText(),
                starter.chineseText(), starter.pronunciationHint(), null);
    }
}
