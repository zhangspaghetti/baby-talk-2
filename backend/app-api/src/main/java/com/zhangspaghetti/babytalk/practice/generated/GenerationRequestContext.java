package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.scene.ScenePersonalizationContext;
import java.util.Objects;

/**
 * Complete, structured personalization passed to every provider phase.
 *
 * <p>This value is prompt input, not a diagnostic or persistence value. Its
 * {@code toString()} intentionally omits all profile and activity material.</p>
 */
public record GenerationRequestContext(
        String babyName,
        String ageRange,
        String parentGoal,
        String locale,
        int recentPracticeCount,
        String dominantReaction,
        String recentActivitySummary
) {

    public GenerationRequestContext {
        requireNonBlank(ageRange, "ageRange");
        requireNonBlank(parentGoal, "parentGoal");
        requireNonBlank(locale, "locale");
        if (recentPracticeCount < 0) {
            throw new IllegalArgumentException("recentPracticeCount must not be negative");
        }
        if (recentActivitySummary == null) {
            throw new IllegalArgumentException("recentActivitySummary is required");
        }
    }

    public static GenerationRequestContext from(ScenePersonalizationContext personalization) {
        Objects.requireNonNull(personalization, "personalization");
        return new GenerationRequestContext(
                personalization.babyName(),
                personalization.ageRange(),
                personalization.parentGoal(),
                personalization.locale(),
                personalization.recentPracticeCount(),
                personalization.dominantReaction(),
                personalization.recentActivitySummary());
    }

    @Override
    public String toString() {
        return "GenerationRequestContext{"
                + "locale='" + diagnosticValue(locale) + '\''
                + ", recentPracticeCount=" + recentPracticeCount
                + ", dominantReaction='" + diagnosticValue(dominantReaction) + '\''
                + '}';
    }

    private static void requireNonBlank(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " is required");
        }
    }

    private static String diagnosticValue(String value) {
        if (value == null) {
            return "null";
        }
        return value.replace('\r', ' ').replace('\n', ' ').replace('\'', '_');
    }
}
