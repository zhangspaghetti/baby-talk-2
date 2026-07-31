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
        String generatedOutputSchemaVersion,
        int minimumCompleteBundleOutputTokens
) {

    public static final int SAFE_MINIMUM_COMPLETE_BUNDLE_OUTPUT_TOKENS = 8192;

    public GenerationProfile(
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
        this(
                version,
                contentHash,
                generatorPrompt,
                judgePrompt,
                repairPrompt,
                rubric,
                evidencePolicy,
                baselineEvidence,
                strategyVersion,
                contentSafetyPolicyVersion,
                generatedOutputSchemaVersion,
                SAFE_MINIMUM_COMPLETE_BUNDLE_OUTPUT_TOKENS);
    }

    public GenerationProfile {
        if (minimumCompleteBundleOutputTokens < SAFE_MINIMUM_COMPLETE_BUNDLE_OUTPUT_TOKENS) {
            throw new IllegalArgumentException(
                    "minimumCompleteBundleOutputTokens must satisfy the safe minimum");
        }
    }

    public String rubricVersion() {
        return rubric.version();
    }

    public String evidencePolicyVersion() {
        return evidencePolicy.version();
    }
}
