package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiAuditPort;
import com.zhangspaghetti.babytalk.practice.agentic.config.QualityRubric;
import com.zhangspaghetti.babytalk.practice.generated.quality.DimensionResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeResultAuditPort;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeDimension;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdict;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdictCalculator;
import com.zhangspaghetti.babytalk.practice.generated.quality.SuggestedJudgeResult;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.EnumMap;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Service
@Profile({"dev", "test"})
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "fake"
)
public class FakeCustomSceneQualityJudge implements CustomSceneQualityJudge {

    private static final String FAKE_PROMPT_VERSION = "fake-custom-scene-quality-judge-v1";
    private static final String FAKE_ROUTING_VERSION = "fake-local-routing-v1";
    private static final String FAKE_HASH = "0".repeat(64);

    private final PracticeAiAuditPort operationAudit;
    private final JudgeResultAuditPort judgeAudit;
    private final JudgeVerdictCalculator verdictCalculator;

    public FakeCustomSceneQualityJudge(
            PracticeAiAuditPort operationAudit,
            JudgeResultAuditPort judgeAudit,
            JudgeVerdictCalculator verdictCalculator
    ) {
        this.operationAudit = Objects.requireNonNull(operationAudit, "operationAudit");
        this.judgeAudit = Objects.requireNonNull(judgeAudit, "judgeAudit");
        this.verdictCalculator = Objects.requireNonNull(verdictCalculator, "verdictCalculator");
    }

    @Override
    public SuggestedJudgeResult judge(JudgeRequest request) {
        Objects.requireNonNull(request, "request");
        var now = OffsetDateTime.now(ZoneOffset.UTC);
        var operationRunId = UUID.randomUUID();
        var providerCallId = UUID.randomUUID();
        operationAudit.insertOperationRun(new PracticeAiAuditPort.OperationRunStarted(
                operationRunId,
                "quality_judge",
                "generated_content",
                request.generatedContentId(),
                request.generatedContentId(),
                request.attemptNumber(),
                request.evidenceBundleId(),
                "fake-custom-scene-quality-judge",
                FAKE_PROMPT_VERSION,
                FAKE_HASH,
                request.rubricVersion(),
                request.rubricContentHash(),
                now));
        operationAudit.insertProviderCall(new PracticeAiAuditPort.ProviderCallStarted(
                providerCallId,
                operationRunId,
                "fake-local",
                "fake",
                "deterministic",
                0,
                UUID.randomUUID(),
                FAKE_ROUTING_VERSION,
                FAKE_HASH,
                now));
        var dimensions = new EnumMap<JudgeDimension, DimensionResult>(JudgeDimension.class);
        for (var dimension : JudgeDimension.values()) {
            dimensions.put(dimension, DimensionResult.PASS);
        }
        var suggested = new SuggestedJudgeResult(
                JudgeVerdict.PASS,
                dimensions,
                List.of(),
                List.of(),
                List.of(),
                1.0d);
        var rubric = new QualityRubric(
                request.rubricVersion(),
                request.rubricContentHash(),
                List.of(JudgeDimension.values()).stream().map(JudgeDimension::rubricKey).toList(),
                Set.of(),
                Set.of(),
                true);
        var effective = verdictCalculator.calculate(suggested, rubric);
        operationAudit.completeProviderCall(new PracticeAiAuditPort.ProviderCallCompleted(
                providerCallId, "succeeded", null, 0, now));
        operationAudit.completeOperationRun(new PracticeAiAuditPort.OperationRunCompleted(
                operationRunId, "succeeded", now));
        judgeAudit.persist(new JudgeResultAuditPort.JudgeAuditRecord(
                providerCallId, suggested, effective, rubric));
        return suggested;
    }
}
