package com.zhangspaghetti.babytalk.practice.generated.contract;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.SoftAssertions.assertSoftly;

import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiJsonSchemaPublisher;
import com.zhangspaghetti.babytalk.practice.agentic.diagnostics.PracticeAiContractViolation.Category;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;
import org.springframework.ai.converter.BeanOutputConverter;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

class CompleteGeneratedBundleContractTest {

    @Test
    void publicProviderParserAcceptsCanonicalSixBranchResponse() throws Exception {
        var response = CompleteGeneratedBundle.ProviderResponse.parse(canonicalResponse());
        var bundle = response.toCompleteBundle(generatedProvenance());

        assertThat(bundle.schemaVersion()).isEqualTo(CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION);
        assertThat(bundle.utterances()).hasSize(6);
        assertThat(bundle.utterances())
                .extracting(CompleteGeneratedBundle.Utterance::role)
                .containsExactly(
                        CompleteGeneratedBundle.UtteranceRole.STARTER,
                        CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                        CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                        CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                        CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                        CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT);
        assertThat(bundle.utterances())
                .extracting(CompleteGeneratedBundle.Utterance::reaction)
                .containsExactly(
                        null,
                        CompleteGeneratedBundle.Reaction.COOPERATING,
                        CompleteGeneratedBundle.Reaction.HESITANT,
                        CompleteGeneratedBundle.Reaction.RESISTING,
                        CompleteGeneratedBundle.Reaction.NO_RESPONSE,
                        CompleteGeneratedBundle.Reaction.OTHER);
        assertThat(bundle.utterances())
                .extracting(CompleteGeneratedBundle.Utterance::providerProvenance)
                .containsOnly(generatedProvenance());
    }

    @Test
    void providerSchemaRequiresEveryCanonicalBranchForStructuredOutputModels() throws Exception {
        var schema = providerSchema();
        var utterancesSchema = schema.get("properties").get("utterances");
        var branchProperties = utterancesSchema.get("properties");

        assertThat(branchProperties).isNotNull();
        assertThat(branchProperties.has("starter")).isTrue();
        assertThat(branchProperties.has("cooperating")).isTrue();
        assertThat(branchProperties.has("hesitant")).isTrue();
        assertThat(branchProperties.has("resisting")).isTrue();
        assertThat(branchProperties.has("no_response")).isTrue();
        assertThat(branchProperties.has("other")).isTrue();
        assertThat(utterancesSchema.get("required").toString())
                .contains(
                        "\"starter\"",
                        "\"cooperating\"",
                        "\"hesitant\"",
                        "\"resisting\"",
                        "\"no_response\"",
                        "\"other\"");
        assertThat(utterancesSchema.get("additionalProperties").booleanValue()).isFalse();
        var starterSchema = resolveLocalSchema(schema, branchProperties.get("starter"));
        var starterProperties = starterSchema.get("properties");
        assertThat(starterProperties.has("role")).isTrue();
        assertThat(starterProperties.has("reaction")).isTrue();
        assertThat(starterProperties.has("providerProvenance")).isFalse();
        assertThat(starterSchema.get("required").toString())
                .contains("\"role\"", "\"reaction\"", "\"displayOrder\"");
        assertThat(starterSchema.get("additionalProperties").booleanValue()).isFalse();
    }

