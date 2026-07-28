package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratedPracticeContentCandidate;
import java.util.Map;
import org.junit.jupiter.api.Test;

class GeneratedCareMomentBundleTest {

    @Test
    void defaultBundleContainsStarterAndEveryCanonicalReactionExactlyOnce() {
        var bundle = GeneratedCareMomentBundle.fromStarter(starter());

        assertThat(bundle.structuralViolationCodes()).isEmpty();
        assertThat(bundle.reactionSupports()).hasSize(5);
        assertThat(bundle.reactionSupports().keySet())
                .containsExactlyInAnyOrder(GeneratedCareMomentBundle.ReactionType.values());
    }

    @Test
    void missingReactionSupportFailsDeterministicBundleGate() {
        var bundle = new GeneratedCareMomentBundle(starter(), Map.of());

        assertThat(bundle.structuralViolationCodes()).containsExactly("MISSING_REACTION_SUPPORT");
    }

    private GeneratedPracticeContentCandidate starter() {
        return new GeneratedPracticeContentCandidate(
                "日常照护", "洗澡时间", "Bath time", "指向水。", "慢一点说。",
                "Warm water.", "水暖暖的。", "warm water", "starter", "fake");
    }
}
