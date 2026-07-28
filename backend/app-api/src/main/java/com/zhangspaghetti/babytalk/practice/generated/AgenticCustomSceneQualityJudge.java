package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.agentic.OperationRequest;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiCapability;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiOperationRunner;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller.StructuredOutputInvalidException;
import com.zhangspaghetti.babytalk.practice.agentic.config.QualityRubric;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.generated.quality.DimensionResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.EffectiveJudgeResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.EvidenceGapCode;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeDimension;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeResultAuditPort;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdict;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdictCalculator;
import com.zhangspaghetti.babytalk.practice.generated.quality.RepairDirective;
import com.zhangspaghetti.babytalk.practice.generated.quality.SuggestedJudgeResult;
import java.util.List;
import java.util.Map;
import java.util.EnumSet;
import java.util.Objects;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import tools.jackson.databind.ObjectMapper;

@Service
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "agentic"
)
public class AgenticCustomSceneQualityJudge implements CustomSceneQualityJudge {

    private static final String SUBJECT_TYPE = "generated_content";

    private final PracticeAiOperationRunner operationRunner;
    private final PracticeAiStructuredOutputCaller structuredOutputCaller;
    private final VersionedResourceRegistry resourceRegistry;
    private final JudgeVerdictCalculator verdictCalculator;
    private final JudgeResultAuditPort auditPort;
    private final ObjectMapper objectMapper;

    @org.springframework.beans.factory.annotation.Autowired
    public AgenticCustomSceneQualityJudge(
            PracticeAiOperationRunner operationRunner,
            PracticeAiStructuredOutputCaller structuredOutputCaller,
            VersionedResourceRegistry resourceRegistry,
            JudgeVerdictCalculator verdictCalculator,
            JudgeResultAuditPort auditPort
    ) {
        this(operationRunner, structuredOutputCaller, resourceRegistry, verdictCalculator, auditPort, new ObjectMapper());
    }

    AgenticCustomSceneQualityJudge(
            PracticeAiOperationRunner operationRunner,
            PracticeAiStructuredOutputCaller structuredOutputCaller,
            VersionedResourceRegistry resourceRegistry,
            JudgeVerdictCalculator verdictCalculator,
            JudgeResultAuditPort auditPort,
            ObjectMapper objectMapper
    ) {
        this.operationRunner = Objects.requireNonNull(operationRunner, "operationRunner");
        this.structuredOutputCaller = Objects.requireNonNull(structuredOutputCaller, "structuredOutputCaller");
        this.resourceRegistry = Objects.requireNonNull(resourceRegistry, "resourceRegistry");
        this.verdictCalculator = Objects.requireNonNull(verdictCalculator, "verdictCalculator");
        this.auditPort = Objects.requireNonNull(auditPort, "auditPort");
        this.objectMapper = Objects.requireNonNull(objectMapper, "objectMapper");
    }

    @Override
    public SuggestedJudgeResult judge(JudgeRequest request) {
        Objects.requireNonNull(request, "request");
        var profile = Objects.requireNonNull(
                resourceRegistry.currentGenerationProfile(), "currentGenerationProfile");
        var rubric = Objects.requireNonNull(resourceRegistry.qualityRubric(), "qualityRubric");
        if (!request.rubricVersion().equals(rubric.version())
                || !request.rubricContentHash().equals(rubric.contentHash())
                || !profile.rubric().version().equals(rubric.version())
                || !profile.rubric().contentHash().equals(rubric.contentHash())) {
            throw new IllegalArgumentException("judge request rubric must match current registry rubric");
        }

        var systemPrompt = resourceRegistry.promptText(VersionedResourceRegistry.PromptKind.JUDGE);
        var userPrompt = userPrompt(request);
        var judgePrompt = profile.judgePrompt();
        var result = operationRunner.execute(new OperationRequest<>(
                PracticeAiCapability.CUSTOM_SCENE_QUALITY_JUDGE,
                SUBJECT_TYPE,
                request.generatedContentId(),
                request.generatedContentId(),
                request.attemptNumber(),
                request.evidenceBundleId(),
                judgePrompt.version(),
                judgePrompt.contentHash(),
                rubric.version(),
                rubric.contentHash(),
                provider -> {
                    var wire = structuredOutputCaller.call(
                            provider, systemPrompt, userPrompt, JudgeWireResponse.class);
                    var suggested = wire.toSuggested();
                    var effective = verdictCalculator.calculate(suggested, rubric);
                    return new OperationRequest.ProviderInvocationResult<>(
                            new JudgeEvaluation(suggested, effective), null);
                }));
        auditPort.persist(new JudgeResultAuditPort.JudgeAuditRecord(
                result.providerCallId(), result.value().suggested(), result.value().effective(), rubric));
        return result.value().suggested();
    }

