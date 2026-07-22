package com.zhangspaghetti.babytalk.practice.generated.quality;

public enum GeneratedOutputViolationCode {
    OUTPUT_PII(false),
    OUTPUT_BIDI_CONTROL(false),
    OUTPUT_ADULT_VIOLENT(false),
    OUTPUT_DANGEROUS_MEDICAL(false),
    UNTRUSTED_METADATA(false),
    DATABASE_OVERFLOW(false),
    INVALID_ENUM(false),
    MISSING_TPR_ACTION(true),
    MISSING_DELIVERY_GUIDANCE(true),
    FIELD_ROLE_MISMATCH(true),
    META_INSTRUCTION(true),
    COURSE_OR_SCORING_FRAMING(true),
    MARKDOWN_OR_TEMPLATE(true);

    private final boolean repairable;

    GeneratedOutputViolationCode(boolean repairable) {
        this.repairable = repairable;
    }

    public boolean repairable() {
        return repairable;
    }
}
