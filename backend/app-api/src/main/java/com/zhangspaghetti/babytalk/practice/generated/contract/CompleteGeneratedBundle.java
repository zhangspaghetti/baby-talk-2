package com.zhangspaghetti.babytalk.practice.generated.contract;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;
import com.zhangspaghetti.babytalk.practice.agentic.diagnostics.PracticeAiContractViolation;
import com.zhangspaghetti.babytalk.practice.agentic.diagnostics.PracticeAiContractViolation.Category;
import java.util.EnumSet;
import java.util.List;
import java.util.Objects;
import tools.jackson.core.StreamReadFeature;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;

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
                if (branch.displayOrder() != 1) {
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
            if (branch.displayOrder() != branch.reaction().ordinal() + 2) {
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
            UtteranceRole role,
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
