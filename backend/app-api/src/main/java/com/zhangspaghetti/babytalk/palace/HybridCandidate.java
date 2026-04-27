package com.zhangspaghetti.babytalk.palace;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * 混合检索候选项。
 */
public record HybridCandidate(
        String chunkId,
        String content,
        Double vectorScore,
        Double keywordScore,
        Double mergedScore,
        String ageRangeRaw,
        Double ageBoostApplied,
        String rankingReason
) {

    public HybridCandidate {
        chunkId = chunkId == null ? "" : chunkId;
        content = content == null ? "" : content;
        mergedScore = mergedScore == null ? 0.0d : mergedScore;
        ageBoostApplied = ageBoostApplied == null ? 1.0d : ageBoostApplied;
        rankingReason = rankingReason == null ? "" : rankingReason;
    }

    @JsonProperty("effectiveScore")
    public double effectiveScore() {
        return mergedScore * ageBoostApplied;
    }
}
