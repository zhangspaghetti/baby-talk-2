package com.zhangspaghetti.babytalk.palace;

import java.util.List;

/**
 * 混合检索结果。
 */
public record RetrievalResult(
        List<HybridCandidate> rankedCandidates,
        QueryTrace trace
) {

    public RetrievalResult {
        rankedCandidates = rankedCandidates == null ? List.of() : List.copyOf(rankedCandidates);
    }
}
