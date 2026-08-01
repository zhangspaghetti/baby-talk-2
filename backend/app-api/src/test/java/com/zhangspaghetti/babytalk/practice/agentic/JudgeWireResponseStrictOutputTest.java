package com.zhangspaghetti.babytalk.practice.agentic;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.practice.generated.AgenticCustomSceneQualityJudge;
import java.util.List;
import java.util.function.Consumer;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.ai.converter.BeanOutputConverter;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.node.ArrayNode;
import tools.jackson.databind.node.ObjectNode;

class JudgeWireResponseStrictOutputTest {

    @Test
    void publishedJudgeSchemaMatchesStrictConverterContract() {
        var schema = publishedSchema();
        var properties = schema.path("properties");
        var dimensions = properties.path("dimensionResults");

        assertThat(textValues(schema.path("required"))).containsExactlyInAnyOrder(
                "suggestedVerdict",
                "dimensionResults",
                "violationCodes",
                "repairDirectives",
                "evidenceGapCodes",
                "confidence");
        assertThat(textValues(properties.path("suggestedVerdict").path("enum")))
                .containsExactly("PASS", "REPAIR", "REJECT", "ABSTAIN");
        assertThat(dimensions.path("type").asText()).isEqualTo("object");
        assertThat(dimensions.path("additionalProperties").isBoolean()).isTrue();
        assertThat(dimensions.path("additionalProperties").asBoolean()).isFalse();
        assertThat(textValues(dimensions.path("required"))).containsExactly(
                "SCENE_ALIGNMENT",
                "PARENT_SPEAKABILITY",
                "NON_COURSE_FRAMING",
                "TPR_QUALITY",
                "DELIVERY_GUIDANCE_QUALITY",
                "AGE_SUITABILITY",
                "BILINGUAL_CONSISTENCY",
                "LOW_PRESSURE_SUPPORT");
        for (var dimension : textValues(dimensions.path("required"))) {
            assertThat(textValues(dimensions.path("properties").path(dimension).path("enum")))
                    .containsExactly("PASS", "FAIL", "ABSTAIN");
        }
        assertThat(textValues(properties.path("violationCodes").path("items").path("enum")))
                .containsExactly(
                        "SCENE_ALIGNMENT_FAILED",
                        "PARENT_SPEAKABILITY_FAILED",
                        "NON_COURSE_FRAMING_FAILED",
                        "TPR_QUALITY_FAILED",
                        "DELIVERY_GUIDANCE_QUALITY_FAILED",
                        "AGE_SUITABILITY_FAILED",
                        "BILINGUAL_CONSISTENCY_FAILED",
                        "LOW_PRESSURE_SUPPORT_FAILED");
        assertThat(textValues(properties.path("repairDirectives").path("items").path("enum")))
                .containsExactly(
                        "REPAIR_SCENE_ALIGNMENT",
                        "REPAIR_PARENT_SPEAKABILITY",
                        "REPAIR_NON_COURSE_FRAMING",
                        "REPAIR_TPR_QUALITY",
                        "REPAIR_DELIVERY_GUIDANCE_QUALITY",
                        "REPAIR_AGE_SUITABILITY",
                        "REPAIR_BILINGUAL_CONSISTENCY",
                        "REPAIR_LOW_PRESSURE_SUPPORT");
        assertThat(textValues(properties.path("evidenceGapCodes").path("items").path("enum")))
                .containsExactly(
                        "SCENE_ALIGNMENT_EVIDENCE_MISSING",
                        "PARENT_SPEAKABILITY_EVIDENCE_MISSING",
                        "NON_COURSE_FRAMING_EVIDENCE_MISSING",
                        "TPR_QUALITY_EVIDENCE_MISSING",
                        "DELIVERY_GUIDANCE_QUALITY_EVIDENCE_MISSING",
                        "AGE_SUITABILITY_EVIDENCE_MISSING",
                        "BILINGUAL_CONSISTENCY_EVIDENCE_MISSING",
                        "LOW_PRESSURE_SUPPORT_EVIDENCE_MISSING");
        assertThat(properties.path("confidence").path("type").asText()).isEqualTo("number");
        assertThat(properties.path("confidence").path("minimum").doubleValue()).isZero();
        assertThat(properties.path("confidence").path("maximum").doubleValue()).isEqualTo(1.0d);
    }

    @Test
    void judgeSchemaRefinerRejectsDimensionMapBaseSchemaDrift() {
        assertBaseSchemaRejected(schema -> dimensionSchema(schema).put("additionalProperties", true));
        assertBaseSchemaRejected(schema -> dimensionSchema(schema).put("additionalProperties", false));
        assertBaseSchemaRejected(schema -> dimensionSchema(schema).put("type", "array"));
        assertBaseSchemaRejected(schema -> dimensionSchema(schema)
                .putObject("properties")
                .putObject("UNKNOWN_DIMENSION")
                .put("type", "string"));
    }

