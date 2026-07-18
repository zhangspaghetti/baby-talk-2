package com.zhangspaghetti.babytalk.practice.generated;

public final class PracticeGenerationRateLimitExceededException extends RuntimeException {

    private final String windowName;
    private final int limit;

    public PracticeGenerationRateLimitExceededException(String windowName, int limit) {
        super(windowName);
        this.windowName = windowName;
        this.limit = limit;
    }

    public String windowName() {
        return windowName;
    }

    public int limit() {
        return limit;
    }
}
