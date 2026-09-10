package com.zhangspaghetti.babytalk.practice.generated.quality;

import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller.StructuredOutputInvalidException;
import com.zhangspaghetti.babytalk.practice.agentic.config.QualityRubric;
import java.util.EnumSet;
import java.util.LinkedHashSet;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;

@Component
public final class JudgeVerdictCalculator {

    public EffectiveJudgeResult calculate(SuggestedJudgeResult suggested, QualityRubric rubric) {
        validate(suggested, rubric);

        JudgeVerdict effectiveVerdict;
        if (hasResultInPolicy(suggested, rubric.rejectOnFail(), DimensionResult.FAIL)) {
            effectiveVerdict = JudgeVerdict.REJECT;
        } else if (hasResultInPolicy(suggested, rubric.repairOnFail(), DimensionResult.FAIL)) {
            effectiveVerdict = JudgeVerdict.REPAIR;
        } else if (suggested.dimensionResults().containsValue(DimensionResult.ABSTAIN)) {
            effectiveVerdict = JudgeVerdict.ABSTAIN;
        } else {
            effectiveVerdict = JudgeVerdict.PASS;
        }
        var consistency = suggested.suggestedVerdict() == effectiveVerdict
                ? VerdictConsistency.CONSISTENT
                : VerdictConsistency.INCONSISTENT;
        boolean repairable = effectiveVerdict == JudgeVerdict.REPAIR
                || effectiveVerdict == JudgeVerdict.ABSTAIN && rubric.repairOnAbstain();
        return new EffectiveJudgeResult(effectiveVerdict, consistency, repairable);
    }

    public Set<String> allowedViolationCodes(QualityRubric rubric) {
        validateRubric(rubric);
        return rubric.dimensions().stream()
                .map(JudgeVerdictCalculator::dimension)
                .map(JudgeDimension::violationCode)
                .collect(Collectors.toUnmodifiableSet());
    }

    private void validate(SuggestedJudgeResult suggested, QualityRubric rubric) {
        try {
            Objects.requireNonNull(suggested, "suggested");
            validateRubric(rubric);
            Objects.requireNonNull(suggested.suggestedVerdict(), "suggestedVerdict");
            Objects.requireNonNull(suggested.dimensionResults(), "dimensionResults");
            Objects.requireNonNull(suggested.violationCodes(), "violationCodes");
            Objects.requireNonNull(suggested.repairDirectives(), "repairDirectives");
            Objects.requireNonNull(suggested.evidenceGapCodes(), "evidenceGapCodes");
            if (!suggested.dimensionResults().keySet().equals(EnumSet.allOf(JudgeDimension.class))
                    || !allowedViolationCodes(rubric).containsAll(suggested.violationCodes())
                    || suggested.confidence() == null
                    || !Double.isFinite(suggested.confidence())
                    || suggested.confidence() < 0.0d
                    || suggested.confidence() > 1.0d) {
                invalid();
            }
        } catch (StructuredOutputInvalidException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            invalid();
        }
    }

    private void validateRubric(QualityRubric rubric) {
        try {
            Objects.requireNonNull(rubric, "rubric");
            var required = EnumSet.allOf(JudgeDimension.class).stream()
                    .map(JudgeDimension::rubricKey)
                    .collect(Collectors.toCollection(LinkedHashSet::new));
            var actual = new LinkedHashSet<>(rubric.dimensions());
            if (rubric.dimensions().size() != required.size()
                    || actual.size() != rubric.dimensions().size()
                    || !actual.equals(required)
                    || !actual.containsAll(rubric.rejectOnFail())
                    || !actual.containsAll(rubric.repairOnFail())) {
                invalid();
            }
        } catch (StructuredOutputInvalidException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            invalid();
        }
    }

    private boolean hasResultInPolicy(
            SuggestedJudgeResult suggested,
            Set<String> policyDimensions,
            DimensionResult result
    ) {
        return policyDimensions.stream()
                .map(JudgeVerdictCalculator::dimension)
                .anyMatch(dimension -> suggested.dimensionResults().get(dimension) == result);
    }

    private static JudgeDimension dimension(String rubricKey) {
        try {
            return JudgeDimension.valueOf(rubricKey.toUpperCase(java.util.Locale.ROOT));
        } catch (RuntimeException exception) {
            throw new StructuredOutputInvalidException();
        }
    }

    private static void invalid() {
        throw new StructuredOutputInvalidException();
    }
}