    @Test
    void judgeSchemaRefinerRejectsTopLevelPropertyAndRequiredDrift() {
        assertBaseSchemaRejected(schema -> ((ObjectNode) schema.path("properties"))
                .putObject("unexpectedField")
                .put("type", "string"));
        assertBaseSchemaRejected(schema -> ((ObjectNode) schema.path("properties")).remove("confidence"));
        assertBaseSchemaRejected(schema -> ((ArrayNode) schema.path("required")).add("unexpectedField"));
        assertBaseSchemaRejected(schema -> removeTextValue(
                (ArrayNode) schema.path("required"), "confidence"));
    }

    @Test
    void judgeSchemaRefinerRejectsBrokenLocalEnumReference() {
        assertBaseSchemaRejected(schema -> {
            var verdict = (ObjectNode) schema.path("properties").path("suggestedVerdict");
            verdict.removeAll();
            verdict.put("$ref", "#/$defs/missing-verdict");
        });
    }

    @Test
    void judgeSchemaRefinerRejectsConfidenceBaseSchemaDrift() {
        assertBaseSchemaRejected(schema -> confidenceSchema(schema)
                .putArray("type")
                .add("number")
                .add("null"));
        assertBaseSchemaRejected(schema -> confidenceSchema(schema).put("type", "string"));
        assertBaseSchemaRejected(schema -> confidenceSchema(schema).put("minimum", 0.0d));
        assertBaseSchemaRejected(schema -> confidenceSchema(schema).put("maximum", 1.0d));
    }

    @Test
    void judgeSchemaRefinerRejectsUnknownBaseSchemaKeywords() {
        assertBaseSchemaRejected(schema -> schema.put("title", "unexpected constraint"));
        assertBaseSchemaRejected(schema -> dimensionSchema(schema).put("minProperties", 8));
        assertBaseSchemaRejected(schema -> violationSchema(schema).put("minItems", 1));
        assertBaseSchemaRejected(schema -> violationItemsSchema(schema).put("pattern", ".*"));
        assertBaseSchemaRejected(schema -> repairItemsSchema(schema).put("pattern", ".*"));
        assertBaseSchemaRejected(schema -> confidenceSchema(schema).put("multipleOf", 0.5d));
    }

    @Test
    void publishedJudgeSchemaStaysInsidePublisherSafetyBudget() {
        var schema = publishedSchema();

        assertThat(nodeCount(schema)).isLessThanOrEqualTo(PracticeAiJsonSchemaPublisher.MAX_SCHEMA_NODES);
        assertThat(maxDepth(schema)).isLessThanOrEqualTo(PracticeAiJsonSchemaPublisher.MAX_SCHEMA_DEPTH);
    }

