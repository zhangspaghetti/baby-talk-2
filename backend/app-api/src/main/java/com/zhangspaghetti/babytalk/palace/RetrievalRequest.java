package com.zhangspaghetti.babytalk.palace;

/**
 * 混合检索请求。
 */
public record RetrievalRequest(
        String query,
        String wingHint,
        String roomHint,
        Integer childAgeMonths,
        int maxResults,
        int maxHops
) {

    private static final int DEFAULT_MAX_RESULTS = 10;
    private static final int DEFAULT_MAX_HOPS = 2;

    public RetrievalRequest {
        query = query == null ? "" : query.trim();
        wingHint = normalizeHint(wingHint);
        roomHint = normalizeHint(roomHint);
        maxResults = maxResults <= 0 ? DEFAULT_MAX_RESULTS : maxResults;
        maxHops = maxHops <= 0 ? DEFAULT_MAX_HOPS : maxHops;
    }

    public RetrievalRequest(String query, String wingHint, String roomHint, Integer childAgeMonths) {
        this(query, wingHint, roomHint, childAgeMonths, DEFAULT_MAX_RESULTS, DEFAULT_MAX_HOPS);
    }

    public RetrievalRequest(String query) {
        this(query, null, null, null, DEFAULT_MAX_RESULTS, DEFAULT_MAX_HOPS);
    }

    private static String normalizeHint(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim().toLowerCase();
    }
}
