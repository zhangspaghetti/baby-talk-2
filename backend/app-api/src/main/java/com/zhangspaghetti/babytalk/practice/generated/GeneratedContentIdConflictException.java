package com.zhangspaghetti.babytalk.practice.generated;

public final class GeneratedContentIdConflictException extends RuntimeException {

    private final String generatedContentId;

    public GeneratedContentIdConflictException(String generatedContentId, Throwable cause) {
        super("practice generated content id already exists: " + generatedContentId, cause);
        this.generatedContentId = generatedContentId;
    }

    public String generatedContentId() {
        return generatedContentId;
    }
}
