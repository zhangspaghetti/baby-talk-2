package com.zhangspaghetti.babytalk.palace;

import java.util.List;

/**
 * 单次检索的结构化追踪信息。
 */
public record QueryTrace(
        List<String> entryRooms,
        List<String> roomsTraversed,
        List<String> bridgeEdgesCrossed,
        String temporalRuleApplied,
        List<HybridCandidate> candidates,
        String projectionVersionUsed
) {

    public QueryTrace {
        entryRooms = entryRooms == null ? List.of() : List.copyOf(entryRooms);
        roomsTraversed = roomsTraversed == null ? List.of() : List.copyOf(roomsTraversed);
        bridgeEdgesCrossed = bridgeEdgesCrossed == null ? List.of() : List.copyOf(bridgeEdgesCrossed);
        temporalRuleApplied = temporalRuleApplied == null || temporalRuleApplied.isBlank()
                ? "skipped"
                : temporalRuleApplied;
        candidates = candidates == null ? List.of() : List.copyOf(candidates);
    }
}
