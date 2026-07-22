package com.zhangspaghetti.babytalk.practice.agentic;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.practice.generated.AgenticCustomSceneQualityJudge;
import java.util.stream.Stream;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

class JudgeWireResponseStrictOutputTest {

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
                Arguments.of("unknown repair directive", validPayload().replace(
                        "\"repairDirectives\":[]",
                        "\"repairDirectives\":[\"FREE_FORM_REPAIR\"]")),
                Arguments.of("unknown evidence gap", validPayload().replace(
                        "\"evidenceGapCodes\":[]",
                        "\"evidenceGapCodes\":[\"FREE_FORM_GAP\"]")));
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
}
