package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.generated.quality.TypedRepairPackage;
import java.util.Objects;
import java.util.UUID;

public interface CustomSceneRepairer {

    /** Repairs and returns all six canonical branches in one provider response. */
    GeneratedCareMomentBundle repairCareMoment(RepairRequest request);

    record RepairRequest(
            String generatedContentId,
            int attemptNumber,
            UUID evidenceBundleId,
            String locale,
            TypedRepairPackage repairPackage
    ) {
        public RepairRequest {
            if (generatedContentId == null || generatedContentId.isBlank()) {
                throw new IllegalArgumentException("generatedContentId must be non-blank");
            }
            if (attemptNumber < 2 || attemptNumber > 5) {
                throw new IllegalArgumentException("repair attemptNumber must be between 2 and 5");
            }
            Objects.requireNonNull(evidenceBundleId, "evidenceBundleId");
            Objects.requireNonNull(locale, "locale");
            Objects.requireNonNull(repairPackage, "repairPackage");
        }
    }
}
