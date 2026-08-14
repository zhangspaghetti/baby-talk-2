package com.zhangspaghetti.babytalk.onboarding.conversation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentService;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class PracticeOnboardingConversationGeneratorTest {

    @Test
    void nextSupportUsesVerifiedPreviousUtteranceAndExplicitInstallationOwnerRef() {
        var content = mock(PracticeGeneratedContentService.class);
        var generated = new PracticeGeneratedContentEntity();
        generated.setGeneratedContentId("generated-next-1");
        var utterance = new PracticeGeneratedContentUtteranceEntity();
        utterance.setUtteranceId("utterance-next-1");
        utterance.setRole("reaction_support");
        utterance.setReactionType("hesitant");
        utterance.setEnglishText("We can go slowly.");
        utterance.setChineseText("我们可以慢慢来。");
        utterance.setPronunciationHint("wi kan go slo-li");
        var installationRef = "installation_" + "a".repeat(64);
        var ownerKey = "owner_" + "b".repeat(64);
        when(content.generateCustomSceneForInstallationOwner(any(), eq(ownerKey), eq(installationRef)))
                .thenReturn(generated);
        when(content.findApprovedUtterances("generated-next-1")).thenReturn(List.of(utterance));
        var generator = new PracticeOnboardingConversationGenerator(content);

        var result = generator.generateNext(new OnboardingConversationGenerator.NextGenerationRequest(
                installationRef, ownerKey, "turn-event-1", "bedtime", Map.of(), "zh-CN", "evening",
                "utterance-first-1", "Time to sleep.", "said_it", true, "hesitant", null));

        var request = ArgumentCaptor.forClass(
                PracticeGeneratedContentService.CustomSceneDiscoveryRequest.class);
        verify(content).generateCustomSceneForInstallationOwner(
                request.capture(), eq(ownerKey), eq(installationRef));
        verify(content, never()).generateCustomScene(any());
        assertThat(request.getValue().installationId()).isNull();
        assertThat(request.getValue().customSceneText()).contains("Time to sleep.", "hesitant");
        assertThat(result.utteranceId()).isEqualTo("utterance-next-1");
    }
}
