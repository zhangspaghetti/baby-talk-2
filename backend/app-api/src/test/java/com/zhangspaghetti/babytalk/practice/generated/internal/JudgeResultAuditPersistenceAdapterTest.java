package com.zhangspaghetti.babytalk.practice.generated.internal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import com.zhangspaghetti.babytalk.practice.agentic.config.QualityRubric;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeJudgeResultEntity;
import com.zhangspaghetti.babytalk.practice.generated.quality.DimensionResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.EffectiveJudgeResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.EvidenceGapCode;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeDimension;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeResultAuditPort;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdict;
import com.zhangspaghetti.babytalk.practice.generated.quality.RepairDirective;
import com.zhangspaghetti.babytalk.practice.generated.quality.SuggestedJudgeResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.VerdictConsistency;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.EnumMap;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

class JudgeResultAuditPersistenceAdapterTest {

    @Test
    void mapsCompleteTypedResultToExistingJudgeEntity() {
        var mapper = mock(PracticeGenerationAuditMapper.class);
        var adapter = new JudgeResultAuditPersistenceAdapter(
                mapper,
                Clock.fixed(Instant.parse("2026-07-18T00:00:00Z"), ZoneOffset.UTC));
        var providerCallId = UUID.fromString("30000000-0000-0000-0000-000000000002");
        var dimensions = new EnumMap<JudgeDimension, DimensionResult>(JudgeDimension.class);
        for (var dimension : JudgeDimension.values()) {
            dimensions.put(dimension, DimensionResult.PASS);
        }
        dimensions.put(JudgeDimension.PARENT_SPEAKABILITY, DimensionResult.FAIL);
        var suggested = new SuggestedJudgeResult(
                JudgeVerdict.PASS,
                dimensions,
                List.of("PARENT_SPEAKABILITY_FAILED", "PARENT_SPEAKABILITY_FAILED"),
                List.of(RepairDirective.REPAIR_PARENT_SPEAKABILITY),
                List.of(EvidenceGapCode.PARENT_SPEAKABILITY_EVIDENCE_MISSING),
                0.91d);
        var effective = new EffectiveJudgeResult(
                JudgeVerdict.REPAIR, VerdictConsistency.INCONSISTENT, true);
        var rubric = new QualityRubric(
                "rubric-v1",
                "9".repeat(64),
                Arrays.stream(JudgeDimension.values()).map(JudgeDimension::rubricKey).toList(),
                Set.of("age_suitability"),
                Set.of(
                        "scene_alignment", "parent_speakability", "non_course_framing",
                        "tpr_quality", "delivery_guidance_quality", "bilingual_consistency",
                        "low_pressure_support"),
                true);

        adapter.persist(new JudgeResultAuditPort.JudgeAuditRecord(
                providerCallId, suggested, effective, rubric));

        var captor = ArgumentCaptor.forClass(PracticeJudgeResultEntity.class);
        verify(mapper).insertJudgeResult(captor.capture());
        var entity = captor.getValue();
        assertThat(entity.judgeResultId()).isNotNull();
        assertThat(entity.providerCallId()).isEqualTo(providerCallId);
        assertThat(entity.suggestedVerdict()).isEqualTo("pass");
        assertThat(entity.effectiveVerdict()).isEqualTo("repair");
        assertThat(entity.verdictConsistency()).isEqualTo("inconsistent");
        assertThat(entity.dimensionResultsJson())
                .isEqualTo("{\"scene_alignment\":\"pass\",\"parent_speakability\":\"fail\","
                        + "\"non_course_framing\":\"pass\",\"tpr_quality\":\"pass\","
                        + "\"delivery_guidance_quality\":\"pass\",\"age_suitability\":\"pass\","
                        + "\"bilingual_consistency\":\"pass\",\"low_pressure_support\":\"pass\"}");
        assertThat(entity.violationCodes()).containsExactly("PARENT_SPEAKABILITY_FAILED");
        assertThat(entity.repairDirectives()).containsExactly("REPAIR_PARENT_SPEAKABILITY");
        assertThat(entity.evidenceGapCodes())
                .containsExactly("PARENT_SPEAKABILITY_EVIDENCE_MISSING");
        assertThat(entity.judgeConfidence()).isEqualByComparingTo(BigDecimal.valueOf(0.91d));
        assertThat(entity.rubricVersion()).isEqualTo("rubric-v1");
        assertThat(entity.rubricContentHash()).isEqualTo("9".repeat(64));
        assertThat(entity.createdAt()).isEqualTo("2026-07-18T00:00:00Z");
    }

    @Test
    void auditWriteUsesIndependentTransaction() throws Exception {
        var method = JudgeResultAuditPersistenceAdapter.class.getMethod(
                "persist", JudgeResultAuditPort.JudgeAuditRecord.class);

        var transactional = method.getAnnotation(Transactional.class);
        assertThat(transactional).isNotNull();
        assertThat(transactional.propagation()).isEqualTo(Propagation.REQUIRES_NEW);
    }
}
