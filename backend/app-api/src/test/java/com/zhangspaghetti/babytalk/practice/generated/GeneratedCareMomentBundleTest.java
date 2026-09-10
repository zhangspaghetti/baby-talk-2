package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
import java.util.List;
import org.junit.jupiter.api.Test;

class GeneratedCareMomentBundleTest {

    @Test
    void completeContractKeepsEveryCanonicalReactionAndIndependentProvenance() {
        var bundle = GeneratedCareMomentBundle.fromCompleteBundle(completeBundle());

        assertThat(bundle.structuralViolationCodes()).isEmpty();
        assertThat(bundle.reactionSupports()).hasSize(5);
        assertThat(bundle.reactionSupports().keySet())
                .containsExactlyInAnyOrder(GeneratedCareMomentBundle.ReactionType.values());
        assertThat(bundle.utterances()).allSatisfy(utterance -> {
            assertThat(utterance.providerProvenance().providerName()).isEqualTo("provider-a");
            assertThat(utterance.providerProvenance().modelName()).isEqualTo("model-a");
        });
    }

    private CompleteGeneratedBundle completeBundle() {
        var provenance = new CompleteGeneratedBundle.ProviderProvenance(
                CompleteGeneratedBundle.ProviderOrigin.PROVIDER_GENERATED, "provider-a", "model-a", 1);
        return new CompleteGeneratedBundle(
                CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION,
                new CompleteGeneratedBundle.SceneMetadata("日常照护", "洗澡时间", "Bath time"),
                List.of(
                        utterance(CompleteGeneratedBundle.UtteranceRole.STARTER, null, 1, provenance),
                        utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.COOPERATING, 2, provenance),
                        utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.HESITANT, 3, provenance),
                        utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.RESISTING, 4, provenance),
                        utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.NO_RESPONSE, 5, provenance),
                        utterance(CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                CompleteGeneratedBundle.Reaction.OTHER, 6, provenance)));
    }

    private CompleteGeneratedBundle.Utterance utterance(
            CompleteGeneratedBundle.UtteranceRole role,
            CompleteGeneratedBundle.Reaction reaction,
            int order,
            CompleteGeneratedBundle.ProviderProvenance provenance
    ) {
        return new CompleteGeneratedBundle.Utterance(
                role, reaction, "Warm water.", "水暖暖的。", "warm water", "指向水。", "慢一点说。",
                "starter", order, provenance);
    }
}
