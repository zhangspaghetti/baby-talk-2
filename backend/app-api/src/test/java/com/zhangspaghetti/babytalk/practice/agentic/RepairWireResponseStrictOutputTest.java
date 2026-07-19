package com.zhangspaghetti.babytalk.practice.agentic;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.practice.generated.AgenticCustomSceneRepairer;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

class RepairWireResponseStrictOutputTest {

    @Test
    void acceptsCompleteRepairPayload() {
        var converted = new PracticeAiStructuredOutputCaller().convertOnce(
                validPayload(), AgenticCustomSceneRepairer.RepairWireResponse.class);

        assertThat(converted.englishText()).isEqualTo("Shoes on.");
        assertThat(converted.difficulty()).isEqualTo("starter");
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("invalidPayloads")
    void rejectsNonConformingRepairPayload(String description, String payload) {
        assertThatThrownBy(() -> new PracticeAiStructuredOutputCaller().convertOnce(
                payload, AgenticCustomSceneRepairer.RepairWireResponse.class))
                .isInstanceOf(PracticeAiStructuredOutputCaller.StructuredOutputInvalidException.class)
                .hasMessage("structured_output_invalid");
    }

    private static Stream<Arguments> invalidPayloads() {
        return Stream.of(
                Arguments.of("malformed JSON", validPayload().substring(0, validPayload().lastIndexOf('}'))),
                Arguments.of("unknown top-level field", validPayload().replace(
                        "\"difficulty\":\"starter\"", "\"difficulty\":\"starter\",\"reason\":\"free text\"")),
                Arguments.of("missing required field", validPayload().replace(
                        ",\"deliveryGuidanceZh\":\"慢慢说。\"", "")),
                Arguments.of("blank required field", validPayload().replace(
                        "\"englishText\":\"Shoes on.\"", "\"englishText\":\" \"")),
                Arguments.of("trusted source supplied by provider", validPayload().replace(
                        "\"difficulty\":\"starter\"", "\"difficulty\":\"starter\",\"generationSource\":\"manual\"")));
    }

    private static String validPayload() {
        return """
                {"spaceTitleZh":"日常照护","activityTitleZh":"穿鞋出门","sceneTagEn":"Shoes on",
                "tprActionZh":"拿起鞋子。","deliveryGuidanceZh":"慢慢说。","englishText":"Shoes on.",
                "chineseText":"穿鞋出门。","pronunciationHint":"shoes on","difficulty":"starter"}
                """;
    }
}
