package com.zhangspaghetti.babytalk.practice.generated.contract;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;
import java.util.Arrays;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
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
        Objects.requireNonNull(scene, "scene");
        utterances = List.copyOf(Objects.requireNonNull(utterances, "utterances"));
        validateCompleteShape(utterances);
    }

    public static String requireSupportedSchemaVersion(String schemaVersion) {
        if (!CURRENT_SCHEMA_VERSION.equals(schemaVersion)) {
            throw new IllegalArgumentException("unsupported complete generated bundle schema version");
        }
        return schemaVersion;
    }

    private static void validateCompleteShape(List<? extends BranchUtterance> branches) {
        if (branches.size() != 6) {
            throw new IllegalArgumentException("complete generated bundle must contain exactly six utterances");
        }
        var starterCount = 0;
        var reactions = EnumSet.noneOf(Reaction.class);
        for (var branch : branches) {
            Objects.requireNonNull(branch, "utterance");
            if (branch.role() == UtteranceRole.STARTER) {
                starterCount++;
                if (branch.reaction() != null || branch.displayOrder() != 1) {
                    throw new IllegalArgumentException("starter must have null reaction and displayOrder 1");
                }
                continue;
            }
            if (branch.role() != UtteranceRole.REACTION_SUPPORT
                    || branch.reaction() == null
                    || branch.displayOrder() != branch.reaction().ordinal() + 2
                    || !reactions.add(branch.reaction())) {
                throw new IllegalArgumentException("reaction supports must use each canonical reaction exactly once");
            }
        }
        if (starterCount != 1 || !reactions.equals(EnumSet.allOf(Reaction.class))) {
            throw new IllegalArgumentException("complete generated bundle branches are missing or duplicated");
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
            Objects.requireNonNull(role, "role");
            requireText(englishText, "englishText", 120);
            requireText(chineseText, "chineseText", 120);
            requireText(pronunciationHint, "pronunciationHint", 120);
            requireText(tprActionZh, "tprActionZh", 240);
            requireText(deliveryGuidanceZh, "deliveryGuidanceZh", 240);
            requireText(difficulty, "difficulty", 16);
            if (displayOrder < 1 || displayOrder > 6) {
                throw new IllegalArgumentException("displayOrder must be between 1 and 6");
            }
            Objects.requireNonNull(providerProvenance, "providerProvenance");
        }
    }

    public record ProviderProvenance(
            ProviderOrigin origin,
            String providerName,
            String modelName,
            int attemptNumber
    ) {
        public ProviderProvenance {
            Objects.requireNonNull(origin, "origin");
            requireText(providerName, "providerName", 120);
            requireText(modelName, "modelName", 120);
            if (attemptNumber < 1 || attemptNumber > 5) {
                throw new IllegalArgumentException("attemptNumber must be between 1 and 5");
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
            Map<String, ProviderUtterance> utterances
    ) {
        public ProviderResponse {
            requireSupportedSchemaVersion(schemaVersion);
            Objects.requireNonNull(scene, "scene");
            utterances = Map.copyOf(Objects.requireNonNull(utterances, "utterances"));
            validateProviderKeysAndShape(utterances);
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
            Objects.requireNonNull(provenance, "provenance");
            var ordered = java.util.stream.Stream.concat(
                            java.util.stream.Stream.of("starter"),
                            Arrays.stream(Reaction.values()).map(Reaction::wireValue))
                    .map(key -> utterances.get(key).toUtterance(provenance))
                    .toList();
            return new CompleteGeneratedBundle(schemaVersion, scene, ordered);
        }

        private static void validateProviderKeysAndShape(Map<String, ProviderUtterance> utterances) {
            var expectedKeys = new java.util.LinkedHashSet<String>();
            expectedKeys.add("starter");
            for (var reaction : Reaction.values()) {
                expectedKeys.add(reaction.wireValue());
            }
            if (!utterances.keySet().equals(expectedKeys)) {
                throw new IllegalArgumentException("complete generated bundle branch keys are missing, duplicated, or unknown");
            }
            var ordered = new java.util.ArrayList<ProviderUtterance>(6);
            var starter = utterances.get("starter");
            if (starter.role() != UtteranceRole.STARTER || starter.reaction() != null) {
                throw new IllegalArgumentException("starter branch role and reaction do not match its key");
            }
            ordered.add(starter);
            for (var reaction : Reaction.values()) {
                var support = utterances.get(reaction.wireValue());
                if (support.role() != UtteranceRole.REACTION_SUPPORT || support.reaction() != reaction) {
                    throw new IllegalArgumentException("reaction support role and reaction do not match its key");
                }
                ordered.add(support);
            }
            validateCompleteShape(ordered);
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
            Objects.requireNonNull(role, "role");
            requireText(englishText, "englishText", 120);
            requireText(chineseText, "chineseText", 120);
            requireText(pronunciationHint, "pronunciationHint", 120);
            requireText(tprActionZh, "tprActionZh", 240);
            requireText(deliveryGuidanceZh, "deliveryGuidanceZh", 240);
            requireText(difficulty, "difficulty", 16);
            if (displayOrder < 1 || displayOrder > 6) {
                throw new IllegalArgumentException("displayOrder must be between 1 and 6");
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

    private static void requireText(String value, String field, int maxChars) {
        if (value == null || value.isBlank() || value.codePointCount(0, value.length()) > maxChars) {
            throw new IllegalArgumentException(field + " must be non-blank and within its storage bound");
        }
    }

    private static <E extends Enum<E>> E enumForWireValue(Class<E> type, String wireValue) {
        if (wireValue != null) {
            for (var value : type.getEnumConstants()) {
                if (((WireValue) value).wireValue().equals(wireValue)) {
                    return value;
                }
            }
        }
        throw new IllegalArgumentException("unsupported " + type.getSimpleName() + " wire value");
    }

    private interface WireValue {
        String wireValue();
    }
}
