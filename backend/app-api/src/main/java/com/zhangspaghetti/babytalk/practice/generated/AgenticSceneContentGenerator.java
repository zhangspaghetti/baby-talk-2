package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.agentic.OperationRequest;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiCapability;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiOperationRunner;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller;
import com.zhangspaghetti.babytalk.practice.agentic.ResolvedProvider;
import com.zhangspaghetti.babytalk.practice.agentic.config.GenerationProfile;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
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
public class AgenticSceneContentGenerator implements SceneContentGenerator {

    private static final String SUBJECT_TYPE = "generated_content";

    private final PracticeAiOperationRunner operationRunner;
    private final PracticeAiStructuredOutputCaller structuredOutputCaller;
    private final VersionedResourceRegistry resourceRegistry;
    private final ObjectMapper objectMapper;

    @org.springframework.beans.factory.annotation.Autowired
    public AgenticSceneContentGenerator(
            PracticeAiOperationRunner operationRunner,
            PracticeAiStructuredOutputCaller structuredOutputCaller,
            VersionedResourceRegistry resourceRegistry
    ) {
        this(operationRunner, structuredOutputCaller, resourceRegistry, new ObjectMapper());
    }

    AgenticSceneContentGenerator(
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
    public GeneratedCareMomentBundle generateCareMoment(GeneratorRequest request) {
        Objects.requireNonNull(request, "request");
        var evidenceBundle = Objects.requireNonNull(request.evidenceBundle(), "evidenceBundle");
        var generationProfile = Objects.requireNonNull(request.generationProfile(), "generationProfile");
        Objects.requireNonNull(request.constraints(), "constraints");
        if (!request.generatedContentId().equals(evidenceBundle.generatedContentId())
                || request.attemptNumber() != evidenceBundle.attemptNumber()) {
            throw new IllegalArgumentException("generator request and evidence bundle lineage must match");
        }

        var currentProfile = Objects.requireNonNull(
                resourceRegistry.currentGenerationProfile(), "currentGenerationProfile");
        if (!currentProfile.equals(generationProfile)) {
            throw new IllegalArgumentException(
                    "generator request generation profile must match current registry profile");
        }
        var evidencePolicy = currentProfile.evidencePolicy();
        if (!evidencePolicy.version().equals(evidenceBundle.evidencePolicyVersion())
                || !evidencePolicy.contentHash().equals(evidenceBundle.evidencePolicyContentHash())) {
            throw new IllegalArgumentException("generator evidence policy must match generation profile");
        }

        var systemPrompt = resourceRegistry.promptText(VersionedResourceRegistry.PromptKind.GENERATOR);
        var userPrompt = userPrompt(request, currentProfile);
        var generatorPrompt = currentProfile.generatorPrompt();
        var result = operationRunner.execute(new OperationRequest<>(
                PracticeAiCapability.CUSTOM_SCENE_GENERATOR,
                SUBJECT_TYPE,
                request.generatedContentId(),
                request.generatedContentId(),
                request.attemptNumber(),
                evidenceBundle.evidenceBundleId(),
                generatorPrompt.version(),
                generatorPrompt.contentHash(),
                evidencePolicy.version(),
                evidencePolicy.contentHash(),
                provider -> {
                    var content = OperationRequest.atFailureStage(
                            OperationRequest.ProviderFailureStage.PROVIDER_RESPONSE_BINDING,
                            () -> callGeneratorProvider(provider, systemPrompt, userPrompt, currentProfile));
                    var wire = OperationRequest.atFailureStage(
                            OperationRequest.ProviderFailureStage.CONTENT_STRICT_PARSER,
                            () -> CompleteGeneratedBundle.ProviderResponse.parse(content));
                    return new OperationRequest.ProviderInvocationResult<>(wire, null);
                }));
        return GeneratedCareMomentBundle.fromCompleteBundle(result.value().toCompleteBundle(
                new CompleteGeneratedBundle.ProviderProvenance(
                        CompleteGeneratedBundle.ProviderOrigin.PROVIDER_GENERATED,
                        result.providerName(),
                        result.modelName(),
                        request.attemptNumber())));
    }

    private String callGeneratorProvider(
            ResolvedProvider provider,
            String systemPrompt,
            String userPrompt,
            GenerationProfile profile
    ) {
        var inferencePolicy = profile.generatorInferencePolicy();
        if (inferencePolicy != null
                && inferencePolicy.matches(provider.providerType(), provider.modelName())) {
            return structuredOutputCaller.callRaw(
                    provider,
                    systemPrompt,
                    userPrompt,
                    CompleteGeneratedBundle.ProviderResponse.class,
                    profile.minimumCompleteBundleOutputTokens(),
                    inferencePolicy.reasoningEffort());
        }
        return structuredOutputCaller.callRaw(
                provider,
                systemPrompt,
                userPrompt,
                CompleteGeneratedBundle.ProviderResponse.class,
                profile.minimumCompleteBundleOutputTokens());
    }

    private String userPrompt(GeneratorRequest request, GenerationProfile profile) {
        var constraints = request.constraints();
        var payload = new GeneratorPromptPayload(
                request.generatedContentId(),
                request.attemptNumber(),
                request.displayText(),
                request.ageRange(),
                request.parentGoal(),
                request.locale(),
                new GenerationRequestContextPayload(
                        request.context().babyName(),
                        request.context().ageRange(),
                        request.context().parentGoal(),
                        request.context().locale(),
                        request.context().actorRole(),
                        request.context().recentPracticeCount(),
                        request.context().dominantReaction(),
                        request.context().recentActivitySummary()),
                new GenerationProfilePayload(
                        profile.version(),
                        profile.generatorPrompt().version(),
                        profile.strategyVersion(),
                        profile.contentSafetyPolicyVersion(),
                        profile.generatedOutputSchemaVersion()),
                new ContentConstraintsPayload(
                        constraints.maxEnglishWords(),
                        constraints.maxEnglishChars(),
                        constraints.maxChineseChars(),
                        constraints.maxCoachTipChars(),
                        constraints.maxSceneTagChars(),
                        constraints.allowedDifficulties().stream().sorted().toList(),
                        constraints.allowedGenerationSources().stream().sorted().toList()),
                CompleteGeneratedBundle.persistenceCodePointLimits(),
                request.evidenceBundle().items().stream()
                        .map(item -> item.sanitizedSummary())
                        .toList());
        return objectMapper.writeValueAsString(payload);
    }

    private record GeneratorPromptPayload(
            String generatedContentId,
            int attemptNumber,
            String displayText,
            String ageRange,
            String parentGoal,
            String locale,
            GenerationRequestContextPayload context,
            GenerationProfilePayload generationProfile,
            ContentConstraintsPayload constraints,
            CompleteGeneratedBundle.PersistenceCodePointLimits persistenceCodePointLimits,
            List<String> orderedSanitizedEvidenceSummaries
    ) {
    }

    private record GenerationRequestContextPayload(
            String babyName,
            String ageRange,
            String parentGoal,
            String locale,
            String actorRole,
            int recentPracticeCount,
            String dominantReaction,
            String recentActivitySummary
    ) {
    }

    private record GenerationProfilePayload(
            String version,
            String generatorPromptVersion,
            String strategyVersion,
            String contentSafetyPolicyVersion,
            String generatedOutputSchemaVersion
    ) {
    }

    private record ContentConstraintsPayload(
            int maxEnglishWords,
            int maxEnglishChars,
            int maxChineseChars,
            int maxCoachTipChars,
            int maxSceneTagChars,
            List<String> allowedDifficulties,
            List<String> allowedGenerationSources
    ) {
    }
}
