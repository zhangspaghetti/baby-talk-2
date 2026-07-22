package com.zhangspaghetti.babytalk.practice.agentic.config;

public record VersionedRef(
        String version,
        String contentHash,
        String resourcePath
) {
}
