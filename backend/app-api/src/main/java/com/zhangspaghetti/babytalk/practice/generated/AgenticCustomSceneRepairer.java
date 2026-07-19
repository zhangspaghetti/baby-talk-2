package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.agentic.OperationRequest;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiCapability;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiOperationRunner;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller.StructuredOutputInvalidException;
import com.zhangspaghetti.babytalk.practice.agentic.config.GenerationProfile;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratedPracticeContentCandidate;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceSummary;
import com.zhangspaghetti.babytalk.practice.generated.quality.TypedRepairPackage;
import java.util.List;
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
public class AgenticCustomSceneRepairer implements CustomSceneRepairer {

    private static final String SUBJECT_TYPE = "generated_content";
    private static final String TRUSTED_GENERATION_SOURCE = "agentic_search";

    private final PracticeAiOperationRunner operationRunner;
    private final PracticeAiStructuredOutputCaller structuredOutputCaller;
    private final VersionedResourceRegistry resourceRegistry;
    private final ObjectMapper objectMapper;

    @org.springframework.beans.factory.annotation.Autowired
    public AgenticCustomSceneRepairer(
            PracticeAiOperationRunner operationRunner,
            PracticeAiStructuredOutputCaller structuredOutputCaller,
            VersionedResourceRegistry resourceRegistry
    ) {
        this(operationRunner, structuredOutputCaller, resourceRegistry, new ObjectMapper());
    }

    AgenticCustomSceneRepairer(
            PracticeAiOperationRunner operationRunner,
            PracticeAiStructuredOutputCaller structuredOutputCaller,
            VersionedResourceRegistry resourceRegistry,
            ObjectMapper objectMapper
    ) {
        this.operationRunner = Objects.requireNonNull(operationRunner, "operationRunner");
        this.structuredOutputCaller = Objects.requireNonNull(structuredOutputCaller, "structuredOutputCaller");
        this.resourceRegistry = Objects.requireNonNull(resourceRegistry, "resourceRegistry");
        this.objectMapper = Objects.requireNonNull(objectMapper, "objectMapper");
    }

    @Override
    public GeneratedPracticeContentCandidate repair(RepairRequest request) {
        Objects.requireNonNull(request, "request");
        var repairPackage = request.repairPackage();
        var currentProfile = Objects.requireNonNull(
                resourceRegistry.currentGenerationProfile(), "currentGenerationProfile");
        if (!currentProfile.equals(repairPackage.generationProfile())) {
            throw new IllegalArgumentException(
                    "repair request generation profile must match current registry profile");
        }
        var repairPrompt = currentProfile.repairPrompt();
        var systemPrompt = resourceRegistry.promptText(VersionedResourceRegistry.PromptKind.REPAIR);
        var userPrompt = objectMapper.writeValueAsString(new RepairPromptPayload(
                request.attemptNumber(),
                request.locale(),
                repairPackage.displayText(),
                repairPackage.ageRange(),
                repairPackage.parentGoal(),
                candidatePayload(repairPackage.previousCandidate()),
                repairPackage.effectiveVerdict().name(),
                repairPackage.failedDimensions().stream().map(Enum::name).toList(),
                repairPackage.violationCodes(),
                repairPackage.repairDirectives().stream().map(Enum::name).toList(),
                repairPackage.evidenceSummaries().stream().map(EvidenceSummary::sanitizedSummary).toList(),
                generationProfilePayload(currentProfile)));
        var result = operationRunner.execute(new OperationRequest<>(
                PracticeAiCapability.CUSTOM_SCENE_REPAIR,
                SUBJECT_TYPE,
                request.generatedContentId(),
                request.generatedContentId(),
                request.attemptNumber(),
                request.evidenceBundleId(),
                repairPrompt.version(),
                repairPrompt.contentHash(),
                currentProfile.evidencePolicy().version(),
                currentProfile.evidencePolicy().contentHash(),
                provider -> new OperationRequest.ProviderInvocationResult<>(
                        structuredOutputCaller.call(
                                provider,
                                systemPrompt,
                                userPrompt,
                                RepairWireResponse.class),
                        null)));
        return result.value().toCandidate();
    }

    private CandidatePayload candidatePayload(GeneratedPracticeContentCandidate candidate) {
        return new CandidatePayload(
                candidate.spaceTitleZh(),
                candidate.activityTitleZh(),
                candidate.sceneTagEn(),
                candidate.tprActionZh(),
                candidate.deliveryGuidanceZh(),
                candidate.englishText(),
                candidate.chineseText(),
                candidate.pronunciationHint(),
                candidate.difficulty());
    }

    private GenerationProfilePayload generationProfilePayload(GenerationProfile profile) {
        return new GenerationProfilePayload(
                profile.version(),
                profile.repairPrompt().version(),
                profile.strategyVersion(),
                profile.contentSafetyPolicyVersion(),
                profile.generatedOutputSchemaVersion());
    }

    private record RepairPromptPayload(
            int attemptNumber,
            String locale,
            String displayText,
            String ageRange,
            String parentGoal,
            CandidatePayload previousCandidate,
            String effectiveVerdict,
            List<String> failedDimensions,
            List<String> violationCodes,
            List<String> repairDirectives,
            List<String> orderedSanitizedEvidenceSummaries,
            GenerationProfilePayload generationProfile
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
            String difficulty
    ) {
    }

    private record GenerationProfilePayload(
            String version,
            String repairPromptVersion,
            String strategyVersion,
            String contentSafetyPolicyVersion,
            String generatedOutputSchemaVersion
    ) {
    }

    public record RepairWireResponse(
            String spaceTitleZh,
            String activityTitleZh,
            String sceneTagEn,
            String tprActionZh,
            String deliveryGuidanceZh,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String difficulty
    ) {
        public RepairWireResponse {
            try {
                requireNonBlank(spaceTitleZh, "spaceTitleZh");
                requireNonBlank(activityTitleZh, "activityTitleZh");
                requireNonBlank(sceneTagEn, "sceneTagEn");
                requireNonBlank(tprActionZh, "tprActionZh");
                requireNonBlank(deliveryGuidanceZh, "deliveryGuidanceZh");
                requireNonBlank(englishText, "englishText");
                requireNonBlank(chineseText, "chineseText");
                requireNonBlank(difficulty, "difficulty");
            } catch (StructuredOutputInvalidException exception) {
                throw exception;
            } catch (RuntimeException exception) {
                throw new StructuredOutputInvalidException();
            }
        }

        GeneratedPracticeContentCandidate toCandidate() {
            return new GeneratedPracticeContentCandidate(
                    spaceTitleZh,
                    activityTitleZh,
                    sceneTagEn,
                    tprActionZh,
                    deliveryGuidanceZh,
                    englishText,
                    chineseText,
                    pronunciationHint,
                    difficulty,
                    TRUSTED_GENERATION_SOURCE);
        }

        private static void requireNonBlank(String value, String field) {
            if (value == null || value.isBlank()) {
                throw new StructuredOutputInvalidException();
            }
        }
    }
}