    @Test
    void acceptsOneCompleteStrictJudgePayload() {
        var converted = new PracticeAiStructuredOutputCaller().convertOnce(
                validPayload(), AgenticCustomSceneQualityJudge.JudgeWireResponse.class);

        assertThat(converted.dimensionResults()).hasSize(8);
        assertThat(converted.confidence()).isEqualTo(0.9d);
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("invalidPayloads")
    void rejectsNonConformingJudgePayload(String description, String payload) {
        var caller = new PracticeAiStructuredOutputCaller();

        assertThatThrownBy(() -> caller.convertOnce(
                payload, AgenticCustomSceneQualityJudge.JudgeWireResponse.class))
                .isInstanceOf(PracticeAiStructuredOutputCaller.StructuredOutputInvalidException.class)
                .hasMessage("structured_output_invalid");
    }

    private static Stream<Arguments> invalidPayloads() {
        return Stream.of(
                Arguments.of("malformed JSON", validPayload().substring(0, validPayload().lastIndexOf('}'))),
                Arguments.of("unknown top-level field", validPayload().replace(
                        "\"confidence\":0.9", "\"confidence\":0.9,\"reason\":\"free text\"")),
                Arguments.of("unknown dimension", validPayload().replace(
                        "\"LOW_PRESSURE_SUPPORT\":\"PASS\"",
                        "\"LOW_PRESSURE_SUPPORT\":\"PASS\",\"MODEL_REASONING\":\"PASS\"")),
                Arguments.of("missing dimension", validPayload().replace(
                        ",\"LOW_PRESSURE_SUPPORT\":\"PASS\"", "")),
                Arguments.of("missing confidence", validPayload().replace(",\"confidence\":0.9", "")),
                Arguments.of("invalid confidence", validPayload().replace("\"confidence\":0.9", "\"confidence\":1.1")),
                Arguments.of("unknown dimension result", validPayload().replace(
                        "\"SCENE_ALIGNMENT\":\"PASS\"", "\"SCENE_ALIGNMENT\":\"MAYBE\"")),
                Arguments.of("numeric suggested verdict", validPayload().replace(
                        "\"suggestedVerdict\":\"PASS\"", "\"suggestedVerdict\":0")),
                Arguments.of("numeric dimension result", validPayload().replace(
                        "\"SCENE_ALIGNMENT\":\"PASS\"", "\"SCENE_ALIGNMENT\":0")),
                Arguments.of("unknown violation code", validPayload().replace(
                        "\"violationCodes\":[]",
                        "\"violationCodes\":[\"FREE_FORM_VIOLATION\"]")),
                Arguments.of("numeric repair directive", validPayload().replace(
                        "\"repairDirectives\":[]", "\"repairDirectives\":[0]")),
                Arguments.of("unknown repair directive", validPayload().replace(
                        "\"repairDirectives\":[]",
                        "\"repairDirectives\":[\"FREE_FORM_REPAIR\"]")),
                Arguments.of("numeric evidence gap", validPayload().replace(
                        "\"evidenceGapCodes\":[]", "\"evidenceGapCodes\":[0]")),
                Arguments.of("unknown evidence gap", validPayload().replace(
                        "\"evidenceGapCodes\":[]",
                        "\"evidenceGapCodes\":[\"FREE_FORM_GAP\"]")),
                Arguments.of("string confidence", validPayload().replace(
                        "\"confidence\":0.9", "\"confidence\":\"0.9\"")));
    }

    private static String validPayload() {
        return """
                {"suggestedVerdict":"PASS","dimensionResults":{
                "SCENE_ALIGNMENT":"PASS","PARENT_SPEAKABILITY":"PASS",
                "NON_COURSE_FRAMING":"PASS","TPR_QUALITY":"PASS",
                "DELIVERY_GUIDANCE_QUALITY":"PASS","AGE_SUITABILITY":"PASS",
                "BILINGUAL_CONSISTENCY":"PASS","LOW_PRESSURE_SUPPORT":"PASS"},
                "violationCodes":[],"repairDirectives":[],"evidenceGapCodes":[],"confidence":0.9}
                """;
    }

    private static List<String> textValues(JsonNode values) {
        return java.util.stream.StreamSupport.stream(values.spliterator(), false)
                .map(JsonNode::asText)
                .toList();
    }

    private static ObjectNode publishedSchema() {
        var converter = new BeanOutputConverter<>(AgenticCustomSceneQualityJudge.JudgeWireResponse.class);
        return (ObjectNode) new ObjectMapper().readTree(PracticeAiJsonSchemaPublisher.publish(
                converter, AgenticCustomSceneQualityJudge.JudgeWireResponse.class));
    }

    private static ObjectNode baseSchema() {
        var converter = new BeanOutputConverter<>(AgenticCustomSceneQualityJudge.JudgeWireResponse.class);
        return (ObjectNode) new ObjectMapper().readTree(converter.getJsonSchema());
    }

    private static ObjectNode dimensionSchema(ObjectNode schema) {
        return (ObjectNode) schema.path("properties").path("dimensionResults");
    }

    private static ObjectNode confidenceSchema(ObjectNode schema) {
        return (ObjectNode) schema.path("properties").path("confidence");
    }

    private static ObjectNode violationSchema(ObjectNode schema) {
        return (ObjectNode) schema.path("properties").path("violationCodes");
    }

    private static ObjectNode violationItemsSchema(ObjectNode schema) {
        return (ObjectNode) violationSchema(schema).path("items");
    }

    private static ObjectNode repairItemsSchema(ObjectNode schema) {
        return (ObjectNode) schema.path("properties").path("repairDirectives").path("items");
    }

    private static void assertBaseSchemaRejected(Consumer<ObjectNode> mutation) {
        var schema = baseSchema();
        mutation.accept(schema);

        assertThatThrownBy(() -> new AgenticCustomSceneQualityJudge.JudgeWireResponseSchemaRefiner()
                .refine(schema))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("custom_scene_quality_judge_provider_schema_invalid");
    }

    private static void removeTextValue(ArrayNode values, String expected) {
        for (var index = 0; index < values.size(); index++) {
            if (expected.equals(values.get(index).asText())) {
                values.remove(index);
                return;
            }
        }
        throw new IllegalArgumentException("required test value is missing");
    }

    private static int nodeCount(JsonNode node) {
        var count = 1;
        for (var child : node) {
            count += nodeCount(child);
        }
        return count;
    }

    private static int maxDepth(JsonNode node) {
        var childDepth = 0;
        for (var child : node) {
            childDepth = Math.max(childDepth, maxDepth(child));
        }
        return childDepth + 1;
    }
}
