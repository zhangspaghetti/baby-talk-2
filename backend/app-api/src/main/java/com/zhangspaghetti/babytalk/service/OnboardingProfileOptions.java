package com.zhangspaghetti.babytalk.service;

import java.util.Set;

public final class OnboardingProfileOptions {

    public static final String AGE_RANGE_M0_3 = "m0_3";
    public static final String AGE_RANGE_M4_6 = "m4_6";
    public static final String AGE_RANGE_M7_11 = "m7_11";
    public static final String AGE_RANGE_M12_17 = "m12_17";
    public static final String AGE_RANGE_M18_23 = "m18_23";
    public static final String AGE_RANGE_M24_30 = "m24_30";
    public static final String AGE_RANGE_M31_36 = "m31_36";

    public static final String PARENT_GOAL_NATURAL_OPENING = "natural_opening";
    public static final String PARENT_GOAL_CONFIDENT_PRONUNCIATION = "confident_pronunciation";
    public static final String PARENT_GOAL_CALMER_CARE = "calmer_care";
    public static final String PARENT_GOAL_KEEP_TALKING = "keep_talking";

    public static final Set<String> AGE_RANGES = Set.of(
            AGE_RANGE_M0_3,
            AGE_RANGE_M4_6,
            AGE_RANGE_M7_11,
            AGE_RANGE_M12_17,
            AGE_RANGE_M18_23,
            AGE_RANGE_M24_30,
            AGE_RANGE_M31_36
    );

    public static final Set<String> PARENT_GOALS = Set.of(
            PARENT_GOAL_NATURAL_OPENING,
            PARENT_GOAL_CONFIDENT_PRONUNCIATION,
            PARENT_GOAL_CALMER_CARE,
            PARENT_GOAL_KEEP_TALKING
    );

    private OnboardingProfileOptions() {
    }
}
