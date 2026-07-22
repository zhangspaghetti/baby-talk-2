package com.zhangspaghetti.babytalk.practice.agentic;

public enum PracticeAiCapability {
    CUSTOM_SCENE_GENERATOR("custom-scene-generator"),
    CUSTOM_SCENE_QUALITY_JUDGE("custom-scene-quality-judge"),
    CUSTOM_SCENE_REPAIR("custom-scene-repair");

    private final String propertyKey;

    PracticeAiCapability(String propertyKey) {
        this.propertyKey = propertyKey;
    }

    public String propertyKey() {
        return propertyKey;
    }
}
