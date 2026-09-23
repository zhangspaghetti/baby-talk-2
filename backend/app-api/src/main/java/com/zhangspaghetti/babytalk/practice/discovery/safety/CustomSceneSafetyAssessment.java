package com.zhangspaghetti.babytalk.practice.discovery.safety;

public record CustomSceneSafetyAssessment(
        Intent intent,
        Action action,
        String templateId,
        String policyVersion
) {

    public enum Intent {
        ORDINARY_SCENE,
        REAL_HEALTH_CONCERN,
        UNCERTAIN
    }

    public enum Action {
        EMERGENCY,
        SEEK_MEDICAL_HELP,
        UNCERTAIN
    }
}
