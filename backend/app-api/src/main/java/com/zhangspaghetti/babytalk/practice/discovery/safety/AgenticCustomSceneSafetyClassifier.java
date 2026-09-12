package com.zhangspaghetti.babytalk.practice.discovery.safety;

import com.zhangspaghetti.babytalk.practice.agentic.OperationRequest;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiCapability;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiJsonSchemaPublisher;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiOperationRunner;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiStructuredOutputCaller;
import com.zhangspaghetti.babytalk.practice.agentic.ResolvedProvider;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import tools.jackson.core.StreamReadFeature;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.MapperFeature;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ObjectNode;

/** Spring AI classifier that emits only the typed safety decision inputs. */
@Service
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "agentic"
)
public final class AgenticCustomSceneSafetyClassifier implements CustomSceneSafetyClassifier {

    private static final String LOCALE = "zh-CN";
    private static final String POLICY_VERSION = "health-safety-v1";
    private static final String PROMPT_VERSION = "custom-scene-safety-classifier-v1";
    private static final String SUBJECT_TYPE = "generated_content";
    private static final JsonMapper STRICT_JSON_MAPPER = JsonMapper.builder()
            .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
            .disable(MapperFeature.ALLOW_COERCION_OF_SCALARS)
            .enable(StreamReadFeature.STRICT_DUPLICATE_DETECTION)
            .build();
    private static final List<String> INTENT_VALUES = List.of(
            "ordinary_scene", "real_health_concern", "uncertain");
    private static final List<String> SIGNAL_VALUES = List.of(
            "health_concern", "prompt_assessment", "ambiguous_concern", "recovered", "fictional");

    private final PracticeAiOperationRunner operationRunner;
    private final PracticeAiStructuredOutputCaller structuredOutputCaller;
    private final VersionedResourceRegistry resourceRegistry;
    private final ObjectMapper objectMapper;

    @org.springframework.beans.factory.annotation.Autowired
    public AgenticCustomSceneSafetyClassifier(
            PracticeAiOperationRunner operationRunner,
            PracticeAiStructuredOutputCaller structuredOutputCaller,
            VersionedResourceRegistry resourceRegistry
    ) {
        this(operationRunner, structuredOutputCaller, resourceRegistry, new ObjectMapper());
    }

