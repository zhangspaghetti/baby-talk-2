package com.zhangspaghetti.babytalk.practice.discovery;

public record SceneTextRiskSignals(
        boolean bidiControlPresent,
        boolean removedInvisible,
        boolean mixedDigitSystems,
        boolean longDigitRun
) {
}
