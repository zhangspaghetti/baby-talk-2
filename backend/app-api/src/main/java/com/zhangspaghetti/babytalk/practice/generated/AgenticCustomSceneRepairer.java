package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.agentic.OperationRequest;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiCapability;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiOperationRunner;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller;
import com.zhangspaghetti.babytalk.practice.agentic.config.GenerationProfile;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
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
    public GeneratedCareMomentBundle repairCareMoment(RepairRequest request) {
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
                repairPackage.previousBundle(),
                repairPackage.effectiveVerdict().name(),
                repairPackage.failedDimensions().stream().map(Enum::name).toList(),
                repairPackage.violationCodes(),
                repairPackage.branchRequirements().stream()
                        .map(requirement -> new BranchRequirementPayload(
                                requirement.branch().wireValue(),
                                requirement.violationCodes().stream().map(Enum::name).toList()))
                        .toList(),
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
                provider -> {
                    var content = OperationRequest.atFailureStage(
                            OperationRequest.ProviderFailureStage.PROVIDER_RESPONSE_BINDING,
                            () -> structuredOutputCaller.callRaw(
                                provider,
                                systemPrompt,
                                userPrompt,
                                CompleteGeneratedBundle.ProviderResponse.class,
                                currentProfile.minimumCompleteBundleOutputTokens()));
                    var wire = OperationRequest.atFailureStage(
                            OperationRequest.ProviderFailureStage.CONTENT_STRICT_PARSER,
                            () -> CompleteGeneratedBundle.ProviderResponse.parse(content));
                    return new OperationRequest.ProviderInvocationResult<>(wire, null);
                }));
        return GeneratedCareMomentBundle.fromCompleteBundle(result.value().toCompleteBundle(
                new CompleteGeneratedBundle.ProviderProvenance(
                        CompleteGeneratedBundle.ProviderOrigin.PROVIDER_REPAIRED,
                        result.providerName(),
                        result.modelName(),
                        request.attemptNumber())));
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
            CompleteGeneratedBundle previousBundle,
            String effectiveVerdict,
            List<String> failedDimensions,
            List<String> violationCodes,
            List<BranchRequirementPayload> branchRequirements,
            List<String> repairDirectives,
            List<String> orderedSanitizedEvidenceSummaries,
            GenerationProfilePayload generationProfile
    ) {
    }

    private record BranchRequirementPayload(
            String branch,
            List<String> violationCodes
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
}
