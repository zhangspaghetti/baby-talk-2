package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
import java.util.Objects;

/** One independently valid branch in a complete generated care bundle. */
public record GeneratedCareUtterance(
        CompleteGeneratedBundle.UtteranceRole role,
        CompleteGeneratedBundle.Reaction reaction,
        String englishText,
        String chineseText,
        String pronunciationHint,
        String tprActionZh,
        String deliveryGuidanceZh,
        String difficulty,
        int displayOrder,
        CompleteGeneratedBundle.ProviderProvenance providerProvenance
) {
    public GeneratedCareUtterance {
        Objects.requireNonNull(role, "role");
        if ((role == CompleteGeneratedBundle.UtteranceRole.STARTER) != (reaction == null)) {
            throw new IllegalArgumentException("utterance role and reaction must use the canonical matrix");
        }
        requireText(englishText, "englishText");
        requireText(chineseText, "chineseText");
        requireText(pronunciationHint, "pronunciationHint");
        requireText(tprActionZh, "tprActionZh");
        requireText(deliveryGuidanceZh, "deliveryGuidanceZh");
        requireText(difficulty, "difficulty");
        if (displayOrder < 1 || displayOrder > GeneratedCareMomentBundle.UTTERANCE_COUNT) {
            throw new IllegalArgumentException("displayOrder must be between 1 and 6");
        }
        Objects.requireNonNull(providerProvenance, "providerProvenance");
    }

    private static void requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " must be non-blank");
        }
    }
}
