package com.zhangspaghetti.babytalk.practice.agentic.config;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;

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
        int minimumCompleteBundleOutputTokens,
        int minimumQualityJudgeOutputTokens,
        RepairInferencePolicy repairInferencePolicy,
        GeneratorInferencePolicy generatorInferencePolicy
) {

    public static final int SAFE_MINIMUM_COMPLETE_BUNDLE_OUTPUT_TOKENS = 8192;
    public static final int SAFE_MINIMUM_QUALITY_JUDGE_OUTPUT_TOKENS = 8192;

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
                SAFE_MINIMUM_COMPLETE_BUNDLE_OUTPUT_TOKENS,
                0,
                null,
                null);
    }

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
            String generatedOutputSchemaVersion,
            int minimumCompleteBundleOutputTokens
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
                minimumCompleteBundleOutputTokens,
                0,
                null,
                null);
    }

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
            String generatedOutputSchemaVersion,
            int minimumCompleteBundleOutputTokens,
            int minimumQualityJudgeOutputTokens
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
                minimumCompleteBundleOutputTokens,
                minimumQualityJudgeOutputTokens,
                null,
                null);
    }

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
            String generatedOutputSchemaVersion,
            int minimumCompleteBundleOutputTokens,
            int minimumQualityJudgeOutputTokens,
            RepairInferencePolicy repairInferencePolicy
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
                minimumCompleteBundleOutputTokens,
                minimumQualityJudgeOutputTokens,
                repairInferencePolicy,
                null);
    }

    public GenerationProfile {
        if (minimumCompleteBundleOutputTokens < SAFE_MINIMUM_COMPLETE_BUNDLE_OUTPUT_TOKENS) {
            throw new IllegalArgumentException(
                    "minimumCompleteBundleOutputTokens must satisfy the safe minimum");
        }
        if (minimumQualityJudgeOutputTokens != 0
                && minimumQualityJudgeOutputTokens < SAFE_MINIMUM_QUALITY_JUDGE_OUTPUT_TOKENS) {
            throw new IllegalArgumentException(
                    "minimumQualityJudgeOutputTokens must satisfy the safe minimum");
        }
    }

    public String rubricVersion() {
        return rubric.version();
    }

    public String evidencePolicyVersion() {
        return evidencePolicy.version();
    }

    public record RepairInferencePolicy(
            String providerType,
            List<String> modelNames,
            PracticeAiReasoningEffort reasoningEffort
    ) {
        private static final int MAX_MODEL_NAMES = 8;

        public RepairInferencePolicy {
            if (providerType == null || providerType.isBlank()) {
                throw new IllegalArgumentException("repair inference provider type is required");
            }
            modelNames = modelNames == null ? List.of() : List.copyOf(modelNames);
            if (modelNames.isEmpty()
                    || modelNames.size() > MAX_MODEL_NAMES
                    || new LinkedHashSet<>(modelNames).size() != modelNames.size()
                    || modelNames.stream().anyMatch(model -> model == null || model.isBlank())) {
                throw new IllegalArgumentException("repair inference model names are invalid");
            }
            Objects.requireNonNull(reasoningEffort, "repair inference reasoning effort is required");
        }

        public boolean matches(String candidateProviderType, String candidateModelName) {
            return providerType.equals(candidateProviderType) && modelNames.contains(candidateModelName);
        }
    }

    public record GeneratorInferencePolicy(
            String providerType,
            List<String> modelNames,
            PracticeAiReasoningEffort reasoningEffort
    ) {
        private static final int MAX_MODEL_NAMES = 8;

        public GeneratorInferencePolicy {
            if (providerType == null || providerType.isBlank()) {
                throw new IllegalArgumentException("generator inference provider type is required");
            }
            modelNames = modelNames == null ? List.of() : List.copyOf(modelNames);
            if (modelNames.isEmpty()
                    || modelNames.size() > MAX_MODEL_NAMES
                    || new LinkedHashSet<>(modelNames).size() != modelNames.size()
                    || modelNames.stream().anyMatch(model -> model == null || model.isBlank())) {
                throw new IllegalArgumentException("generator inference model names are invalid");
            }
            Objects.requireNonNull(reasoningEffort, "generator inference reasoning effort is required");
        }

        public boolean matches(String candidateProviderType, String candidateModelName) {
            return providerType.equals(candidateProviderType) && modelNames.contains(candidateModelName);
        }
    }
}