    @Test
    void providerSchemaEnumTokensMatchStrictParserWireTokens() throws Exception {
        var schema = providerSchema();
        var starterSchema = resolveLocalSchema(
                schema,
                schema.get("properties").get("utterances").get("properties").get("starter"));
        var roleSchema = starterSchema.get("properties").get("role");
        var reactionSchema = starterSchema.get("properties").get("reaction");
        assertFlatStringEnumSchema(roleSchema);
        assertFlatStringEnumSchema(reactionSchema);
        var roleSchemaTokens = enumTextValues(roleSchema);
        var reactionSchemaTokens = enumTextValues(reactionSchema);
        var roleParserTokens = Arrays.stream(CompleteGeneratedBundle.UtteranceRole.values())
                .map(CompleteGeneratedBundle.UtteranceRole::wireValue)
                .collect(Collectors.toSet());
        var reactionParserTokens = Arrays.stream(CompleteGeneratedBundle.Reaction.values())
                .map(CompleteGeneratedBundle.Reaction::wireValue)
                .collect(Collectors.toSet());

        assertSoftly(softly -> {
            softly.assertThat(roleSchemaTokens).containsExactlyInAnyOrderElementsOf(roleParserTokens);
            softly.assertThat(reactionSchemaTokens).containsExactlyInAnyOrderElementsOf(reactionParserTokens);
            softly.assertThat(typeNames(roleSchema)).containsExactly("string");
            softly.assertThat(typeNames(reactionSchema)).containsExactlyInAnyOrder("string", "null");
            softly.assertThat(nullEnumValueCount(roleSchema)).isZero();
            softly.assertThat(nullEnumValueCount(reactionSchema)).isOne();
        });
        roleSchemaTokens.forEach(CompleteGeneratedBundle.UtteranceRole::fromWireValue);
        reactionSchemaTokens.forEach(CompleteGeneratedBundle.Reaction::fromWireValue);
    }

    @Test
    void strictParserRejectsJavaEnumNamesAndCaseAliases() {
        assertViolationCategory(
                () -> CompleteGeneratedBundle.UtteranceRole.fromWireValue("STARTER"),
                Category.ENUM_VALUE);
        assertViolationCategory(
                () -> CompleteGeneratedBundle.UtteranceRole.fromWireValue("Starter"),
                Category.ENUM_VALUE);
        assertViolationCategory(
                () -> CompleteGeneratedBundle.Reaction.fromWireValue("COOPERATING"),
                Category.ENUM_VALUE);
        assertViolationCategory(
                () -> CompleteGeneratedBundle.Reaction.fromWireValue("Cooperating"),
                Category.ENUM_VALUE);
    }

    @Test
    void typedValidationEmitsStableContractViolationCategories() {
        assertViolationCategory(
                () -> CompleteGeneratedBundle.requireSupportedSchemaVersion("unsupported-v2"),
                Category.SCHEMA_VERSION);
        assertViolationCategory(
                () -> new CompleteGeneratedBundle.ProviderResponse(
                        CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION,
                        null,
                        canonicalProviderUtterances()),
                Category.REQUIRED_COMPONENT);
        assertViolationCategory(
                () -> new CompleteGeneratedBundle.SceneMetadata("", "activity", "scene"),
                Category.TEXT_CONSTRAINT);
        assertViolationCategory(
                () -> CompleteGeneratedBundle.Reaction.fromWireValue("unsupported"),
                Category.ENUM_VALUE);
        assertViolationCategory(
                () -> new CompleteGeneratedBundle.ProviderUtterances(
                        null,
                        support(CompleteGeneratedBundle.Reaction.COOPERATING),
                        support(CompleteGeneratedBundle.Reaction.HESITANT),
                        support(CompleteGeneratedBundle.Reaction.RESISTING),
                        support(CompleteGeneratedBundle.Reaction.NO_RESPONSE),
                        support(CompleteGeneratedBundle.Reaction.OTHER)),
                Category.BRANCH_COMPLETENESS);
        assertViolationCategory(
                () -> new CompleteGeneratedBundle.ProviderUtterances(
                        utterance(
                                CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                                null,
                                1),
                        support(CompleteGeneratedBundle.Reaction.COOPERATING),
                        support(CompleteGeneratedBundle.Reaction.HESITANT),
                        support(CompleteGeneratedBundle.Reaction.RESISTING),
                        support(CompleteGeneratedBundle.Reaction.NO_RESPONSE),
                        support(CompleteGeneratedBundle.Reaction.OTHER)),
                Category.ROLE_REACTION_MAPPING);
        assertViolationCategory(
                () -> utterance(CompleteGeneratedBundle.UtteranceRole.STARTER, null, 0),
                Category.DISPLAY_ORDER);
    }

