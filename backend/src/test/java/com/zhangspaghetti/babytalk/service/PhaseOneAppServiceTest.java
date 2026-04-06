package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.web.BabyTalkPayloads;
import org.junit.jupiter.api.Test;

class PhaseOneAppServiceTest {

    @Test
    void bootstrapExposesSeedSnapshot() {
        PhaseOneAppService service = new PhaseOneAppService();

        BabyTalkPayloads.AppSnapshotResponse snapshot = service.bootstrap();

        assertThat(snapshot.caregiverName()).isEqualTo("小明妈妈");
        assertThat(snapshot.spaces()).hasSize(6);
        assertThat(snapshot.coachSuggestions()).isNotEmpty();
        assertThat(snapshot.onboardingComplete()).isFalse();
    }

    @Test
    void babbledReactionReturnsCelebrationAndSnapshotUpdate() {
        PhaseOneAppService service = new PhaseOneAppService();

        service.completeOnboarding(new BabyTalkPayloads.OnboardingRequest(
                "小明妈妈",
                "小明",
                8,
                "balanced"
        ));
        BabyTalkPayloads.AppActionResponse response = service.registerReaction(
                new BabyTalkPayloads.PracticeReactionRequest("walk", "walk-1", "babbled")
        );

        assertThat(response.celebration()).isNotNull();
        assertThat(response.celebration().title()).contains("发声");
        assertThat(response.snapshot().growthPoints()).isEqualTo(48);
        assertThat(response.snapshot().earnedMilestoneIds()).contains("first-babble-ever");
        assertThat(
                response.snapshot().spaces().stream()
                        .flatMap(space -> space.activities().stream())
                        .filter(activity -> activity.id().equals("walk"))
                        .findFirst()
                        .orElseThrow()
                        .progress()
        ).isGreaterThan(0.18);
    }

    @Test
    void coachReplyReturnsUsablePhraseForBathPrompt() {
        PhaseOneAppService service = new PhaseOneAppService();

        BabyTalkPayloads.CoachAskResponse response = service.askCoach(
                new BabyTalkPayloads.CoachAskRequest("洗澡怎么开口")
        );

        assertThat(response.answer()).contains("洗澡时先别追求完整句");
        assertThat(response.suggestedPhraseEnglish()).isEqualTo("Splash splash! Can you splash with me?");
        assertThat(response.followUpPrompt()).contains("Water time feels warm and safe.");
    }
}