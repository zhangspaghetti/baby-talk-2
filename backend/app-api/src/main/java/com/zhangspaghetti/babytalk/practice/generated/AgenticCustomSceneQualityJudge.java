package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.agentic.OperationRequest;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiCapability;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiJsonSchemaPublisher;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiOperationRunner;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller.FinishReason;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller.StructuredOutputInvalidException;
import com.zhangspaghetti.babytalk.practice.agentic.ResolvedProvider;
import com.zhangspaghetti.babytalk.practice.agentic.config.GenerationProfile;
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
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.node.ObjectNode;

@Service
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "agentic"
)
public class AgenticCustomSceneQualityJudge implements CustomSceneQualityJudge {

    private static final String SUBJECT_TYPE = "generated_content";
    private static final List<String> ALLOWED_JUDGE_VIOLATION_CODES = java.util.Arrays.stream(
                    JudgeDimension.values())
            .map(JudgeDimension::violationCode)
            .toList();

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
                    var wire = callJudgeProvider(provider, systemPrompt, userPrompt, profile);
                    var suggested = wire.toSuggested();
                    var effective = verdictCalculator.calculate(suggested, rubric);
                    return new OperationRequest.ProviderInvocationResult<>(
                            new JudgeEvaluation(suggested, effective), null);
                }));
        auditPort.persist(new JudgeResultAuditPort.JudgeAuditRecord(
                result.providerCallId(), result.value().suggested(), result.value().effective(), rubric));
        return result.value().suggested();
    }

    private JudgeWireResponse callJudgeProvider(
            ResolvedProvider provider,
            String systemPrompt,
            String userPrompt,
            GenerationProfile profile
    ) {
        try {
            return callJudgeProviderOnce(provider, systemPrompt, userPrompt, profile);
        } catch (StructuredOutputInvalidException firstInvalidResponse) {
            if (firstInvalidResponse.providerResponseMetadata().finishReason() != FinishReason.STOP) {
                throw firstInvalidResponse;
            }
            return callJudgeProviderOnce(provider, systemPrompt, userPrompt, profile);
        }
    }

    private JudgeWireResponse callJudgeProviderOnce(
            ResolvedProvider provider,
            String systemPrompt,
            String userPrompt,
            GenerationProfile profile
    ) {
        if (profile.minimumQualityJudgeOutputTokens() == 0) {
            return structuredOutputCaller.call(
                    provider, systemPrompt, userPrompt, JudgeWireResponse.class);
        }
        var inferencePolicy = profile.qualityJudgeInferencePolicy();
        if (inferencePolicy != null
                && inferencePolicy.matches(provider.providerType(), provider.modelName())) {
            return structuredOutputCaller.call(
                    provider,
                    systemPrompt,
                    userPrompt,
                    JudgeWireResponse.class,
                    profile.minimumQualityJudgeOutputTokens(),
                    inferencePolicy.reasoningEffort());
        }
        return structuredOutputCaller.call(
                provider,
                systemPrompt,
                userPrompt,
                JudgeWireResponse.class,
                profile.minimumQualityJudgeOutputTokens());
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

    @PracticeAiJsonSchemaPublisher.RefinedBy(JudgeWireResponseSchemaRefiner.class)
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
                        || !ALLOWED_JUDGE_VIOLATION_CODES.containsAll(violationCodes)
                        || hasDuplicates(violationCodes)
                        || hasDuplicates(repairDirectives)
                        || hasDuplicates(evidenceGapCodes)
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

        private static boolean hasDuplicates(List<?> values) {
            return new LinkedHashSet<>(values).size() != values.size();
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

    /** Publishes every constraint enforced after Judge DTO conversion. */
    public static final class JudgeWireResponseSchemaRefiner
            implements PracticeAiJsonSchemaPublisher.SchemaRefiner {

        private static final String INVALID_SCHEMA = "custom_scene_quality_judge_provider_schema_invalid";
        private static final String JSON_SCHEMA_DRAFT = "https://json-schema.org/draft/2020-12/schema";
        private static final List<String> RESPONSE_FIELDS = List.of(
                "suggestedVerdict",
                "dimensionResults",
                "violationCodes",
                "repairDirectives",
                "evidenceGapCodes",
                "confidence");
        private static final List<String> DIMENSION_KEYS = java.util.Arrays.stream(JudgeDimension.values())
                .map(Enum::name)
                .toList();
        private static final List<String> DIMENSION_RESULTS = java.util.Arrays.stream(DimensionResult.values())
                .map(Enum::name)
                .toList();
        private static final List<String> VERDICTS = java.util.Arrays.stream(JudgeVerdict.values())
                .map(Enum::name)
                .toList();
        private static final List<String> REPAIR_DIRECTIVES = java.util.Arrays.stream(RepairDirective.values())
                .map(Enum::name)
                .toList();
        private static final List<String> EVIDENCE_GAP_CODES = java.util.Arrays.stream(EvidenceGapCode.values())
                .map(Enum::name)
                .toList();

        @Override
        public void refine(ObjectNode schema) {
            requireExactKeywords(
                    schema, "$schema", "type", "properties", "required", "additionalProperties");
            requireText(schema.get("$schema"), JSON_SCHEMA_DRAFT);
            requireType(schema, Set.of("object"));
            requireFalse(schema.get("additionalProperties"));
            requireRequiredFields(schema.get("required"), RESPONSE_FIELDS);

            var properties = requiredObject(schema, "properties");
            requireObjectFields(properties, RESPONSE_FIELDS);
            requireTextEnum(schema, requiredObject(properties, "suggestedVerdict"), VERDICTS);
            refineDimensions(requiredObject(properties, "dimensionResults"));
            refineViolations(requiredObject(properties, "violationCodes"));
            requireArrayEnum(
                    schema, requiredObject(properties, "repairDirectives"), REPAIR_DIRECTIVES);
            requireArrayEnum(
                    schema, requiredObject(properties, "evidenceGapCodes"), EVIDENCE_GAP_CODES);
            refineConfidence(requiredObject(properties, "confidence"));
        }

        private static void refineDimensions(ObjectNode dimensions) {
            requireExactKeywords(dimensions, "type");
            requireType(dimensions, Set.of("object"));

            var properties = dimensions.objectNode();
            for (var dimension : DIMENSION_KEYS) {
                properties.set(dimension, flatTextEnum(dimensions, DIMENSION_RESULTS));
            }
            dimensions.set("properties", properties);
            dimensions.set("required", textArray(dimensions, DIMENSION_KEYS));
            dimensions.put("additionalProperties", false);
        }

        private static void refineViolations(ObjectNode violations) {
            requireExactKeywords(violations, "type", "items");
            requireType(violations, Set.of("array"));
            var sourceItems = requiredObject(violations, "items");
            requireExactKeywords(sourceItems, "type");
            requireType(sourceItems, Set.of("string"));
            violations.set("items", flatTextEnum(violations, ALLOWED_JUDGE_VIOLATION_CODES));
            violations.put("maxItems", ALLOWED_JUDGE_VIOLATION_CODES.size());
        }

        private static void refineConfidence(ObjectNode confidence) {
            requireExactKeywords(confidence, "type", "format");
            requireType(confidence, Set.of("number"));
            requireText(confidence.get("format"), "double");
            confidence.put("type", "number");
            confidence.put("minimum", 0.0d);
            confidence.put("maximum", 1.0d);
        }

        private static void requireArrayEnum(
                ObjectNode root,
                ObjectNode arraySchema,
                List<String> expected
        ) {
            requireExactKeywords(arraySchema, "type", "items");
            requireType(arraySchema, Set.of("array"));
            requireTextEnum(root, arraySchema.get("items"), expected);
            arraySchema.put("maxItems", expected.size());
        }

        private static void requireTextEnum(
                ObjectNode root,
                JsonNode candidate,
                List<String> expected
        ) {
            var resolved = resolveLocalSchema(root, candidate);
            requireExactKeywords(resolved, "type", "enum");
            requireType(resolved, Set.of("string"));
            rejectCombinators(resolved);
            requireTextValues(resolved.get("enum"), expected);
        }

        private static ObjectNode resolveLocalSchema(ObjectNode root, JsonNode candidate) {
            if (!(candidate instanceof ObjectNode objectCandidate)) {
                throw invalidSchema();
            }
            if (!objectCandidate.has("$ref")) {
                return objectCandidate;
            }
            if (objectCandidate.size() != 1 || !objectCandidate.get("$ref").isTextual()) {
                throw invalidSchema();
            }
            var reference = objectCandidate.get("$ref").textValue();
            if (!reference.startsWith("#/")) {
                throw invalidSchema();
            }
            JsonNode resolved = root;
            for (var segment : reference.substring(2).split("/", -1)) {
                resolved = resolved.get(decodePointerSegment(segment));
                if (resolved == null) {
                    throw invalidSchema();
                }
            }
            if (!(resolved instanceof ObjectNode resolvedObject)) {
                throw invalidSchema();
            }
            return resolvedObject;
        }

        private static String decodePointerSegment(String encoded) {
            var decoded = new StringBuilder(encoded.length());
            for (var index = 0; index < encoded.length(); index++) {
                var character = encoded.charAt(index);
                if (character != '~') {
                    decoded.append(character);
                    continue;
                }
                if (++index >= encoded.length()) {
                    throw invalidSchema();
                }
                var escaped = encoded.charAt(index);
                if (escaped == '0') {
                    decoded.append('~');
                } else if (escaped == '1') {
                    decoded.append('/');
                } else {
                    throw invalidSchema();
                }
            }
            return decoded.toString();
        }

        private static ObjectNode requiredObject(JsonNode root, String... path) {
            JsonNode current = root;
            for (var segment : path) {
                current = current == null ? null : current.get(segment);
                if (!(current instanceof ObjectNode)) {
                    throw invalidSchema();
                }
            }
            return (ObjectNode) current;
        }

        private static void requireType(ObjectNode schema, Set<String> expected) {
            if (!typeNames(schema.get("type")).equals(expected)) {
                throw invalidSchema();
            }
            rejectCombinators(schema);
        }

        private static Set<String> typeNames(JsonNode type) {
            var names = new LinkedHashSet<String>();
            if (type == null) {
                throw invalidSchema();
            }
            if (type.isTextual()) {
                names.add(type.textValue());
            } else if (type.isArray()) {
                for (var value : type) {
                    if (!value.isTextual() || !names.add(value.textValue())) {
                        throw invalidSchema();
                    }
                }
            } else {
                throw invalidSchema();
            }
            return Set.copyOf(names);
        }

        private static void requireFalse(JsonNode value) {
            if (value == null || !value.isBoolean() || value.booleanValue()) {
                throw invalidSchema();
            }
        }

        private static void requireText(JsonNode value, String expected) {
            if (value == null || !value.isTextual() || !expected.equals(value.textValue())) {
                throw invalidSchema();
            }
        }

        private static void requireRequiredFields(JsonNode values, List<String> expected) {
            requireTextValues(values, expected);
        }

        private static void requireObjectFields(ObjectNode properties, List<String> expected) {
            var actual = properties.properties().stream()
                    .map(java.util.Map.Entry::getKey)
                    .collect(java.util.stream.Collectors.toCollection(LinkedHashSet::new));
            if (!actual.equals(new LinkedHashSet<>(expected))) {
                throw invalidSchema();
            }
        }

        private static void requireExactKeywords(ObjectNode schema, String... expected) {
            var actual = schema.properties().stream()
                    .map(java.util.Map.Entry::getKey)
                    .collect(java.util.stream.Collectors.toCollection(LinkedHashSet::new));
            if (!actual.equals(Set.of(expected))) {
                throw invalidSchema();
            }
        }

        private static void requireTextValues(JsonNode values, List<String> expected) {
            if (values == null || !values.isArray()) {
                throw invalidSchema();
            }
            var actual = new ArrayList<String>();
            for (var value : values) {
                if (!value.isTextual()) {
                    throw invalidSchema();
                }
                actual.add(value.textValue());
            }
            if (actual.size() != new LinkedHashSet<>(actual).size()
                    || !new LinkedHashSet<>(actual).equals(new LinkedHashSet<>(expected))) {
                throw invalidSchema();
            }
        }

        private static ObjectNode flatTextEnum(ObjectNode owner, List<String> values) {
            var schema = owner.objectNode();
            schema.put("type", "string");
            schema.set("enum", textArray(owner, values));
            return schema;
        }

        private static tools.jackson.databind.node.ArrayNode textArray(
                ObjectNode owner,
                List<String> values
        ) {
            var array = owner.arrayNode();
            values.forEach(array::add);
            return array;
        }

        private static void rejectCombinators(ObjectNode schema) {
            if (schema.has("oneOf") || schema.has("anyOf") || schema.has("allOf")) {
                throw invalidSchema();
            }
        }

        private static IllegalStateException invalidSchema() {
            return new IllegalStateException(INVALID_SCHEMA);
        }
    }
}
