package com.zhangspaghetti.babytalk.practice.discovery;

import cn.hutool.core.util.StrUtil;

public enum PracticeDiscoveryMode {
    CATALOG("catalog"),
    CUSTOM_SCENE("custom_scene");

    private final String wireValue;

    PracticeDiscoveryMode(String wireValue) {
        this.wireValue = wireValue;
    }

    public String wireValue() {
        return wireValue;
    }

    public static PracticeDiscoveryMode fromWireValue(String value) {
        var normalized = StrUtil.trimToNull(value);
        if (normalized == null) {
            return null;
        }
        for (var mode : values()) {
            if (mode.wireValue.equals(normalized)) {
                return mode;
            }
        }
        return null;
    }

}