    AgenticCustomSceneSafetyClassifier(
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
    public CustomSceneSafetyClassifier.SemanticResult classify(
            CustomSceneSafetyClassifier.ClassifierRequest request
    ) {
        Objects.requireNonNull(request, "request");
        validateRequest(request);
        var systemPrompt = requiredSystemPrompt(
                resourceRegistry.promptText(VersionedResourceRegistry.PromptKind.SAFETY_CLASSIFIER));
        var promptRef = resourceRegistry.promptRef(VersionedResourceRegistry.PromptKind.SAFETY_CLASSIFIER);
        var promptVersion = promptRef == null ? PROMPT_VERSION : promptRef.version();
        var promptHash = promptRef == null || !isHash(promptRef.contentHash())
                ? sha256(systemPrompt)
                : promptRef.contentHash();
        var policyHash = resourceRegistry.healthSafetyPolicyHash();
        if (!isHash(policyHash)) {
            policyHash = sha256(request.policyVersion());
        }
        var userPrompt = objectMapper.writeValueAsString(new ClassifierPromptPayload(
                request.displayText(), request.ageRange(), request.locale(), request.policyVersion()));
        var generatedContentId = UUID.randomUUID().toString();
        var finalPolicyHash = policyHash;
        var result = operationRunner.execute(new OperationRequest<>(
                PracticeAiCapability.CUSTOM_SCENE_SAFETY_CLASSIFIER,
                SUBJECT_TYPE,
                generatedContentId,
                generatedContentId,
                1,
                null,
                promptVersion,
                promptHash,
                request.policyVersion(),
                finalPolicyHash,
                provider -> parseProviderResponse(provider, systemPrompt, userPrompt)));
        return result.value();
    }

    private OperationRequest.ProviderInvocationResult<CustomSceneSafetyClassifier.SemanticResult>
            parseProviderResponse(
                    ResolvedProvider provider,
                    String systemPrompt,
                    String userPrompt
            ) {
        var content = OperationRequest.atFailureStage(
                OperationRequest.ProviderFailureStage.PROVIDER_RESPONSE_BINDING,
                () -> structuredOutputCaller.callRaw(provider, systemPrompt, userPrompt, ProviderResponse.class));
        var semanticResult = OperationRequest.atFailureStage(
                OperationRequest.ProviderFailureStage.CONTENT_STRICT_PARSER,
                () -> parse(content));
        return new OperationRequest.ProviderInvocationResult<>(semanticResult, null);
    }

    private CustomSceneSafetyClassifier.SemanticResult parse(String content) {
        try {
            var root = STRICT_JSON_MAPPER.readValue(content, JsonNode.class);
            if (!(root instanceof ObjectNode object)
                    || object.size() != 2
                    || !object.has("intent")
                    || !object.has("signals")) {
                throw invalid();
            }
            var intentNode = object.get("intent");
            var signalsNode = object.get("signals");
            if (intentNode == null || !intentNode.isTextual()
                    || signalsNode == null || !signalsNode.isArray()
                    || signalsNode.size() > SIGNAL_VALUES.size()) {
                throw invalid();
            }
            var intent = parseIntent(intentNode.textValue());
            var signalSet = EnumSet.noneOf(CustomSceneSafetyClassifier.Signal.class);
            var orderedSignals = new ArrayList<CustomSceneSafetyClassifier.Signal>();
            for (var signalNode : signalsNode) {
                if (signalNode == null || !signalNode.isTextual()) {
                    throw invalid();
                }
                var signal = parseSignal(signalNode.textValue());
                if (!signalSet.add(signal)) {
                    throw invalid();
                }
                orderedSignals.add(signal);
            }
            validateCombination(intent, signalSet);
            return new CustomSceneSafetyClassifier.SemanticResult(intent, List.copyOf(orderedSignals));
        } catch (PracticeAiStructuredOutputCaller.StructuredOutputInvalidException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            throw invalid();
        }
    }

    private CustomSceneSafetyAssessment.Intent parseIntent(String value) {
        if (!INTENT_VALUES.contains(value)) {
            throw invalid();
        }
        return switch (value) {
            case "ordinary_scene" -> CustomSceneSafetyAssessment.Intent.ORDINARY_SCENE;
            case "real_health_concern" -> CustomSceneSafetyAssessment.Intent.REAL_HEALTH_CONCERN;
            case "uncertain" -> CustomSceneSafetyAssessment.Intent.UNCERTAIN;
            default -> throw invalid();
        };
    }

    private CustomSceneSafetyClassifier.Signal parseSignal(String value) {
        if (!SIGNAL_VALUES.contains(value)) {
            throw invalid();
        }
        return switch (value) {
            case "health_concern" -> CustomSceneSafetyClassifier.Signal.HEALTH_CONCERN;
            case "prompt_assessment" -> CustomSceneSafetyClassifier.Signal.PROMPT_ASSESSMENT;
            case "ambiguous_concern" -> CustomSceneSafetyClassifier.Signal.AMBIGUOUS_CONCERN;
            case "recovered" -> CustomSceneSafetyClassifier.Signal.RECOVERED;
            case "fictional" -> CustomSceneSafetyClassifier.Signal.FICTIONAL;
            default -> throw invalid();
        };
    }

    private void validateCombination(
            CustomSceneSafetyAssessment.Intent intent,
            EnumSet<CustomSceneSafetyClassifier.Signal> signals
    ) {
        var hasHealth = signals.contains(CustomSceneSafetyClassifier.Signal.HEALTH_CONCERN);
        var hasPrompt = signals.contains(CustomSceneSafetyClassifier.Signal.PROMPT_ASSESSMENT);
        var hasAmbiguous = signals.contains(CustomSceneSafetyClassifier.Signal.AMBIGUOUS_CONCERN);
        var hasRecovered = signals.contains(CustomSceneSafetyClassifier.Signal.RECOVERED);
        var hasFictional = signals.contains(CustomSceneSafetyClassifier.Signal.FICTIONAL);
        if (hasPrompt && !hasHealth) {
            throw invalid();
        }
        switch (intent) {
            case ORDINARY_SCENE -> {
                if (hasHealth || hasPrompt || hasAmbiguous) {
                    throw invalid();
                }
            }
            case REAL_HEALTH_CONCERN -> {
                if (!hasHealth || hasAmbiguous || hasRecovered || hasFictional) {
                    throw invalid();
                }
            }
            case UNCERTAIN -> {
                if (!hasAmbiguous || hasHealth || hasPrompt || hasRecovered || hasFictional) {
                    throw invalid();
                }
            }
            default -> throw invalid();
        }
    }

    private void validateRequest(CustomSceneSafetyClassifier.ClassifierRequest request) {
        if (isBlank(request.displayText())
                || isBlank(request.ageRange())
                || !LOCALE.equals(request.locale())
                || !POLICY_VERSION.equals(request.policyVersion())) {
            throw new CustomSceneSafetyClassifier.UnavailableException();
        }
    }

    private String requiredSystemPrompt(String prompt) {
        if (prompt == null || prompt.isBlank()) {
            throw new CustomSceneSafetyClassifier.UnavailableException();
        }
        return prompt;
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private static boolean isHash(String value) {
        return value != null && value.matches("[0-9a-f]{64}");
    }

    private static String sha256(String value) {
        try {
            var digest = MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8));
            var hash = new StringBuilder(digest.length * 2);
            for (var byteValue : digest) {
                hash.append(String.format("%02x", byteValue));
            }
            return hash.toString();
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }

    private static PracticeAiStructuredOutputCaller.StructuredOutputInvalidException invalid() {
        return new PracticeAiStructuredOutputCaller.StructuredOutputInvalidException();
    }

    private record ClassifierPromptPayload(
            String displayText,
            String ageRange,
            String locale,
            String policyVersion
    ) {
    }

    @PracticeAiJsonSchemaPublisher.RefinedBy(ProviderResponseSchemaRefiner.class)
    public record ProviderResponse(String intent, List<String> signals) {
    }

    /** Publishes the exact two-field provider wire contract. */
    public static final class ProviderResponseSchemaRefiner
            implements PracticeAiJsonSchemaPublisher.SchemaRefiner {

        private static final String JSON_SCHEMA_DRAFT = "https://json-schema.org/draft/2020-12/schema";

        @Override
        public void refine(ObjectNode schema) {
            var keys = schema.properties().stream()
                    .map(java.util.Map.Entry::getKey)
                    .toList();
            keys.forEach(schema::remove);
            schema.put("$schema", JSON_SCHEMA_DRAFT);
            schema.put("type", "object");
            var properties = schema.objectNode();
            var intent = schema.objectNode();
            intent.put("type", "string");
            intent.set("enum", textArray(schema, INTENT_VALUES));
            properties.set("intent", intent);
            var signals = schema.objectNode();
            signals.put("type", "array");
            signals.set("items", enumSchema(schema, SIGNAL_VALUES));
            signals.put("maxItems", SIGNAL_VALUES.size());
            signals.put("uniqueItems", true);
            properties.set("signals", signals);
            schema.set("properties", properties);
            schema.set("required", textArray(schema, List.of("intent", "signals")));
            schema.put("additionalProperties", false);
        }

        private static ObjectNode enumSchema(ObjectNode owner, List<String> values) {
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
    }
}
