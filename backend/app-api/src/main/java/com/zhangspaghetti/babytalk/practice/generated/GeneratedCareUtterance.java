package com.zhangspaghetti.babytalk.practice.generated;

/**
 * One approved, speakable utterance in a bounded generated care moment.
 */
public record GeneratedCareUtterance(
        String englishText,
        String chineseText,
        String pronunciationHint,
        String tprActionZh,
        String deliveryGuidanceZh,
        String difficulty
) {
    public GeneratedCareUtterance {
        requireText(englishText, "englishText", 120);
        requireText(chineseText, "chineseText", 120);
        requireText(pronunciationHint, "pronunciationHint", 120);
        requireText(tprActionZh, "tprActionZh", 240);
        requireText(deliveryGuidanceZh, "deliveryGuidanceZh", 240);
        requireText(difficulty, "difficulty", 16);
    }

    private static void requireText(String value, String field, int maxChars) {
        if (value == null || value.isBlank() || value.codePointCount(0, value.length()) > maxChars) {
            throw new IllegalArgumentException(field + " must be non-blank and within its storage bound");
        }
    }
}
