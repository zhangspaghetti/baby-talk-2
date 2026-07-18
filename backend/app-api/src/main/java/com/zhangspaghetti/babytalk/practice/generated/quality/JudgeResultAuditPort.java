package com.zhangspaghetti.babytalk.practice.generated.quality;

import com.zhangspaghetti.babytalk.practice.agentic.config.QualityRubric;
import java.util.Objects;
import java.util.UUID;

public interface JudgeResultAuditPort {

    void persist(JudgeAuditRecord record);

    record JudgeAuditRecord(
            UUID providerCallId,
            SuggestedJudgeResult suggested,
            EffectiveJudgeResult effective,
            QualityRubric rubric
    ) {
        public JudgeAuditRecord {
            Objects.requireNonNull(providerCallId, "providerCallId");
            Objects.requireNonNull(suggested, "suggested");
            Objects.requireNonNull(effective, "effective");
            Objects.requireNonNull(rubric, "rubric");
        }
    }
}
