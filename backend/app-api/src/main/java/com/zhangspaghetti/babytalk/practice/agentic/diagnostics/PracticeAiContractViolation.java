package com.zhangspaghetti.babytalk.practice.agentic.diagnostics;

/** Privacy-safe typed identity for strict provider contract diagnostics. */
public interface PracticeAiContractViolation {

    Category category();

    enum Category {
        SCHEMA_VERSION,
        REQUIRED_COMPONENT,
        TEXT_CONSTRAINT,
        ENUM_VALUE,
        BRANCH_COMPLETENESS,
        ROLE_REACTION_MAPPING,
        DISPLAY_ORDER,
        PROVENANCE,
        UNKNOWN
    }
}
