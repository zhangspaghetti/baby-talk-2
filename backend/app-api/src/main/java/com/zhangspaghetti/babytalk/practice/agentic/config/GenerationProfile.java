package com.zhangspaghetti.babytalk.practice.agentic.config;

public record GenerationProfile(
        String version,
        String contentHash,
        VersionedRef generatorPrompt,
        VersionedRef judgePrompt,
        VersionedRef repairPrompt,
        VersionedRef rubric,
        VersionedRef evidencePolicy,
        VersionedRef baselineEvidence,
        String strategyVersion,
        String contentSafetyPolicyVersion,
        String generatedOutputSchemaVersion
) {

    public String rubricVersion() {
        return rubric.version();
    }

    public String evidencePolicyVersion() {
        return evidencePolicy.version();
    }
}
