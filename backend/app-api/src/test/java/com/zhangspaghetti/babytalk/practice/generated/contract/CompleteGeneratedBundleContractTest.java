package com.zhangspaghetti.babytalk.practice.generated.contract;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;
import org.springframework.ai.converter.BeanOutputConverter;
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
        var schema = new ObjectMapper().readTree(new BeanOutputConverter<>(
                CompleteGeneratedBundle.ProviderResponse.class).getJsonSchema());
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
