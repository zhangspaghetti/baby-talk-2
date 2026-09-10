package com.zhangspaghetti.babytalk.practice.generated.quality;

import java.util.Locale;

public enum JudgeDimension {
    SCENE_ALIGNMENT,
    PARENT_SPEAKABILITY,
    NON_COURSE_FRAMING,
    TPR_QUALITY,
    DELIVERY_GUIDANCE_QUALITY,
    AGE_SUITABILITY,
    BILINGUAL_CONSISTENCY,
    LOW_PRESSURE_SUPPORT;

    public String rubricKey() {
        return name().toLowerCase(Locale.ROOT);
    }

    public String violationCode() {
        return name() + "_FAILED";
    }
}