    @Test
    void completeBundleRejectsNullUtteranceWithTypedCategory() {
        var canonicalBundle = CompleteGeneratedBundle.ProviderResponse.parse(canonicalResponse())
                .toCompleteBundle(generatedProvenance());
        var utterances = new ArrayList<>(canonicalBundle.utterances());
        utterances.set(2, null);

        assertViolationCategory(
                () -> new CompleteGeneratedBundle(
                        CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION,
                        canonicalBundle.scene(),
                        utterances),
                Category.BRANCH_COMPLETENESS);
    }

    @Test
    void providerProvenanceRejectsInvalidAttemptWithTypedViolation() {
        assertViolationCategory(
                () -> new CompleteGeneratedBundle.ProviderProvenance(
                        CompleteGeneratedBundle.ProviderOrigin.PROVIDER_GENERATED,
                        "primary",
                        "gpt-test",
                        0),
                Category.PROVENANCE);
    }

    @Test
    void publicProviderParserPreservesTypedViolationIdentityWithoutMessageParsing() {
        assertThatThrownBy(() -> CompleteGeneratedBundle.ProviderResponse.parse("""
                {"schemaVersion":"custom-scene-generated-output-v1","scene":{"spaceTitleZh":"scene","activityTitleZh":"activity","sceneTagEn":"tag"},"utterances":{}}
                """))
                .isInstanceOf(CompleteGeneratedBundle.InvalidProviderResponseException.class)
                .satisfies(failure -> assertThat(contractViolationCategory(failure))
                        .isEqualTo(Category.BRANCH_COMPLETENESS));
    }

    @Test
    void publicProviderParserRejectsMissingDuplicateAndUnknownBranchKeys() {
        assertThatThrownBy(() -> CompleteGeneratedBundle.ProviderResponse.parse("""
                {"schemaVersion":"custom-scene-generated-output-v1","scene":{"spaceTitleZh":"日常照护","activityTitleZh":"穿鞋","sceneTagEn":"Shoes"},"utterances":{"starter":{"role":"starter","reaction":null,"englishText":"Shoes on.","chineseText":"穿鞋。","pronunciationHint":"shoes on","tprActionZh":"拿鞋。","deliveryGuidanceZh":"慢慢说。","difficulty":"starter","displayOrder":1}}}
                """))
                .isInstanceOf(CompleteGeneratedBundle.InvalidProviderResponseException.class);
        assertThatThrownBy(() -> CompleteGeneratedBundle.ProviderResponse.parse(
                canonicalResponse().replace("\"other\"", "\"cooperating\"")))
                .isInstanceOf(CompleteGeneratedBundle.InvalidProviderResponseException.class);
        assertThatThrownBy(() -> CompleteGeneratedBundle.ProviderResponse.parse(
                canonicalResponse().replace("\"other\"", "\"unexpected\"")))
                .isInstanceOf(CompleteGeneratedBundle.InvalidProviderResponseException.class);
    }

    @Test
    void publicProviderParserRejectsUnsupportedVersion() {
        assertThatThrownBy(() -> CompleteGeneratedBundle.ProviderResponse.parse(
                canonicalResponse().replace(
                        CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION,
                        "custom-scene-generated-output-v2")))
                .isInstanceOf(CompleteGeneratedBundle.InvalidProviderResponseException.class);
    }

    @Test
    void publicProviderParserRejectsTrailingJsonValues() {
        assertThatThrownBy(() -> CompleteGeneratedBundle.ProviderResponse.parse(
                canonicalResponse() + "\n{}"))
                .isInstanceOf(CompleteGeneratedBundle.InvalidProviderResponseException.class);
    }

    @Test
    void serializedBundleCarriesRoleReactionAndProvenanceIndependently() throws Exception {
        var bundle = CompleteGeneratedBundle.ProviderResponse.parse(canonicalResponse())
                .toCompleteBundle(generatedProvenance());

        var json = new ObjectMapper().writeValueAsString(bundle);

        assertThat(json)
                .contains("\"role\":\"starter\"", "\"reaction\":null")
                .contains("\"role\":\"reaction_support\"", "\"reaction\":\"cooperating\"")
                .contains("\"providerProvenance\"")
                .contains("\"origin\":\"provider_generated\"")
                .contains("\"providerName\":\"primary\"", "\"modelName\":\"gpt-test\"");
    }

