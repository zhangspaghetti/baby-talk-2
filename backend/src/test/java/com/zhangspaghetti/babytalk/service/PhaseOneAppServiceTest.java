package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.web.BabyTalkPayloads;
import org.junit.jupiter.api.Test;

class PhaseOneAppServiceTest {

    @Test
    void bootstrapExposesSeedSnapshot() {
        PhaseOneAppService service = new PhaseOneAppService();
        String sessionId = service.createSession().sessionId();

        BabyTalkPayloads.AppSnapshotResponse snapshot = service.bootstrap(sessionId);

        assertThat(snapshot.caregiverName()).isEqualTo("小明妈妈");
        assertThat(snapshot.spaces()).hasSize(6);
        assertThat(snapshot.coachSuggestions()).isNotEmpty();
        assertThat(snapshot.onboardingComplete()).isFalse();
    }

    @Test
    void babbledReactionReturnsCelebrationAndSnapshotUpdate() {
        PhaseOneAppService service = new PhaseOneAppService();
        String sessionId = service.createSession().sessionId();

        service.completeOnboarding(sessionId, new BabyTalkPayloads.OnboardingRequest(
                "小明妈妈",
                "小明",
                8,
                "balanced"
        ));
        BabyTalkPayloads.AppActionResponse response = service.registerReaction(
                sessionId,
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
        String sessionId = service.createSession().sessionId();

        BabyTalkPayloads.CoachAskResponse response = service.askCoach(
                sessionId,
                new BabyTalkPayloads.CoachAskRequest("洗澡怎么开口")
        );

        assertThat(response.answer()).contains("洗澡时先别追求完整句");
        assertThat(response.suggestedPhraseEnglish()).isEqualTo("Splash splash! Can you splash with me?");
        assertThat(response.followUpPrompt()).contains("Water time feels warm and safe.");
    }

    @Test
    void sessionsKeepSnapshotsIsolated() {
        PhaseOneAppService service = new PhaseOneAppService();
        String firstSessionId = service.createSession().sessionId();
        String secondSessionId = service.createSession().sessionId();

        service.completeOnboarding(firstSessionId, new BabyTalkPayloads.OnboardingRequest(
                "大宝妈妈",
                "大宝",
                14,
                "stretch"
        ));

        BabyTalkPayloads.AppSnapshotResponse firstSnapshot = service.bootstrap(firstSessionId);
        BabyTalkPayloads.AppSnapshotResponse secondSnapshot = service.bootstrap(secondSessionId);

        assertThat(firstSnapshot.caregiverName()).isEqualTo("大宝妈妈");
        assertThat(secondSnapshot.caregiverName()).isEqualTo("小明妈妈");
        assertThat(secondSnapshot.onboardingComplete()).isFalse();
    }
}