    private String userPrompt(JudgeRequest request) {
        var candidate = request.candidate();
        return objectMapper.writeValueAsString(new JudgePromptPayload(
                request.displayText(),
                request.ageRange(),
                request.parentGoal(),
                new CandidatePayload(
                        candidate.spaceTitleZh(),
                        candidate.activityTitleZh(),
                        candidate.sceneTagEn(),
                        candidate.tprActionZh(),
                        candidate.deliveryGuidanceZh(),
                        candidate.englishText(),
                        candidate.chineseText(),
                        candidate.pronunciationHint(),
                        candidate.difficulty(),
                        candidate.generationSource()),
                request.careMoment().reactionSupports().entrySet().stream()
                        .sorted(java.util.Comparator.comparingInt(entry -> entry.getKey().ordinal()))
                        .map(entry -> new ReactionSupportPayload(
                                entry.getKey().wireValue(),
                                entry.getValue().englishText(),
                                entry.getValue().chineseText(),
                                entry.getValue().pronunciationHint(),
                                entry.getValue().tprActionZh(),
                                entry.getValue().deliveryGuidanceZh(),
                                entry.getValue().difficulty()))
                        .toList(),
                request.strategyIds(),
                request.communicationPrimitiveIds(),
                request.ageGuidanceTags(),
                request.safetyConstraintTags(),
                request.orderedSanitizedEvidenceSummaries(),
                request.rubricVersion(),
                request.rubricContentHash()));
    }

    private record JudgePromptPayload(
            String displayText,
            String ageRange,
            String parentGoal,
            CandidatePayload candidate,
            List<ReactionSupportPayload> reactionSupports,
            List<String> strategyIds,
            List<String> communicationPrimitiveIds,
            List<String> ageGuidanceTags,
            List<String> safetyConstraintTags,
            List<String> orderedSanitizedEvidenceSummaries,
            String rubricVersion,
            String rubricContentHash
    ) {
    }

    private record ReactionSupportPayload(
            String reactionType,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String tprActionZh,
            String deliveryGuidanceZh,
            String difficulty
    ) {
    }

    private record CandidatePayload(
            String spaceTitleZh,
            String activityTitleZh,
            String sceneTagEn,
            String tprActionZh,
            String deliveryGuidanceZh,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String difficulty,
            String generationSource
    ) {
    }

    private record JudgeEvaluation(
            SuggestedJudgeResult suggested,
            EffectiveJudgeResult effective
    ) {
    }

    public record JudgeWireResponse(
            JudgeVerdict suggestedVerdict,
            Map<JudgeDimension, DimensionResult> dimensionResults,
            List<String> violationCodes,
            List<RepairDirective> repairDirectives,
            List<EvidenceGapCode> evidenceGapCodes,
            Double confidence
    ) {
        public JudgeWireResponse {
            try {
                Objects.requireNonNull(suggestedVerdict, "suggestedVerdict");
                dimensionResults = Map.copyOf(Objects.requireNonNull(dimensionResults, "dimensionResults"));
                violationCodes = List.copyOf(Objects.requireNonNull(violationCodes, "violationCodes"));
                repairDirectives = List.copyOf(Objects.requireNonNull(repairDirectives, "repairDirectives"));
                evidenceGapCodes = List.copyOf(Objects.requireNonNull(evidenceGapCodes, "evidenceGapCodes"));
                if (!dimensionResults.keySet().equals(EnumSet.allOf(JudgeDimension.class))
                        || confidence == null
                        || !Double.isFinite(confidence)
                        || confidence < 0.0d
                        || confidence > 1.0d) {
                    throw new StructuredOutputInvalidException();
                }
            } catch (StructuredOutputInvalidException exception) {
                throw exception;
            } catch (RuntimeException exception) {
                throw new StructuredOutputInvalidException();
            }
        }

        public SuggestedJudgeResult toSuggested() {
            return new SuggestedJudgeResult(
                    suggestedVerdict,
                    dimensionResults,
                    violationCodes,
                    repairDirectives,
                    evidenceGapCodes,
                    confidence);
        }
    }
}
