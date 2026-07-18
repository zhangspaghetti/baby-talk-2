package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.agentic.OperationRequest;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiCapability;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiOperationRunner;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
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
public class AgenticCustomSceneGenerator implements CustomSceneGenerator {

    private static final String SUBJECT_TYPE = "generated_content";
    private static final String TRUSTED_GENERATION_SOURCE = "agentic_search";

    private final PracticeAiOperationRunner operationRunner;
    private final PracticeAiStructuredOutputCaller structuredOutputCaller;
    private final VersionedResourceRegistry resourceRegistry;
    private final ObjectMapper objectMapper;

    @org.springframework.beans.factory.annotation.Autowired
    public AgenticCustomSceneGenerator(
            PracticeAiOperationRunner operationRunner,
            PracticeAiStructuredOutputCaller structuredOutputCaller,
            VersionedResourceRegistry resourceRegistry
    ) {
        this(operationRunner, structuredOutputCaller, resourceRegistry, new ObjectMapper());
    }

    AgenticCustomSceneGenerator(
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
    public GeneratedPracticeContentCandidate generate(GeneratorRequest request) {
        Objects.requireNonNull(request, "request");
        var evidenceBundle = Objects.requireNonNull(request.evidenceBundle(), "evidenceBundle");
        var generationProfile = Objects.requireNonNull(request.generationProfile(), "generationProfile");
        Objects.requireNonNull(request.constraints(), "constraints");
        if (!request.generatedContentId().equals(evidenceBundle.generatedContentId())
                || request.attemptNumber() != evidenceBundle.attemptNumber()) {
            throw new IllegalArgumentException("generator request and evidence bundle lineage must match");
        }

        var systemPrompt = resourceRegistry.promptText(VersionedResourceRegistry.PromptKind.GENERATOR);
        var userPrompt = userPrompt(request);
        var generatorPrompt = generationProfile.generatorPrompt();
        var evidencePolicy = generationProfile.evidencePolicy();
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
                    var wire = structuredOutputCaller.call(
                            provider,
                            systemPrompt,
                            userPrompt,
                            GeneratorWireResponse.class);
                    return new OperationRequest.ProviderInvocationResult<>(wire, null);
                }));
        return toCandidate(result.value());
    }

    private String userPrompt(GeneratorRequest request) {
        var profile = request.generationProfile();
        var constraints = request.constraints();
        var payload = new GeneratorPromptPayload(
                request.generatedContentId(),
                request.attemptNumber(),
                request.displayText(),
                request.ageRange(),
                request.parentGoal(),
                request.locale(),
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
                request.evidenceBundle().items().stream()
                        .map(item -> item.sanitizedSummary())
                        .toList());
        return objectMapper.writeValueAsString(payload);
    }

    private GeneratedPracticeContentCandidate toCandidate(GeneratorWireResponse wire) {
        return new GeneratedPracticeContentCandidate(
                wire.spaceTitleZh(),
                wire.activityTitleZh(),
                wire.sceneTagEn(),
                wire.tprActionZh(),
                wire.deliveryGuidanceZh(),
                wire.englishText(),
                wire.chineseText(),
                wire.pronunciationHint(),
                wire.difficulty(),
                TRUSTED_GENERATION_SOURCE);
    }

    private record GeneratorPromptPayload(
            String generatedContentId,
            int attemptNumber,
            String displayText,
            String ageRange,
            String parentGoal,
            String locale,
            GenerationProfilePayload generationProfile,
            ContentConstraintsPayload constraints,
            List<String> orderedSanitizedEvidenceSummaries
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

    public record GeneratorWireResponse(
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
        public GeneratorWireResponse {
            requireNonBlank(spaceTitleZh, "spaceTitleZh");
            requireNonBlank(activityTitleZh, "activityTitleZh");
            requireNonBlank(sceneTagEn, "sceneTagEn");
            requireNonBlank(tprActionZh, "tprActionZh");
            requireNonBlank(deliveryGuidanceZh, "deliveryGuidanceZh");
            requireNonBlank(englishText, "englishText");
            requireNonBlank(chineseText, "chineseText");
            requireNonBlank(difficulty, "difficulty");
        }

        private static void requireNonBlank(String value, String field) {
            if (value == null || value.isBlank()) {
                throw new IllegalArgumentException(field + " must be non-blank");
            }
        }
    }
}
