package com.zhangspaghetti.babytalk.onboarding.conversation;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import org.junit.jupiter.api.Test;

class PracticeOnboardingConversationGeneratorTest {

    private final PracticeOnboardingConversationGenerator generator =
            new PracticeOnboardingConversationGenerator();

    @Test
    void firstUtteranceUsesStableServerCuratedCopyWithoutGenerationService() {
        var request = new OnboardingConversationGenerator.GenerationRequest(
                "qa-installation-1", "first-event-1", "bedtime", Map.of(), "zh-CN", "night");

        var first = generator.generate(request);
        var replay = generator.generate(request);

        assertThat(first.generatedContentId()).isEqualTo("onboarding_bedtime");
        assertThat(first.utteranceId()).isEqualTo("onboarding_bedtime_starter");
        assertThat(first.englishText()).isEqualTo("Time for bed.");
        assertThat(first.chineseText()).isEqualTo("该睡觉啦。");
        assertThat(first.pronunciationHint()).isEqualTo("time for bed");
        assertThat(first).isEqualTo(replay);
    }

    @Test
    void nextUtteranceIsStableForSceneAndReaction() {
        var request = new OnboardingConversationGenerator.NextGenerationRequest(
                "installation_hash", "owner_hash", "turn-event-1", "bedtime", Map.of(), "zh-CN", "evening",
                "onboarding_bedtime_starter", "Time for bed.", "said_it", true, "hesitant", null);

        var result = generator.generateNext(request);
        var replay = generator.generateNext(request);

        assertThat(result.generatedContentId()).isEqualTo("onboarding_bedtime");
        assertThat(result.utteranceId()).isEqualTo("onboarding_bedtime_hesitant");
        assertThat(result.englishText()).isEqualTo("You can try slowly.");
        assertThat(result.chineseText()).isEqualTo("你可以慢慢试。");
        assertThat(result).isEqualTo(replay);
    }

    @Test
    void nextUtteranceWithoutReactionUsesStableSceneContinuation() {
        var request = new OnboardingConversationGenerator.NextGenerationRequest(
                "installation_hash", "owner_hash", "turn-event-2", "feeding", Map.of(), "zh-CN", "morning",
                "onboarding_feeding_starter", "Let's eat.", "said_it", false, null, null);

        var result = generator.generateNext(request);

        assertThat(result.generatedContentId()).isEqualTo("onboarding_feeding");
        assertThat(result.utteranceId()).isEqualTo("onboarding_feeding_no_response");
        assertThat(result.englishText()).isEqualTo("I will wait with you.");
        assertThat(result.chineseText()).isEqualTo("我陪你等一等。");
    }
}
