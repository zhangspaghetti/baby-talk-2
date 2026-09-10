package com.zhangspaghetti.babytalk.practice.generated.quality;

import java.util.Objects;

/** Sanitized length evidence. Field paths are application-owned; content is never retained. */
public record GeneratedOutputViolationDiagnostic(
        GeneratedOutputViolationCode code,
        FieldPath field,
        LengthUnit lengthUnit,
        int actualLength,
        int limit
) {
    public GeneratedOutputViolationDiagnostic {
        Objects.requireNonNull(code, "code");
        Objects.requireNonNull(field, "field");
        Objects.requireNonNull(lengthUnit, "lengthUnit");
        if (code != GeneratedOutputViolationCode.DATABASE_OVERFLOW
                && code != GeneratedOutputViolationCode.PROVIDER_CONTENT_OVERFLOW) {
            throw new IllegalArgumentException("length diagnostic requires an overflow violation code");
        }
        if (limit < 0 || actualLength <= limit) {
            throw new IllegalArgumentException("diagnostic length must exceed its non-negative limit");
        }
    }

    public GeneratedOutputViolationDiagnostic(
            GeneratedOutputViolationCode code,
            FieldPath field,
            int actualLength,
            int limit
    ) {
        this(code, field, LengthUnit.CODE_POINT, actualLength, limit);
    }

    public static GeneratedOutputViolationDiagnostic forFieldPath(
            GeneratedOutputViolationCode code,
            String fieldPath,
            LengthUnit lengthUnit,
            int actualLength,
            int limit
    ) {
        return new GeneratedOutputViolationDiagnostic(
                code,
                FieldPath.fromWireValue(fieldPath),
                lengthUnit,
                actualLength,
                limit);
    }

    public String fieldPath() {
        return field.wireValue();
    }

    public String auditCode() {
        return code.name()
                + ":fieldPath=" + fieldPath()
                + ":lengthUnit=" + lengthUnit.wireValue()
                + ":actualLength=" + actualLength
                + ":limit=" + limit;
    }

    public enum FieldPath {
        SPACE_TITLE_ZH("spaceTitleZh"),
        ACTIVITY_TITLE_ZH("activityTitleZh"),
        SCENE_TAG_EN("sceneTagEn"),
        TPR_ACTION_ZH("tprActionZh"),
        DELIVERY_GUIDANCE_ZH("deliveryGuidanceZh"),
        ENGLISH_TEXT("englishText"),
        CHINESE_TEXT("chineseText"),
        PRONUNCIATION_HINT("pronunciationHint"),
        DIFFICULTY("difficulty"),
        GENERATION_SOURCE("generationSource"),
        COACH_TIP_ZH("coachTipZh"),
        PROVIDER_NAME("providerProvenance.providerName"),
        MODEL_NAME("providerProvenance.modelName");

        private final String wireValue;

        FieldPath(String wireValue) {
            this.wireValue = wireValue;
        }

        public String wireValue() {
            return wireValue;
        }

        public static FieldPath fromWireValue(String wireValue) {
            for (var field : values()) {
                if (field.wireValue.equals(wireValue)) {
                    return field;
                }
            }
            throw new IllegalArgumentException("diagnostic fieldPath must be application-owned");
        }
    }

    public enum LengthUnit {
        CODE_POINT("code_point"),
        GRAPHEME("grapheme");

        private final String wireValue;

        LengthUnit(String wireValue) {
            this.wireValue = wireValue;
        }

        public String wireValue() {
            return wireValue;
        }
    }
}