    @Test
    void generatorAndRepairContractsRejectUnsupportedSchemaVersions() {
        var bundle = CompleteGeneratedBundle.ProviderResponse.parse(canonicalResponse())
                .toCompleteBundle(generatedProvenance());

        assertThatThrownBy(() -> new GeneratorCompleteBundleContract.Request("unsupported-v2"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("unsupported complete generated bundle schema version");
        assertThatThrownBy(() -> new RepairCompleteBundleContract.Request("unsupported-v2", bundle))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("unsupported complete generated bundle schema version");
        assertThat(new GeneratorCompleteBundleContract.Response(bundle).bundle()).isSameAs(bundle);
        assertThat(new RepairCompleteBundleContract.Request(
                CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION, bundle).previousBundle()).isSameAs(bundle);
        assertThat(new RepairCompleteBundleContract.Response(bundle).bundle()).isSameAs(bundle);
    }

    private CompleteGeneratedBundle.ProviderProvenance generatedProvenance() {
        return new CompleteGeneratedBundle.ProviderProvenance(
                CompleteGeneratedBundle.ProviderOrigin.PROVIDER_GENERATED,
                "primary",
                "gpt-test",
                1);
    }

    private CompleteGeneratedBundle.ProviderUtterances canonicalProviderUtterances() {
        return new CompleteGeneratedBundle.ProviderUtterances(
                utterance(CompleteGeneratedBundle.UtteranceRole.STARTER, null, 1),
                support(CompleteGeneratedBundle.Reaction.COOPERATING),
                support(CompleteGeneratedBundle.Reaction.HESITANT),
                support(CompleteGeneratedBundle.Reaction.RESISTING),
                support(CompleteGeneratedBundle.Reaction.NO_RESPONSE),
                support(CompleteGeneratedBundle.Reaction.OTHER));
    }

    private CompleteGeneratedBundle.ProviderUtterance support(CompleteGeneratedBundle.Reaction reaction) {
        return utterance(
                CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                reaction,
                reaction.ordinal() + 2);
    }

    private CompleteGeneratedBundle.ProviderUtterance utterance(
            CompleteGeneratedBundle.UtteranceRole role,
            CompleteGeneratedBundle.Reaction reaction,
            int displayOrder
    ) {
        return new CompleteGeneratedBundle.ProviderUtterance(
                role,
                reaction,
                "English",
                "中文",
                "pronunciation",
                "动作",
                "引导",
                "easy",
                displayOrder);
    }

    private void assertViolationCategory(
            Runnable invocation,
            Category expectedCategory
    ) {
        assertThatThrownBy(invocation::run)
                .isInstanceOf(CompleteGeneratedBundle.ContractViolationException.class)
                .satisfies(failure -> assertThat(
                        ((CompleteGeneratedBundle.ContractViolationException) failure).category())
                        .isEqualTo(expectedCategory));
    }

    private Category contractViolationCategory(Throwable failure) {
        var current = failure;
        while (current != null) {
            if (current instanceof CompleteGeneratedBundle.ContractViolationException violation) {
                return violation.category();
            }
            current = current.getCause();
        }
        return Category.UNKNOWN;
    }

    private JsonNode resolveLocalSchema(JsonNode root, JsonNode candidate) {
        var reference = candidate.path("$ref").asText(null);
        if (reference == null || !reference.startsWith("#/")) {
            return candidate;
        }
        var resolved = root;
        for (var segment : reference.substring(2).split("/")) {
            resolved = resolved.get(segment.replace("~1", "/").replace("~0", "~"));
        }
        return resolved;
    }

    private JsonNode providerSchema() throws Exception {
        var converter = new BeanOutputConverter<>(CompleteGeneratedBundle.ProviderResponse.class);
        return new ObjectMapper().readTree(PracticeAiJsonSchemaPublisher.publish(converter));
    }

    private void assertFlatStringEnumSchema(JsonNode candidate) {
        assertThat(candidate).isNotNull();
        assertThat(candidate.has("$ref")).isFalse();
        assertThat(candidate.has("oneOf")).isFalse();
        assertThat(candidate.has("anyOf")).isFalse();
        assertThat(candidate.has("allOf")).isFalse();
        assertThat(candidate.get("enum")).isNotNull();
        assertThat(candidate.get("enum").isArray()).isTrue();
    }

    private Set<String> enumTextValues(JsonNode candidate) {
        var values = new LinkedHashSet<String>();
        var enumValues = candidate.get("enum");
        for (var value : enumValues) {
            assertThat(value.isTextual() || value.isNull()).isTrue();
            if (value.isTextual()) {
                values.add(value.textValue());
            }
        }
        return values;
    }

    private Set<String> typeNames(JsonNode candidate) {
        var values = new LinkedHashSet<String>();
        var type = candidate.get("type");
        assertThat(type).isNotNull();
        if (type.isTextual()) {
            values.add(type.textValue());
        } else {
            assertThat(type.isArray()).isTrue();
            for (var value : type) {
                assertThat(value.isTextual()).isTrue();
                values.add(value.textValue());
            }
        }
        return values;
    }

    private long nullEnumValueCount(JsonNode candidate) {
        var enumValues = candidate.get("enum");
        return java.util.stream.StreamSupport.stream(enumValues.spliterator(), false)
                .filter(JsonNode::isNull)
                .count();
    }

    private String canonicalResponse() {
        return """
                {
                  "schemaVersion": "custom-scene-generated-output-v1",
                  "scene": {
                    "spaceTitleZh": "日常照护",
                    "activityTitleZh": "穿鞋出门",
                    "sceneTagEn": "Shoes on"
                  },
                  "utterances": {
                    "starter": {
                      "role": "starter",
                      "reaction": null,
                      "englishText": "Shoes on.",
                      "chineseText": "穿鞋出门。",
                      "pronunciationHint": "shoes on",
                      "tprActionZh": "拿起鞋子。",
                      "deliveryGuidanceZh": "慢慢说。",
                      "difficulty": "starter",
                      "displayOrder": 1
                    },
                    "cooperating": {
                      "role": "reaction_support",
                      "reaction": "cooperating",
                      "englishText": "Let's put shoes on.",
                      "chineseText": "我们穿鞋。",
                      "pronunciationHint": "lets put shoes on",
                      "tprActionZh": "指向鞋子。",
                      "deliveryGuidanceZh": "轻声邀请。",
                      "difficulty": "easy",
                      "displayOrder": 2
                    },
                    "hesitant": {
                      "role": "reaction_support",
                      "reaction": "hesitant",
                      "englishText": "You can try slowly.",
                      "chineseText": "你可以慢慢试。",
                      "pronunciationHint": "you can try slowly",
                      "tprActionZh": "把鞋放近。",
                      "deliveryGuidanceZh": "留出等待。",
                      "difficulty": "easy",
                      "displayOrder": 3
                    },
                    "resisting": {
                      "role": "reaction_support",
                      "reaction": "resisting",
                      "englishText": "No shoes now is okay.",
                      "chineseText": "现在不穿也可以。",
                      "pronunciationHint": "no shoes now is okay",
                      "tprActionZh": "手掌停下。",
                      "deliveryGuidanceZh": "接住拒绝。",
                      "difficulty": "easy",
                      "displayOrder": 4
                    },
                    "no_response": {
                      "role": "reaction_support",
                      "reaction": "no_response",
                      "englishText": "I will wait with you.",
                      "chineseText": "我陪你等一等。",
                      "pronunciationHint": "i will wait with you",
                      "tprActionZh": "安静停留。",
                      "deliveryGuidanceZh": "不重复追问。",
                      "difficulty": "easy",
                      "displayOrder": 5
                    },
                    "other": {
                      "role": "reaction_support",
                      "reaction": "other",
                      "englishText": "Let's take a small pause.",
                      "chineseText": "我们先停一会儿。",
                      "pronunciationHint": "lets take a small pause",
                      "tprActionZh": "做深呼吸。",
                      "deliveryGuidanceZh": "平静收束。",
                      "difficulty": "easy",
                      "displayOrder": 6
                    }
                  }
                }
                """;
    }
}
