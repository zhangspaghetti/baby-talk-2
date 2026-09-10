package com.zhangspaghetti.babytalk.practice.scene;

/**
 * Structured, bounded personalization facts supplied to scene generation.
 *
 * <p>The baby name remains available to the provider prompt, but diagnostic
 * rendering deliberately contains only low-sensitivity context metadata.</p>
 */
public record ScenePersonalizationContext(
        String babyName,
        String ageRange,
        String parentGoal,
        String locale,
        String actorRole,
        int recentPracticeCount,
        String dominantReaction,
        String recentActivitySummary,
        String householdContextVersion
) {

    @Override
    public String toString() {
        return "ScenePersonalizationContext{"
                + "locale='" + diagnosticValue(locale) + '\''
                + ", actorRole='" + diagnosticValue(actorRole) + '\''
                + ", recentPracticeCount=" + recentPracticeCount
                + ", dominantReaction='" + diagnosticValue(dominantReaction) + '\''
                + ", householdContextVersion='" + diagnosticValue(householdContextVersion) + '\''
                + '}';
    }

    private static String diagnosticValue(String value) {
        if (value == null) {
            return "null";
        }
        return value.replace('\r', ' ').replace('\n', ' ').replace('\'', '_');
    }
}
