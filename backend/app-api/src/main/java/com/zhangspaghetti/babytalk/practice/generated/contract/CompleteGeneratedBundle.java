package com.zhangspaghetti.babytalk.practice.generated.contract;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;
import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiJsonSchemaPublisher;
import com.zhangspaghetti.babytalk.practice.agentic.diagnostics.PracticeAiContractViolation;
import com.zhangspaghetti.babytalk.practice.agentic.diagnostics.PracticeAiContractViolation.Category;
import io.swagger.v3.oas.annotations.media.Schema;
import java.util.EnumSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import tools.jackson.databind.JsonNode;
import tools.jackson.core.StreamReadFeature;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ArrayNode;
import tools.jackson.databind.node.ObjectNode;

/**
 * Versioned, closed six-utterance provider contract. This type is the public serialization
 * boundary for generated care content; role, reaction, and provider provenance never share a
 * field.
 */
public record CompleteGeneratedBundle(
        String schemaVersion,
        SceneMetadata scene,
        List<Utterance> utterances
) {
    public static final String CURRENT_SCHEMA_VERSION = "custom-scene-generated-output-v1";
    private static final int STARTER_DISPLAY_ORDER = 1;

    private static final ObjectMapper STRICT_PROVIDER_MAPPER = JsonMapper.builder()
            .enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
            .enable(StreamReadFeature.STRICT_DUPLICATE_DETECTION)
            .build();

    public CompleteGeneratedBundle {
        requireSupportedSchemaVersion(schemaVersion);
        scene = requireComponent(scene, Category.REQUIRED_COMPONENT, "scene");
        utterances = requireComponent(
                utterances,
                Category.BRANCH_COMPLETENESS,
                "utterances");
        validateCompleteShape(utterances);
        utterances = List.copyOf(utterances);
    }

    public static String requireSupportedSchemaVersion(String schemaVersion) {
        if (!CURRENT_SCHEMA_VERSION.equals(schemaVersion)) {
            throw violation(
                    Category.SCHEMA_VERSION,
                    "unsupported complete generated bundle schema version");
        }
        return schemaVersion;
    }

    private static void validateCompleteShape(List<? extends BranchUtterance> branches) {
        if (branches.size() != 6) {
            throw violation(
                    Category.BRANCH_COMPLETENESS,
                    "complete generated bundle must contain exactly six utterances");
        }
        var starterCount = 0;
        var reactions = EnumSet.noneOf(Reaction.class);
        for (var branch : branches) {
            requireComponent(branch, Category.BRANCH_COMPLETENESS, "utterance");
            if (branch.role() == UtteranceRole.STARTER) {
                starterCount++;
                if (branch.reaction() != null) {
                    throw violation(
                            Category.ROLE_REACTION_MAPPING,
                            "starter must have null reaction");
                }
                if (branch.displayOrder() != STARTER_DISPLAY_ORDER) {
                    throw violation(
                            Category.DISPLAY_ORDER,
                            "starter must have displayOrder 1");
                }
                continue;
            }
            if (branch.role() != UtteranceRole.REACTION_SUPPORT
                    || branch.reaction() == null) {
                throw violation(
                        Category.ROLE_REACTION_MAPPING,
                        "reaction support role and reaction are required");
            }
            if (branch.displayOrder() != canonicalDisplayOrder(branch.reaction())) {
                throw violation(
                        Category.DISPLAY_ORDER,
                        "reaction support displayOrder must match reaction");
            }
            if (!reactions.add(branch.reaction())) {
                throw violation(
                        Category.BRANCH_COMPLETENESS,
                        "reaction supports must use each canonical reaction exactly once");
            }
        }
        if (starterCount != 1 || !reactions.equals(EnumSet.allOf(Reaction.class))) {
            throw violation(
                    Category.BRANCH_COMPLETENESS,
                    "complete generated bundle branches are missing or duplicated");
        }
    }

    private interface BranchUtterance {
        UtteranceRole role();

        Reaction reaction();

        int displayOrder();
    }

    public record SceneMetadata(
            String spaceTitleZh,
            String activityTitleZh,
            String sceneTagEn
    ) {
        public SceneMetadata {
            requireText(spaceTitleZh, "spaceTitleZh", 120);
            requireText(activityTitleZh, "activityTitleZh", 120);
            requireText(sceneTagEn, "sceneTagEn", 120);
        }
    }

    public record Utterance(
            UtteranceRole role,
            Reaction reaction,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String tprActionZh,
            String deliveryGuidanceZh,
            String difficulty,
            int displayOrder,
            ProviderProvenance providerProvenance
    ) implements BranchUtterance {
        public Utterance {
            role = requireComponent(role, Category.REQUIRED_COMPONENT, "role");
            requireText(englishText, "englishText", 120);
            requireText(chineseText, "chineseText", 120);
            requireText(pronunciationHint, "pronunciationHint", 120);
            requireText(tprActionZh, "tprActionZh", 240);
            requireText(deliveryGuidanceZh, "deliveryGuidanceZh", 240);
            requireText(difficulty, "difficulty", 16);
            if (displayOrder < 1 || displayOrder > 6) {
                throw violation(
                        Category.DISPLAY_ORDER,
                        "displayOrder must be between 1 and 6");
            }
            providerProvenance = requireComponent(
                    providerProvenance,
                    Category.REQUIRED_COMPONENT,
                    "providerProvenance");
        }
    }

    public record ProviderProvenance(
            ProviderOrigin origin,
            String providerName,
            String modelName,
            int attemptNumber
    ) {
        public ProviderProvenance {
            origin = requireComponent(origin, Category.REQUIRED_COMPONENT, "origin");
            requireText(providerName, "providerName", 120);
            requireText(modelName, "modelName", 120);
            if (attemptNumber < 1 || attemptNumber > 5) {
                throw violation(Category.PROVENANCE, "attemptNumber must be between 1 and 5");
            }
        }
    }

    public enum UtteranceRole implements WireValue {
        STARTER("starter"),
        REACTION_SUPPORT("reaction_support");

        private final String wireValue;

        UtteranceRole(String wireValue) {
            this.wireValue = wireValue;
        }

        @JsonValue
        public String wireValue() {
            return wireValue;
        }

        @JsonCreator
        public static UtteranceRole fromWireValue(String wireValue) {
            return enumForWireValue(UtteranceRole.class, wireValue);
        }
    }

    public enum Reaction implements WireValue {
        COOPERATING("cooperating"),
        HESITANT("hesitant"),
        RESISTING("resisting"),
        NO_RESPONSE("no_response"),
        OTHER("other");

        private final String wireValue;

        Reaction(String wireValue) {
            this.wireValue = wireValue;
        }

        @JsonValue
        public String wireValue() {
            return wireValue;
        }

        @JsonCreator
        public static Reaction fromWireValue(String wireValue) {
            return enumForWireValue(Reaction.class, wireValue);
        }
    }

    public enum ProviderOrigin implements WireValue {
        PROVIDER_GENERATED("provider_generated"),
        PROVIDER_REPAIRED("provider_repaired");

        private final String wireValue;

        ProviderOrigin(String wireValue) {
            this.wireValue = wireValue;
        }

        @JsonValue
        public String wireValue() {
            return wireValue;
        }

        @JsonCreator
        public static ProviderOrigin fromWireValue(String wireValue) {
            return enumForWireValue(ProviderOrigin.class, wireValue);
        }
    }

    /** Strict provider wire schema. Provider-owned metadata cannot populate provenance. */
    @PracticeAiJsonSchemaPublisher.RefinedBy(ProviderResponseSchemaRefiner.class)
    public record ProviderResponse(
            String schemaVersion,
            SceneMetadata scene,
            ProviderUtterances utterances
    ) {
        public ProviderResponse {
            requireSupportedSchemaVersion(schemaVersion);
            scene = requireComponent(scene, Category.REQUIRED_COMPONENT, "scene");
            utterances = requireComponent(
                    utterances,
                    Category.BRANCH_COMPLETENESS,
                    "utterances");
        }

        public static ProviderResponse parse(String json) {
            if (json == null || json.isBlank()) {
                throw new InvalidProviderResponseException();
            }
            try {
                return STRICT_PROVIDER_MAPPER.readValue(json, ProviderResponse.class);
            } catch (RuntimeException exception) {
                throw new InvalidProviderResponseException(exception);
            }
        }

        public CompleteGeneratedBundle toCompleteBundle(ProviderProvenance provenance) {
            requireComponent(provenance, Category.REQUIRED_COMPONENT, "provenance");
            var ordered = utterances.ordered().stream()
                    .map(branch -> branch.toUtterance(provenance))
                    .toList();
            return new CompleteGeneratedBundle(schemaVersion, scene, ordered);
        }
    }

    /** Publishes the key-specific constraints already enforced by {@link ProviderUtterances}. */
    public static final class ProviderResponseSchemaRefiner
            implements PracticeAiJsonSchemaPublisher.SchemaRefiner {

        @Override
        public void refine(ObjectNode schema) {
            var branchProperties = requiredObject(
                    schema, "properties", "utterances", "properties");
            constrainBranch(
                    schema,
                    branchProperties,
                    "starter",
                    UtteranceRole.STARTER,
                    null,
                    STARTER_DISPLAY_ORDER);
            constrainBranch(
                    schema,
                    branchProperties,
                    "cooperating",
                    UtteranceRole.REACTION_SUPPORT,
                    Reaction.COOPERATING,
                    canonicalDisplayOrder(Reaction.COOPERATING));
            constrainBranch(
                    schema,
                    branchProperties,
                    "hesitant",
                    UtteranceRole.REACTION_SUPPORT,
                    Reaction.HESITANT,
                    canonicalDisplayOrder(Reaction.HESITANT));
            constrainBranch(
                    schema,
                    branchProperties,
                    "resisting",
                    UtteranceRole.REACTION_SUPPORT,
                    Reaction.RESISTING,
                    canonicalDisplayOrder(Reaction.RESISTING));
            constrainBranch(
                    schema,
                    branchProperties,
                    "no_response",
                    UtteranceRole.REACTION_SUPPORT,
                    Reaction.NO_RESPONSE,
                    canonicalDisplayOrder(Reaction.NO_RESPONSE));
            constrainBranch(
                    schema,
                    branchProperties,
                    "other",
                    UtteranceRole.REACTION_SUPPORT,
                    Reaction.OTHER,
                    canonicalDisplayOrder(Reaction.OTHER));
        }

        private static void constrainBranch(
                ObjectNode schema,
                ObjectNode branchProperties,
                String branchKey,
                UtteranceRole role,
                Reaction reaction,
                int displayOrder
        ) {
            var branchSchema = resolvedBranchSchema(schema, branchProperties.get(branchKey));
            var properties = requiredObject(branchSchema, "properties");
            setTextEnum(properties, "role", role.wireValue());
            if (reaction == null) {
                setNullEnum(properties, "reaction");
            } else {
                setTextEnum(properties, "reaction", reaction.wireValue());
            }
            setIntegerEnum(properties, "displayOrder", displayOrder);
            branchProperties.set(branchKey, branchSchema);
        }

        private static ObjectNode resolvedBranchSchema(ObjectNode root, JsonNode candidate) {
            if (!(candidate instanceof ObjectNode candidateObject)) {
                throw invalidSchema();
            }
            tools.jackson.databind.JsonNode resolved = candidate;
            if (candidateObject.has("$ref")) {
                if (candidateObject.size() != 1 || !candidateObject.get("$ref").isTextual()) {
                    throw invalidSchema();
                }
                var reference = candidateObject.get("$ref").textValue();
                if (!reference.startsWith("#/")) {
                    throw invalidSchema();
                }
                resolved = root;
                for (var segment : reference.substring(2).split("/", -1)) {
                    resolved = resolved.get(decodePointerSegment(segment));
                    if (resolved == null) {
                        throw invalidSchema();
                    }
                }
            }
            if (!(resolved instanceof ObjectNode objectSchema)) {
                throw invalidSchema();
            }
            return objectSchema.deepCopy();
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

        private static ObjectNode requiredObject(
                JsonNode root,
                String... path
        ) {
            JsonNode current = root;
            for (var segment : path) {
                current = current == null ? null : current.get(segment);
                if (!(current instanceof ObjectNode)) {
                    throw invalidSchema();
                }
            }
            return (ObjectNode) current;
        }

        private static void setTextEnum(ObjectNode properties, String propertyName, String value) {
            var property = requiredObject(properties, propertyName);
            var sourceTypes = "role".equals(propertyName)
                    ? Set.of("string")
                    : Set.of("string", "null");
            validateSourceConstraint(property, sourceTypes, property.textNode(value), true);
            property.put("type", "string");
            property.set("enum", enumValues(property, value));
        }

        private static void setNullEnum(ObjectNode properties, String propertyName) {
            var property = requiredObject(properties, propertyName);
            validateSourceConstraint(
                    property,
                    Set.of("string", "null"),
                    property.nullNode(),
                    true);
            var values = property.arrayNode();
            values.addNull();
            property.set("enum", values);
        }

        private static void setIntegerEnum(ObjectNode properties, String propertyName, int value) {
            var property = requiredObject(properties, propertyName);
            validateSourceConstraint(
                    property,
                    Set.of("integer"),
                    property.numberNode(value),
                    false);
            var values = property.arrayNode();
            values.add(value);
            property.set("enum", values);
        }

        private static void validateSourceConstraint(
                ObjectNode property,
                Set<String> expectedTypes,
                JsonNode expectedValue,
                boolean requireEnum
        ) {
            if (property.has("$ref")
                    || property.has("oneOf")
                    || property.has("anyOf")
                    || property.has("allOf")) {
                throw invalidSchema();
            }
            if (!typeNames(property.get("type")).equals(expectedTypes)) {
                throw invalidSchema();
            }
            var enumValues = property.get("enum");
            if (enumValues == null) {
                if (requireEnum) {
                    throw invalidSchema();
                }
            } else if (!enumValues.isArray()
                    || java.util.stream.StreamSupport.stream(enumValues.spliterator(), false)
                            .noneMatch(expectedValue::equals)) {
                throw invalidSchema();
            }
            var constant = property.get("const");
            if (constant != null && !constant.equals(expectedValue)) {
                throw invalidSchema();
            }
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
            return names;
        }

        private static ArrayNode enumValues(ObjectNode property, String value) {
            var values = property.arrayNode();
            values.add(value);
            return values;
        }

        private static IllegalStateException invalidSchema() {
            return new IllegalStateException("complete_generated_bundle_provider_schema_invalid");
        }
    }

    /** Fixed provider-facing branch object so JSON Schema requires all six canonical keys. */
    public record ProviderUtterances(
            ProviderUtterance starter,
            ProviderUtterance cooperating,
            ProviderUtterance hesitant,
            ProviderUtterance resisting,
            ProviderUtterance no_response,
            ProviderUtterance other
    ) {
        public ProviderUtterances {
            starter = requireComponent(
                    starter, Category.BRANCH_COMPLETENESS, "starter");
            cooperating = requireComponent(
                    cooperating, Category.BRANCH_COMPLETENESS, "cooperating");
            hesitant = requireComponent(
                    hesitant, Category.BRANCH_COMPLETENESS, "hesitant");
            resisting = requireComponent(
                    resisting, Category.BRANCH_COMPLETENESS, "resisting");
            no_response = requireComponent(
                    no_response, Category.BRANCH_COMPLETENESS, "no_response");
            other = requireComponent(
                    other, Category.BRANCH_COMPLETENESS, "other");
            if (starter.role() != UtteranceRole.STARTER || starter.reaction() != null) {
                throw violation(
                        Category.ROLE_REACTION_MAPPING,
                        "starter branch role and reaction do not match its key");
            }
            validateSupport(cooperating, Reaction.COOPERATING);
            validateSupport(hesitant, Reaction.HESITANT);
            validateSupport(resisting, Reaction.RESISTING);
            validateSupport(no_response, Reaction.NO_RESPONSE);
            validateSupport(other, Reaction.OTHER);
            validateCompleteShape(List.of(starter, cooperating, hesitant, resisting, no_response, other));
        }

        private List<ProviderUtterance> ordered() {
            return List.of(starter, cooperating, hesitant, resisting, no_response, other);
        }

        private static void validateSupport(ProviderUtterance support, Reaction reaction) {
            if (support.role() != UtteranceRole.REACTION_SUPPORT || support.reaction() != reaction) {
                throw violation(
                        Category.ROLE_REACTION_MAPPING,
                        "reaction support role and reaction do not match its key");
            }
        }
    }

    public record ProviderUtterance(
            @Schema(
                    implementation = String.class,
                    allowableValues = {"starter", "reaction_support"})
            UtteranceRole role,
            @Schema(implementation = String.class, nullable = true, allowableValues = {
                    "cooperating", "hesitant", "resisting", "no_response", "other"
            })
            Reaction reaction,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String tprActionZh,
            String deliveryGuidanceZh,
            String difficulty,
            int displayOrder
    ) implements BranchUtterance {
        public ProviderUtterance {
            role = requireComponent(role, Category.REQUIRED_COMPONENT, "role");
            requireText(englishText, "englishText", 120);
            requireText(chineseText, "chineseText", 120);
            requireText(pronunciationHint, "pronunciationHint", 120);
            requireText(tprActionZh, "tprActionZh", 240);
            requireText(deliveryGuidanceZh, "deliveryGuidanceZh", 240);
            requireText(difficulty, "difficulty", 16);
            if (displayOrder < 1 || displayOrder > 6) {
                throw violation(
                        Category.DISPLAY_ORDER,
                        "displayOrder must be between 1 and 6");
            }
        }

        private Utterance toUtterance(ProviderProvenance provenance) {
            return new Utterance(
                    role,
                    reaction,
                    englishText,
                    chineseText,
                    pronunciationHint,
                    tprActionZh,
                    deliveryGuidanceZh,
                    difficulty,
                    displayOrder,
                    provenance);
        }
    }

    public static final class InvalidProviderResponseException extends RuntimeException {
        public InvalidProviderResponseException() {
            this(null);
        }

        private InvalidProviderResponseException(Throwable cause) {
            super("complete_generated_bundle_invalid", cause);
        }
    }

    public static final class ContractViolationException extends IllegalArgumentException
            implements PracticeAiContractViolation {
        private final Category category;

        private ContractViolationException(Category category, String message) {
            super(message);
            this.category = Objects.requireNonNull(category, "category");
        }

        public Category category() {
            return category;
        }
    }

    private static void requireText(String value, String field, int maxChars) {
        if (value == null || value.isBlank() || value.codePointCount(0, value.length()) > maxChars) {
            throw violation(
                    Category.TEXT_CONSTRAINT,
                    field + " must be non-blank and within its storage bound");
        }
    }

    private static <T> T requireComponent(
            T value,
            Category category,
            String componentName
    ) {
        if (value == null) {
            throw violation(category, componentName + " is required");
        }
        return value;
    }

    private static ContractViolationException violation(
            Category category,
            String message
    ) {
        return new ContractViolationException(category, message);
    }

    private static int canonicalDisplayOrder(Reaction reaction) {
        return reaction.ordinal() + 2;
    }

    private static <E extends Enum<E>> E enumForWireValue(Class<E> type, String wireValue) {
        if (wireValue != null) {
            for (var value : type.getEnumConstants()) {
                if (((WireValue) value).wireValue().equals(wireValue)) {
                    return value;
                }
            }
        }
        throw violation(
                Category.ENUM_VALUE,
                "unsupported " + type.getSimpleName() + " wire value");
    }

    private interface WireValue {
        String wireValue();
    }
}
