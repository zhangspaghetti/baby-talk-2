package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiOperationRunner.ProvidersExhaustedException;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGeneratedContentValidator;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratedPracticeContentCandidate;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratorRequest;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneQualityJudge.JudgeRequest;
import com.zhangspaghetti.babytalk.practice.generated.evidence.CustomSceneEvidenceRetriever;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceBundleFactory;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceRetrievalResult;
import com.zhangspaghetti.babytalk.practice.generated.evidence.FrozenEvidenceBundle;
import com.zhangspaghetti.babytalk.practice.generated.evidence.RetrievalStatus;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.practice.generated.quality.DimensionResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.EvidenceGapCode;
import com.zhangspaghetti.babytalk.practice.generated.quality.GeneratedOutputGateResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.GeneratedOutputViolationCode;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeDimension;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdict;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdictCalculator;
import com.zhangspaghetti.babytalk.practice.generated.quality.RepairDirective;
import com.zhangspaghetti.babytalk.practice.generated.quality.SuggestedJudgeResult;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.DefaultResourceLoader;

class CustomSceneGenerationOrchestratorTest {

    private static final OffsetDateTime NOW = OffsetDateTime.parse("2026-07-18T12:00:00Z");

    @Test
    void generatorGatePassJudgePassActivatesWithOneInitialBundle() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.pass());
        harness.judges.add(pass());

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("active");
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "generator:1",
                "gate:1",
                "judge:1",
                "activate",
                "attempt-completed:1:passed");
        assertThat(harness.generatorRequests).singleElement().satisfies(request -> {
            assertThat(request.attemptNumber()).isEqualTo(1);
            assertThat(request.evidenceBundle()).isSameAs(harness.bundle(1));
        });
        assertThat(harness.judgeRequests).singleElement().satisfies(request -> {
            assertThat(request.attemptNumber()).isEqualTo(1);
            assertThat(request.evidenceBundleId()).isEqualTo(harness.bundle(1).evidenceBundleId());
        });
    }

    @Test
    void attemptStartAuditFailureExpiresParentWithoutCompletingOrGenerating() {
        var harness = new Harness(2);
        harness.attemptStartFailure = new IllegalStateException("audit unavailable");

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("expired");
        assertThat(result.generationErrorCode()).isEqualTo("attempt_audit_start_failure");
        assertThat(harness.completedAttempts).isEmpty();
        assertThat(harness.events).containsExactly(
                "attempt-start-failed:1:generator",
                "expire:attempt_audit_start_failure:true");
        assertThat(harness.generatorRequests).isEmpty();
        assertThat(harness.repairRequests).isEmpty();
    }

    @Test
    void repairableDeterministicFailureRepairsThenRegatesAndFreshlyJudges() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.repairable(GeneratedOutputViolationCode.MISSING_TPR_ACTION));
        harness.gates.add(GateSpec.pass());
        harness.judges.add(pass());

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("active");
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "generator:1",
                "gate:1",
                "attempt-completed:1:repairable_violation",
                "attempt-started:2:repair",
                "bundle:reused:2",
                "repair:2",
                "gate:2",
                "judge:2",
                "activate",
                "attempt-completed:2:passed");
        assertThat(harness.repairRequests).singleElement().satisfies(request -> {
            assertThat(request.attemptNumber()).isEqualTo(2);
            assertThat(request.evidenceBundleId()).isEqualTo(harness.bundle(2).evidenceBundleId());
            assertThat(request.repairPackage().violationCodes()).containsExactly("MISSING_TPR_ACTION");
        });
        assertThat(harness.judgeRequests).singleElement().satisfies(request ->
                assertThat(request.attemptNumber()).isEqualTo(2));
    }

    @Test
    void repairableViolationExpiresWithoutRepairWhenAttemptCompletionAuditFails() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.repairable(GeneratedOutputViolationCode.MISSING_TPR_ACTION));
        harness.attemptCompletionFailure = new IllegalStateException("audit unavailable");

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("expired");
        assertThat(result.generationErrorCode()).isEqualTo("attempt_audit_completion_failure");
        assertThat(harness.completedAttempts).isEmpty();
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "generator:1",
                "gate:1",
                "attempt-completion-failed:1:repairable_violation",
                "expire:attempt_audit_completion_failure:true");
        assertThat(harness.repairRequests).isEmpty();
    }

    @Test
    void judgeRepairRepairsThenRegatesAndUsesFreshJudge() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.pass());
        harness.gates.add(GateSpec.pass());
        harness.judges.add(repair());
        harness.judges.add(pass());

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("active");
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "generator:1",
                "gate:1",
                "judge:1",
                "attempt-completed:1:judge_repair",
                "attempt-started:2:repair",
                "bundle:reused:2",
                "repair:2",
                "gate:2",
                "judge:2",
                "activate",
                "attempt-completed:2:passed");
        assertThat(harness.judgeRequests).extracting(JudgeRequest::attemptNumber).containsExactly(1, 2);
        assertThat(harness.judgeRequests).extracting(JudgeRequest::evidenceBundleId)
                .containsExactly(harness.bundle(1).evidenceBundleId(), harness.bundle(2).evidenceBundleId());
        assertThat(harness.repairRequests).singleElement().satisfies(request -> {
            assertThat(request.repairPackage().effectiveVerdict()).isEqualTo(JudgeVerdict.REPAIR);
                assertThat(request.repairPackage().repairDirectives()).containsExactly(RepairDirective.REPAIR_TPR_QUALITY);
        });
    }

    @Test
    void judgeRepairExpiresWithoutRepairWhenAttemptCompletionAuditFails() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.pass());
        harness.judges.add(repair());
        harness.attemptCompletionFailure = new IllegalStateException("audit unavailable");

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("expired");
        assertThat(result.generationErrorCode()).isEqualTo("attempt_audit_completion_failure");
        assertThat(harness.completedAttempts).isEmpty();
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "generator:1",
                "gate:1",
                "judge:1",
                "attempt-completion-failed:1:judge_repair",
                "expire:attempt_audit_completion_failure:true");
        assertThat(harness.repairRequests).isEmpty();
    }

    @Test
    void judgeAbstainRepairsThenRegatesAndUsesFreshJudge() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.pass());
        harness.gates.add(GateSpec.pass());
        harness.judges.add(abstain());
        harness.judges.add(pass());

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("active");
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "generator:1",
                "gate:1",
                "judge:1",
                "attempt-completed:1:judge_abstain",
                "attempt-started:2:repair",
                "bundle:reused:2",
                "repair:2",
                "gate:2",
                "judge:2",
                "activate",
                "attempt-completed:2:passed");
        assertThat(harness.repairRequests).singleElement().satisfies(request ->
                assertThat(request.repairPackage().effectiveVerdict()).isEqualTo(JudgeVerdict.ABSTAIN));
        assertThat(harness.judgeRequests).extracting(JudgeRequest::attemptNumber).containsExactly(1, 2);
    }

    @Test
    void terminalDeterministicFailureRejectsWithoutJudgeOrRepair() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.terminal(GeneratedOutputViolationCode.OUTPUT_PII));

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("rejected");
        assertThat(result.generationErrorCode()).isEqualTo("terminal_output_violation");
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "generator:1",
                "gate:1",
                "attempt-completed:1:terminal_violation",
                "reject:terminal_output_violation:false");
        assertThat(harness.judgeRequests).isEmpty();
        assertThat(harness.repairRequests).isEmpty();
    }

    @Test
    void judgeRejectRejectsWithoutRepair() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.pass());
        harness.judges.add(reject());

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("rejected");
        assertThat(result.generationErrorCode()).isEqualTo("judge_rejected");
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "generator:1",
                "gate:1",
                "judge:1",
                "attempt-completed:1:judge_reject",
                "reject:judge_rejected:false");
        assertThat(harness.repairRequests).isEmpty();
    }

    @Test
    void generatorProvidersExhaustedExpiresParent() {
        var harness = new Harness(2);
        harness.generatorExhausted = true;

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("expired");
        assertThat(result.generationErrorCode()).isEqualTo("providers_exhausted");
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "generator:1",
                "attempt-completed:1:providers_exhausted",
                "expire:providers_exhausted:true");
        assertThat(harness.judgeRequests).isEmpty();
        assertThat(harness.repairRequests).isEmpty();
    }

    @Test
    void providerExhaustionExpiresParentWhenAttemptCompletionAuditFails() {
        var harness = new Harness(2);
        harness.generatorExhausted = true;
        harness.attemptCompletionFailure = new IllegalStateException("audit unavailable");

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("expired");
        assertThat(result.generationErrorCode()).isEqualTo("providers_exhausted");
        assertThat(harness.completedAttempts).isEmpty();
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "generator:1",
                "attempt-completion-failed:1:providers_exhausted",
                "expire:providers_exhausted:true");
    }

    @Test
    void judgeProvidersExhaustedExpiresParent() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.pass());
        harness.judgeExhausted = true;

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("expired");
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "generator:1",
                "gate:1",
                "judge:1",
                "attempt-completed:1:providers_exhausted",
                "expire:providers_exhausted:true");
        assertThat(harness.repairRequests).isEmpty();
    }

    @Test
    void repairProvidersExhaustedExpiresParent() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.repairable(GeneratedOutputViolationCode.MISSING_TPR_ACTION));
        harness.repairExhausted = true;

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("expired");
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "generator:1",
                "gate:1",
                "attempt-completed:1:repairable_violation",
                "attempt-started:2:repair",
                "bundle:reused:2",
                "repair:2",
                "attempt-completed:2:providers_exhausted",
                "expire:providers_exhausted:true");
        assertThat(harness.judgeRequests).isEmpty();
    }

    @Test
    void attemptLimitExhaustionRejectsAfterLastCompletedAttempt() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.repairable(GeneratedOutputViolationCode.MISSING_TPR_ACTION));
        harness.gates.add(GateSpec.repairable(GeneratedOutputViolationCode.MISSING_DELIVERY_GUIDANCE));

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("rejected");
        assertThat(result.generationErrorCode()).isEqualTo("generation_attempts_exhausted");
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "generator:1",
                "gate:1",
                "attempt-completed:1:repairable_violation",
                "attempt-started:2:repair",
                "bundle:reused:2",
                "repair:2",
                "gate:2",
                "attempt-completed:2:attempt_limit_exhausted",
                "reject:generation_attempts_exhausted:false");
        assertThat(harness.judgeRequests).isEmpty();
    }

    @Test
    void providerFallbackDoesNotIncrementSemanticAttemptNumber() {
        var harness = new Harness(2);
        harness.generatorFallback = true;
        harness.gates.add(GateSpec.pass());
        harness.judges.add(pass());

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("active");
        assertThat(harness.events).containsSubsequence(
                "generator-provider:0",
                "generator-provider:1",
                "generator:1",
                "gate:1",
                "judge:1");
        assertThat(harness.events).filteredOn(event -> event.startsWith("attempt-started:"))
                .containsExactly("attempt-started:1:generator");
        assertThat(harness.events).filteredOn(event -> event.startsWith("bundle:"))
                .containsExactly("bundle:initial:1");
        assertThat(harness.generatorRequests).extracting(GeneratorRequest::attemptNumber).containsExactly(1);
    }

    @Test
    void initialInsufficientEvidenceExpiresWithoutConsumingDailyQuota() {
        var harness = new Harness(2);
        harness.initialEvidenceInsufficient = true;

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("expired");
        assertThat(result.generationErrorCode()).isEqualTo("insufficient_evidence");
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "attempt-completed:1:insufficient_evidence",
                "expire:insufficient_evidence:true");
        assertThat(harness.generatorRequests).isEmpty();
    }

    @Test
    void dailyLimitExpiresBeforeThrowingAndCreatesNoGeneratorOperation() {
        var harness = new Harness(2);
        harness.startDecision = GenerationStartDecision.DAILY_LIMIT_EXCEEDED;

        assertThatThrownBy(harness::execute)
                .isInstanceOf(PracticeGenerationRateLimitExceededException.class);

        assertThat(harness.executionDraft.status()).isEqualTo("expired");
        assertThat(harness.executionDraft.generationErrorCode()).isEqualTo("generation_rate_limited");
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "attempt-completed:1:generation_rate_limited",
                "expire:generation_rate_limited:true");
        assertThat(harness.generatorRequests).isEmpty();
    }

    @Test
    void notLiveReturnsOnlyActiveReloadAndCreatesNoGeneratorOperation() {
        var activeHarness = new Harness(2);
        activeHarness.startDecision = GenerationStartDecision.NOT_LIVE;
        activeHarness.notLiveReloadStatus = "active";

        assertThat(activeHarness.execute().status()).isEqualTo("active");
        assertThat(activeHarness.generatorRequests).isEmpty();

        var rejectedHarness = new Harness(2);
        rejectedHarness.startDecision = GenerationStartDecision.NOT_LIVE;
        rejectedHarness.notLiveReloadStatus = "rejected";

        assertThatThrownBy(rejectedHarness::execute)
                .isInstanceOf(CustomSceneGenerationOrchestrator.GenerationExecutionException.class)
                .hasMessage("generation_not_live");
        assertThat(rejectedHarness.generatorRequests).isEmpty();
    }

    @Test
    void retrieverRuntimeCompletesAttemptAndExpiresParent() {
        var harness = new Harness(2);
        harness.retrieverFailure = new IllegalArgumentException("retrieval failed");

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("expired");
        assertThat(result.generationErrorCode()).isEqualTo("evidence_failure");
        assertThat(harness.completedAttempts).singleElement().satisfies(completed ->
                assertThat(completed.outcome()).isEqualTo("evidence_failure"));
    }

    @Test
    void reusedBundleRuntimeCompletesRepairAttemptAndExpiresParent() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.repairable(GeneratedOutputViolationCode.MISSING_TPR_ACTION));
        harness.reusedBundleFailure = new IllegalArgumentException("reused bundle invalid");

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("expired");
        assertThat(harness.completedAttempts).extracting(GenerationAttemptAuditPort.AttemptCompleted::outcome)
                .containsExactly("repairable_violation", "evidence_failure");
        assertThat(harness.repairRequests).isEmpty();
    }

    @Test
    void repairedAttemptAuditContainsOnlyCurrentAttemptCodes() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.repairable(GeneratedOutputViolationCode.MISSING_TPR_ACTION));
        harness.gates.add(GateSpec.pass());
        harness.judges.add(pass());

        harness.execute();

        assertThat(harness.completedAttempts).hasSize(2);
        assertThat(harness.completedAttempts.get(0).violationCodes()).containsExactly("MISSING_TPR_ACTION");
        assertThat(harness.completedAttempts.get(1).violationCodes()).isEmpty();
        assertThat(harness.repairRequests).singleElement().satisfies(request ->
                assertThat(request.repairPackage().violationCodes()).containsExactly("MISSING_TPR_ACTION"));
    }

    @Test
    void supportedJudgeGapRefreshesEvidenceBeforeRepair() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.pass());
        harness.gates.add(GateSpec.pass());
        harness.judges.add(repair(EvidenceGapCode.SCENE_ALIGNMENT_EVIDENCE_MISSING));
        harness.judges.add(pass());

        harness.execute();

        assertThat(harness.events).containsSubsequence(
                "attempt-completed:1:judge_repair",
                "attempt-started:2:repair",
                "bundle:refreshed:2",
                "repair:2");
        assertThat(harness.repairRequests).singleElement().satisfies(request ->
                assertThat(request.evidenceBundleId()).isEqualTo(harness.refreshedBundle.evidenceBundleId()));
    }

    @Test
    void unsupportedJudgeGapReusesEvidenceAndAuditsInconsistencyOnCurrentAttempt() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.pass());
        harness.gates.add(GateSpec.pass());
        harness.judges.add(repair(EvidenceGapCode.TPR_QUALITY_EVIDENCE_MISSING));
        harness.judges.add(pass());

        harness.execute();

        assertThat(harness.events).contains("bundle:reused:2").doesNotContain("bundle:refreshed:2");
        assertThat(harness.completedAttempts.get(0).violationCodes()).containsExactly("TPR_QUALITY_FAILED");
        assertThat(harness.completedAttempts.get(1).violationCodes())
                .containsExactly("judge_evidence_action_inconsistent");
        assertThat(harness.repairRequests).singleElement().satisfies(request ->
                assertThat(request.repairPackage().violationCodes())
                        .containsExactly("TPR_QUALITY_FAILED", "judge_evidence_action_inconsistent"));
    }

    @Test
    void insufficientRefreshedEvidenceExpiresWithoutInvokingRepair() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.pass());
        harness.judges.add(repair(EvidenceGapCode.SCENE_ALIGNMENT_EVIDENCE_MISSING));
        harness.refreshedBundleFailure = new IllegalStateException("minimum evidence policy is not satisfied");

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("expired");
        assertThat(result.generationErrorCode()).isEqualTo("insufficient_evidence");
        assertThat(harness.repairRequests).isEmpty();
        assertThat(harness.completedAttempts).extracting(GenerationAttemptAuditPort.AttemptCompleted::outcome)
                .containsExactly("judge_repair", "insufficient_evidence");
    }

    @Test
    void validatorRuntimeCompletesAttemptAndExpiresParent() {
        var harness = new Harness(2);
        harness.validatorFailure = new IllegalStateException("validator failure");

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("expired");
        assertThat(result.generationErrorCode()).isEqualTo("validation_failure");
        assertThat(harness.completedAttempts).singleElement().satisfies(completed ->
                assertThat(completed.outcome()).isEqualTo("validation_failure"));
    }

    @Test
    void activationRuntimeExpiresParentAfterPassedAttempt() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.pass());
        harness.judges.add(pass());
        harness.activationFailure = new IllegalStateException("activation failure");

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("expired");
        assertThat(result.generationErrorCode()).isEqualTo("activation_failure");
        assertThat(harness.completedAttempts).singleElement().satisfies(completed ->
                assertThat(completed.outcome()).isEqualTo("activation_failure"));
    }

    @Test
    void activationRemainsActiveWhenAttemptCompletionAuditFails() {
        var harness = new Harness(2);
        harness.gates.add(GateSpec.pass());
        harness.judges.add(pass());
        harness.attemptCompletionFailure = new IllegalStateException("audit unavailable");

        var result = harness.execute();

        assertThat(result.status()).isEqualTo("active");
        assertThat(result.generationErrorCode()).isNull();
        assertThat(harness.completedAttempts).isEmpty();
        assertThat(harness.events).containsExactly(
                "attempt-started:1:generator",
                "retrieve:initial",
                "bundle:initial:1",
                "quota:start",
                "generator:1",
                "gate:1",
                "judge:1",
                "activate",
                "attempt-completion-failed:1:passed");
    }

    private static SuggestedJudgeResult pass() {
        return new SuggestedJudgeResult(
                JudgeVerdict.PASS, dimensions(), List.of(), List.of(), List.of(), 0.95d);
    }

    private static SuggestedJudgeResult repair() {
        return repair((EvidenceGapCode[]) null);
    }

    private static SuggestedJudgeResult repair(EvidenceGapCode... evidenceGapCodes) {
        var dimensions = dimensions();
        dimensions.put(JudgeDimension.TPR_QUALITY, DimensionResult.FAIL);
        return new SuggestedJudgeResult(
                JudgeVerdict.REPAIR,
                dimensions,
                List.of(JudgeDimension.TPR_QUALITY.violationCode()),
                List.of(RepairDirective.REPAIR_TPR_QUALITY),
                evidenceGapCodes == null ? List.of() : List.of(evidenceGapCodes),
                0.85d);
    }

    private static SuggestedJudgeResult abstain() {
        var dimensions = dimensions();
        dimensions.put(JudgeDimension.TPR_QUALITY, DimensionResult.ABSTAIN);
        return new SuggestedJudgeResult(
                JudgeVerdict.ABSTAIN,
                dimensions,
                List.of(),
                List.of(RepairDirective.REPAIR_TPR_QUALITY),
                List.of(),
                0.65d);
    }

    private static SuggestedJudgeResult reject() {
        var dimensions = dimensions();
        dimensions.put(JudgeDimension.AGE_SUITABILITY, DimensionResult.FAIL);
        return new SuggestedJudgeResult(
                JudgeVerdict.REJECT,
                dimensions,
                List.of(JudgeDimension.AGE_SUITABILITY.violationCode()),
                List.of(),
                List.of(),
                0.90d);
    }

    private static EnumMap<JudgeDimension, DimensionResult> dimensions() {
        var dimensions = new EnumMap<JudgeDimension, DimensionResult>(JudgeDimension.class);
        for (var dimension : JudgeDimension.values()) {
            dimensions.put(dimension, DimensionResult.PASS);
        }
        return dimensions;
    }

    private record GateSpec(List<GeneratedOutputViolationCode> terminal, List<GeneratedOutputViolationCode> repairable) {
        private static GateSpec pass() {
            return new GateSpec(List.of(), List.of());
        }

        private static GateSpec repairable(GeneratedOutputViolationCode code) {
            return new GateSpec(List.of(), List.of(code));
        }

        private static GateSpec terminal(GeneratedOutputViolationCode code) {
            return new GateSpec(List.of(code), List.of());
        }
    }

    private static final class Harness {
        private final List<String> events = new ArrayList<>();
        private final ArrayDeque<GateSpec> gates = new ArrayDeque<>();
        private final ArrayDeque<SuggestedJudgeResult> judges = new ArrayDeque<>();
        private final List<GeneratorRequest> generatorRequests = new ArrayList<>();
        private final List<CustomSceneRepairer.RepairRequest> repairRequests = new ArrayList<>();
        private final List<JudgeRequest> judgeRequests = new ArrayList<>();
        private final List<GenerationAttemptAuditPort.AttemptCompleted> completedAttempts = new ArrayList<>();
        private final List<FrozenEvidenceBundle> bundles = new ArrayList<>();
        private final FrozenEvidenceBundle refreshedBundle;
        private final CustomSceneGenerationOrchestrator orchestrator;
        private final CustomSceneGenerationOrchestrator.GenerationExecution execution;
        private int gateNumber;
        private boolean generatorExhausted;
        private boolean judgeExhausted;
        private boolean repairExhausted;
        private boolean generatorFallback;
        private boolean initialEvidenceInsufficient;
        private RuntimeException retrieverFailure;
        private RuntimeException reusedBundleFailure;
        private RuntimeException refreshedBundleFailure;
        private RuntimeException validatorFailure;
        private RuntimeException activationFailure;
        private RuntimeException attemptStartFailure;
        private RuntimeException attemptCompletionFailure;
        private GenerationStartDecision startDecision = GenerationStartDecision.STARTED;
        private String notLiveReloadStatus;

        private Harness(int attemptLimit) {
            var commands = mock(PracticeGeneratedContentCommands.class);
            var queryMapper = mock(PracticeGeneratedContentQueryMapper.class);
            var generator = mock(CustomSceneGenerator.class);
            var repairer = mock(CustomSceneRepairer.class);
            var validator = mock(CustomSceneGeneratedContentValidator.class);
            var judge = mock(CustomSceneQualityJudge.class);
            var retriever = mock(CustomSceneEvidenceRetriever.class);
            var bundleFactory = mock(EvidenceBundleFactory.class);
            var attemptAudit = mock(GenerationAttemptAuditPort.class);
            var registry = new VersionedResourceRegistry(new DefaultResourceLoader());
            var clock = Clock.fixed(Instant.parse("2026-07-18T12:00:00Z"), ZoneOffset.UTC);
            var keyFactory = new PracticeGeneratedContentKeyFactory(
                    new PracticeGeneratedContentOwnerProperties("owner-key-v1", "x".repeat(32)));
            executionDraft = draft(attemptLimit, registry);

            bundles.add(bundle(1, null, RetrievalStatus.INITIAL));
            bundles.add(bundle(2, bundles.get(0).evidenceBundleId(), RetrievalStatus.REUSED));
            refreshedBundle = bundle(2, null, RetrievalStatus.REFRESHED);

            doAnswer(invocation -> {
                var started = invocation.getArgument(0, GenerationAttemptAuditPort.AttemptStarted.class);
                if (attemptStartFailure != null) {
                    events.add("attempt-start-failed:" + started.attemptNumber() + ":" + started.attemptType());
                    throw attemptStartFailure;
                }
                events.add("attempt-started:" + started.attemptNumber() + ":" + started.attemptType());
                return null;
            }).when(attemptAudit).startAttempt(any());
            doAnswer(invocation -> {
                var completed = invocation.getArgument(0, GenerationAttemptAuditPort.AttemptCompleted.class);
                if (attemptCompletionFailure != null) {
                    events.add("attempt-completion-failed:" + completed.attemptNumber() + ":" + completed.outcome());
                    throw attemptCompletionFailure;
                }
                completedAttempts.add(completed);
                events.add("attempt-completed:" + completed.attemptNumber() + ":" + completed.outcome());
                return null;
            }).when(attemptAudit).completeAttempt(any());
            when(retriever.retrieve(any())).thenAnswer(invocation -> {
                events.add("retrieve:initial");
                if (retrieverFailure != null) {
                    throw retrieverFailure;
                }
                var request = invocation.getArgument(0, com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceRetrievalRequest.class);
                return new EvidenceRetrievalResult(
                        List.of(),
                        request.retrievalTraceId(),
                        initialEvidenceInsufficient ? RetrievalStatus.INSUFFICIENT : RetrievalStatus.INITIAL);
            });
            when(bundleFactory.createInitial(anyString(), anyInt(), any())).thenAnswer(invocation -> {
                events.add("bundle:initial:" + invocation.getArgument(1));
                return bundle(invocation.getArgument(1));
            });
            when(bundleFactory.deriveReused(anyString(), anyInt(), any())).thenAnswer(invocation -> {
                events.add("bundle:reused:" + invocation.getArgument(1));
                if (reusedBundleFailure != null) {
                    throw reusedBundleFailure;
                }
                return bundle(invocation.getArgument(1));
            });
            when(bundleFactory.createRefreshed(anyString(), anyInt(), any())).thenAnswer(invocation -> {
                events.add("bundle:refreshed:" + invocation.getArgument(1));
                if (refreshedBundleFailure != null) {
                    throw refreshedBundleFailure;
                }
                return refreshedBundle;
            });
            when(commands.startGeneration(anyString(), any(), anyInt(), any())).thenAnswer(invocation -> {
                events.add("quota:start");
                if (startDecision == GenerationStartDecision.NOT_LIVE && notLiveReloadStatus != null) {
                    executionDraft.setStatus(notLiveReloadStatus);
                    if (!"active".equals(notLiveReloadStatus)) {
                        executionDraft.setNormalizedSceneText(null);
                    }
                }
                return startDecision;
            });
            when(generator.generate(any())).thenAnswer(invocation -> {
                var request = invocation.getArgument(0, GeneratorRequest.class);
                generatorRequests.add(request);
                if (generatorFallback) {
                    events.add("generator-provider:0");
                    events.add("generator-provider:1");
                }
                events.add("generator:" + request.attemptNumber());
                if (generatorExhausted) {
                    throw new ProvidersExhaustedException(UUID.randomUUID());
                }
                return candidate();
            });
            when(repairer.repair(any())).thenAnswer(invocation -> {
                var request = invocation.getArgument(0, CustomSceneRepairer.RepairRequest.class);
                repairRequests.add(request);
                events.add("repair:" + request.attemptNumber());
                if (repairExhausted) {
                    throw new ProvidersExhaustedException(UUID.randomUUID());
                }
                return candidate();
            });
            when(validator.evaluate(any(), any(CustomSceneGenerator.ContentConstraints.class),
                    any(CustomSceneGeneratedContentValidator.GeneratedOutputValidationContext.class)))
                    .thenAnswer(invocation -> {
                        events.add("gate:" + (++gateNumber));
                        if (validatorFailure != null) {
                            throw validatorFailure;
                        }
                        var spec = gates.removeFirst();
                        return new GeneratedOutputGateResult(invocation.getArgument(0), spec.terminal(), spec.repairable());
                    });
            when(judge.judge(any())).thenAnswer(invocation -> {
                var request = invocation.getArgument(0, JudgeRequest.class);
                judgeRequests.add(request);
                events.add("judge:" + request.attemptNumber());
                if (judgeExhausted) {
                    throw new ProvidersExhaustedException(UUID.randomUUID());
                }
                return judges.removeFirst();
            });
            when(commands.activate(any())).thenAnswer(invocation -> {
                events.add("activate");
                if (activationFailure != null) {
                    throw activationFailure;
                }
                return Optional.of(invocation.getArgument(0, PracticeGeneratedContentEntity.class));
            });
            doAnswer(invocation -> {
                events.add("reject:" + invocation.getArgument(1) + ":" + invocation.getArgument(2));
                transition(executionDraft, "rejected", invocation.getArgument(1), invocation.getArgument(2));
                return null;
            }).when(commands).reject(anyString(), anyString(), anyBoolean(), any(), any());
            doAnswer(invocation -> {
                events.add("expire:" + invocation.getArgument(1) + ":" + invocation.getArgument(2));
                transition(executionDraft, "expired", invocation.getArgument(1), invocation.getArgument(2));
                return null;
            }).when(commands).expire(anyString(), anyString(), anyBoolean(), any(), any());
            when(queryMapper.findByGeneratedContentId(anyString())).thenAnswer(invocation -> executionDraft);

            orchestrator = new CustomSceneGenerationOrchestrator(
                    commands,
                    queryMapper,
                    generator,
                    repairer,
                    validator,
                    judge,
                    new JudgeVerdictCalculator(),
                    retriever,
                    bundleFactory,
                    attemptAudit,
                    keyFactory,
                    clock);
            execution = new CustomSceneGenerationOrchestrator.GenerationExecution(
                    executionDraft,
                    NOW.minusDays(1),
                    10,
                    registry.currentGenerationProfile(),
                    registry.qualityRubric(),
                    Set.copyOf(registry.minimumEvidencePolicy().requiredClaimCoverage()),
                    CustomSceneGenerator.ContentConstraints.defaults());
        }

        private final PracticeGeneratedContentEntity executionDraft;

        private PracticeGeneratedContentEntity execute() {
            return orchestrator.execute(execution);
        }

        private FrozenEvidenceBundle bundle(int attemptNumber) {
            return bundles.get(attemptNumber - 1);
        }

        private FrozenEvidenceBundle bundle(int attemptNumber, UUID derivedFrom, RetrievalStatus status) {
            return new FrozenEvidenceBundle(
                    UUID.nameUUIDFromBytes(("bundle-" + attemptNumber).getBytes(java.nio.charset.StandardCharsets.UTF_8)),
                    "pgc_orchestrator_test",
                    attemptNumber,
                    derivedFrom,
                    status,
                    status == RetrievalStatus.REUSED ? null : UUID.randomUUID(),
                    "evidence-v1",
                    "e".repeat(64),
                    "sanitizer-v1",
                    Integer.toHexString(attemptNumber).repeat(64).substring(0, 64),
                    List.of(),
                    NOW);
        }

        private static PracticeGeneratedContentEntity draft(int attemptLimit, VersionedResourceRegistry registry) {
            var profile = registry.currentGenerationProfile();
            var rubric = registry.qualityRubric();
            var policy = registry.minimumEvidencePolicy();
            var draft = new PracticeGeneratedContentEntity();
            draft.setGeneratedContentId("pgc_orchestrator_test");
            draft.setOwnerScope("installation");
            draft.setOwnerKey("owner_test");
            draft.setOwnerKeyVersion("owner-key-v1");
            draft.setInstallationRefHash("installation_test");
            draft.setSurface("onboarding");
            draft.setMode("custom_scene");
            draft.setRequestFingerprint("fp_test");
            draft.setNormalizedSceneText("给宝宝穿鞋");
            draft.setAgeRange("m7_11");
            draft.setParentGoal("calmer_care");
            draft.setLocale("zh-CN");
            draft.setStatus("draft");
            draft.setGenerationProfileVersion(profile.version());
            draft.setGenerationProfileHash(profile.contentHash());
            draft.setRubricVersion(rubric.version());
            draft.setRubricContentHash(rubric.contentHash());
            draft.setEvidencePolicyVersion(policy.version());
            draft.setEvidencePolicyContentHash(policy.contentHash());
            draft.setProviderRoutingPolicyVersion("routing-v1");
            draft.setProviderRoutingPolicyHash("r".repeat(64));
            draft.setGenerationAttemptLimit(attemptLimit);
            draft.setContentRefreshEpoch(1);
            draft.setContentVersion(1);
            draft.setGenerationExpiresAt(NOW.plusMinutes(5));
            draft.setRetentionExpiresAt(NOW.plusDays(30));
            draft.setCreatedAt(NOW);
            draft.setUpdatedAt(NOW);
            return draft;
        }

        private static GeneratedPracticeContentCandidate candidate() {
            return new GeneratedPracticeContentCandidate(
                    "日常照护", "穿鞋出门", "Shoes on", "拿起鞋子。", "慢慢说。",
                    "Shoes on.", "穿鞋出门。", "shoes on", "starter", "agentic_search");
        }

        private static void transition(
                PracticeGeneratedContentEntity entity,
                String status,
                String errorCode,
                boolean retryable
        ) {
            entity.setStatus(status);
            entity.setNormalizedSceneText(null);
            entity.setGenerationErrorCode(errorCode);
            entity.setGenerationErrorRetryable(retryable);
            entity.setUpdatedAt(NOW);
        }
    }
}
