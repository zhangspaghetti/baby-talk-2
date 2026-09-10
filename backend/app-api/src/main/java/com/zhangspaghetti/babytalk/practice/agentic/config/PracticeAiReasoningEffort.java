package com.zhangspaghetti.babytalk.practice.agentic.config;

public enum PracticeAiReasoningEffort {
    NONE("none");

    private final String wireValue;

    PracticeAiReasoningEffort(String wireValue) {
        this.wireValue = wireValue;
    }

    public String wireValue() {
        return wireValue;
    }

    public static PracticeAiReasoningEffort fromWireValue(String value) {
        for (var candidate : values()) {
            if (candidate.wireValue.equals(value)) {
                return candidate;
            }
        }
        throw new IllegalArgumentException("unsupported Practice AI reasoning effort");
    }
}
