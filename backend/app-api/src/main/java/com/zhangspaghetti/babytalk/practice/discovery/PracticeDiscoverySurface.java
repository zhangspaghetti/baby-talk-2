package com.zhangspaghetti.babytalk.practice.discovery;

import cn.hutool.core.util.StrUtil;

public enum PracticeDiscoverySurface {
    ONBOARDING("onboarding"),
    SCENE_SEARCH("scene_search"),
    CARE_TURN_SUPPORT("care_turn_support"),
    MENTOR_GENERATION("mentor_generation");

    private final String wireValue;

    PracticeDiscoverySurface(String wireValue) {
        this.wireValue = wireValue;
    }

    public String wireValue() {
        return wireValue;
    }

    public static PracticeDiscoverySurface fromWireValue(String value) {
        var normalized = StrUtil.trimToNull(value);
        if (normalized == null) {
            return null;
        }
        for (var surface : values()) {
            if (surface.wireValue.equals(normalized)) {
                return surface;
            }
        }
        return null;
    }

}
