package com.zhangspaghetti.babytalk.practice.agentic.config;

import java.util.List;
import java.util.Set;

public record QualityRubric(
        String version,
        String contentHash,
        List<String> dimensions,
        Set<String> rejectOnFail,
        Set<String> repairOnFail,
        boolean repairOnAbstain
) {

    public QualityRubric {
        dimensions = List.copyOf(dimensions);
        rejectOnFail = Set.copyOf(rejectOnFail);
        repairOnFail = Set.copyOf(repairOnFail);
    }
}
