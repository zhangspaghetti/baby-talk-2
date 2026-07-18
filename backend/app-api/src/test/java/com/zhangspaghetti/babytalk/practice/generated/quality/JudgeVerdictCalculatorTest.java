package com.zhangspaghetti.babytalk.practice.generated.quality;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller.StructuredOutputInvalidException;
import com.zhangspaghetti.babytalk.practice.agentic.config.QualityRubric;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;

class JudgeVerdictCalculatorTest {

    private final JudgeVerdictCalculator calculator = new JudgeVerdictCalculator();
    private final QualityRubric rubric = new QualityRubric(
            "custom-scene-quality-v1",
            "rubric-hash",
            List.of(
                    "scene_alignment",
                    "parent_speakability",
                    "non_course_framing",
                    "tpr_quality",
                    "delivery_guidance_quality",
                    "age_suitability",
                    "bilingual_consistency",
                    "low_pressure_support"),
            Set.of("age_suitability"),
            Set.of(
                    "scene_alignment",
                    "parent_speakability",
                    "non_course_framing",
                    "tpr_quality",
                    "delivery_guidance_quality",
                    "bilingual_consistency",
                    "low_pressure_support"),
            true);

    @Test
    void allPassProducesEffectivePass() {
        var effective = calculator.calculate(suggested(JudgeVerdict.PASS, results()), rubric);

        assertThat(effective.effectiveVerdict()).isEqualTo(JudgeVerdict.PASS);
        assertThat(effective.verdictConsistency()).isEqualTo(VerdictConsistency.CONSISTENT);
        assertThat(effective.repairable()).isFalse();
    }

    @Test
    void ageSuitabilityFailProducesReject() {
        var effective = calculator.calculate(suggested(
                JudgeVerdict.REJECT,
                results(JudgeDimension.AGE_SUITABILITY, DimensionResult.FAIL),
                List.of("AGE_SUITABILITY_FAILED"),
                0.99d), rubric);

        assertThat(effective.effectiveVerdict()).isEqualTo(JudgeVerdict.REJECT);
        assertThat(effective.repairable()).isFalse();
    }

    @Test
    void parentSpeakabilityFailProducesRepair() {
        var effective = calculator.calculate(suggested(
                JudgeVerdict.REPAIR,
                results(JudgeDimension.PARENT_SPEAKABILITY, DimensionResult.FAIL),
                List.of("PARENT_SPEAKABILITY_FAILED"),
                0.99d), rubric);

        assertThat(effective.effectiveVerdict()).isEqualTo(JudgeVerdict.REPAIR);
        assertThat(effective.repairable()).isTrue();
    }

    @Test
    void anyAbstainProducesRepairableAbstain() {
        var effective = calculator.calculate(suggested(
                JudgeVerdict.ABSTAIN,
                results(JudgeDimension.TPR_QUALITY, DimensionResult.ABSTAIN),
                List.of(),
                0.99d), rubric);

        assertThat(effective.effectiveVerdict()).isEqualTo(JudgeVerdict.ABSTAIN);
        assertThat(effective.repairable()).isTrue();
    }

    @Test
    void suggestedPassWithFailedDimensionIsInconsistentAndConservative() {
        var effective = calculator.calculate(suggested(
                JudgeVerdict.PASS,
                results(JudgeDimension.PARENT_SPEAKABILITY, DimensionResult.FAIL),
                List.of("PARENT_SPEAKABILITY_FAILED"),
                0.99d), rubric);

        assertThat(effective.effectiveVerdict()).isEqualTo(JudgeVerdict.REPAIR);
        assertThat(effective.verdictConsistency()).isEqualTo(VerdictConsistency.INCONSISTENT);
    }

    @Test
    void confidenceNeverChangesEffectiveVerdict() {
        var dimensions = results(JudgeDimension.PARENT_SPEAKABILITY, DimensionResult.FAIL);

        var low = calculator.calculate(suggested(
                JudgeVerdict.REPAIR, dimensions, List.of("PARENT_SPEAKABILITY_FAILED"), 0.01d), rubric);
        var high = calculator.calculate(suggested(
                JudgeVerdict.REPAIR, dimensions, List.of("PARENT_SPEAKABILITY_FAILED"), 0.99d), rubric);

        assertThat(low).isEqualTo(high);
    }

    @Test
    void missingDimensionFailsClosedAsStructuredOutputInvalid() {
        var incomplete = results();
        incomplete.remove(JudgeDimension.LOW_PRESSURE_SUPPORT);

        assertThatThrownBy(() -> calculator.calculate(suggested(JudgeVerdict.PASS, incomplete), rubric))
                .isInstanceOf(StructuredOutputInvalidException.class)
                .hasMessage("structured_output_invalid");
    }

    @Test
    void rubricWithUnknownDimensionFailsClosedAsStructuredOutputInvalid() {
        var unknownRubric = new QualityRubric(
                rubric.version(),
                rubric.contentHash(),
                List.of(
                        "scene_alignment",
                        "parent_speakability",
                        "non_course_framing",
                        "tpr_quality",
                        "delivery_guidance_quality",
                        "age_suitability",
                        "bilingual_consistency",
                        "unknown_dimension"),
                rubric.rejectOnFail(),
                rubric.repairOnFail(),
                true);

        assertThatThrownBy(() -> calculator.calculate(suggested(JudgeVerdict.PASS, results()), unknownRubric))
                .isInstanceOf(StructuredOutputInvalidException.class)
                .hasMessage("structured_output_invalid");
    }

    @Test
    void unknownViolationCodeFailsClosedAsStructuredOutputInvalid() {
        assertThatThrownBy(() -> calculator.calculate(suggested(
                JudgeVerdict.REPAIR,
                results(JudgeDimension.SCENE_ALIGNMENT, DimensionResult.FAIL),
                List.of("MODEL_FREE_TEXT"),
                0.8d), rubric))
                .isInstanceOf(StructuredOutputInvalidException.class)
                .hasMessage("structured_output_invalid");
    }

    private SuggestedJudgeResult suggested(JudgeVerdict verdict, Map<JudgeDimension, DimensionResult> dimensions) {
        return suggested(verdict, dimensions, List.of(), 0.8d);
    }

    private SuggestedJudgeResult suggested(
            JudgeVerdict verdict,
            Map<JudgeDimension, DimensionResult> dimensions,
            List<String> violationCodes,
            double confidence
    ) {
        return new SuggestedJudgeResult(
                verdict,
                dimensions,
                violationCodes,
                List.of(),
                List.of(),
                confidence);
    }

    private EnumMap<JudgeDimension, DimensionResult> results(Object... replacements) {
        var results = new EnumMap<JudgeDimension, DimensionResult>(JudgeDimension.class);
        for (var dimension : JudgeDimension.values()) {
            results.put(dimension, DimensionResult.PASS);
        }
        for (int index = 0; index < replacements.length; index += 2) {
            results.put((JudgeDimension) replacements[index], (DimensionResult) replacements[index + 1]);
        }
        return results;
    }
}
