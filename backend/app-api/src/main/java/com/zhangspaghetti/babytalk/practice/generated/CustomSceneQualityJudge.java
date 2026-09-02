package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.generated.SceneContentGenerator.GeneratedPracticeContentCandidate;
import com.zhangspaghetti.babytalk.practice.generated.quality.SuggestedJudgeResult;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

public interface CustomSceneQualityJudge {

    SuggestedJudgeResult judge(JudgeRequest request);

    record JudgeRequest(
            String generatedContentId,
            int attemptNumber,
            UUID evidenceBundleId,
            String displayText,
            String ageRange,
            String parentGoal,
            GeneratedPracticeContentCandidate candidate,
            GeneratedCareMomentBundle careMoment,
            List<String> strategyIds,
            List<String> communicationPrimitiveIds,
            List<String> ageGuidanceTags,
            List<String> safetyConstraintTags,
            List<String> orderedSanitizedEvidenceSummaries,
            String rubricVersion,
            String rubricContentHash,
            GenerationRequestContext context
    ) {
        public JudgeRequest(
                String generatedContentId,
                int attemptNumber,
                UUID evidenceBundleId,
                String displayText,
                String ageRange,
                String parentGoal,
                GeneratedPracticeContentCandidate candidate,
                GeneratedCareMomentBundle careMoment,
                List<String> strategyIds,
                List<String> communicationPrimitiveIds,
                List<String> ageGuidanceTags,
                List<String> safetyConstraintTags,
                List<String> orderedSanitizedEvidenceSummaries,
                String rubricVersion,
                String rubricContentHash
        ) {
            this(generatedContentId, attemptNumber, evidenceBundleId, displayText, ageRange, parentGoal,
                    candidate, careMoment, strategyIds, communicationPrimitiveIds, ageGuidanceTags,
                    safetyConstraintTags, orderedSanitizedEvidenceSummaries, rubricVersion, rubricContentHash,
                    new GenerationRequestContext(
                            "legacy",
                            ageRange,
                            parentGoal,
                            "unknown",
                            "legacy",
                            0,
                            null,
                            ""));
        }

        public JudgeRequest {
            requireNonBlank(generatedContentId, "generatedContentId");
            if (attemptNumber < 1) {
                throw new IllegalArgumentException("attemptNumber must be positive");
            }
            Objects.requireNonNull(evidenceBundleId, "evidenceBundleId");
            requireNonBlank(displayText, "displayText");
            requireNonBlank(ageRange, "ageRange");
            requireNonBlank(parentGoal, "parentGoal");
            Objects.requireNonNull(candidate, "candidate");
            Objects.requireNonNull(careMoment, "careMoment");
            strategyIds = requiredList(strategyIds, "strategyIds");
            communicationPrimitiveIds = requiredList(communicationPrimitiveIds, "communicationPrimitiveIds");
            ageGuidanceTags = requiredList(ageGuidanceTags, "ageGuidanceTags");
            safetyConstraintTags = requiredList(safetyConstraintTags, "safetyConstraintTags");
            orderedSanitizedEvidenceSummaries = requiredList(
                    orderedSanitizedEvidenceSummaries, "orderedSanitizedEvidenceSummaries");
            requireNonBlank(rubricVersion, "rubricVersion");
            requireNonBlank(rubricContentHash, "rubricContentHash");
            Objects.requireNonNull(context, "context");
            if (!Objects.equals(ageRange, context.ageRange())
                    || !Objects.equals(parentGoal, context.parentGoal())) {
                throw new IllegalArgumentException("judge request context must match request profile");
            }
        }

        @Override
        public String toString() {
            return "JudgeRequest{"
                    + "generatedContentId='" + generatedContentId + '\''
                    + ", attemptNumber=" + attemptNumber
                    + ", rubricVersion='" + rubricVersion + '\''
                    + '}';
        }
        private static List<String> requiredList(List<String> values, String field) {
            Objects.requireNonNull(values, field);
            var copy = List.copyOf(values);
            if (copy.stream().anyMatch(String::isBlank)) {
                throw new IllegalArgumentException(field + " must contain non-blank values");
            }
            return copy;
        }

        private static void requireNonBlank(String value, String field) {
            if (value == null || value.isBlank()) {
                throw new IllegalArgumentException(field + " must be non-blank");
            }
        }
    }
}
