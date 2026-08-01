package com.zhangspaghetti.babytalk.practice.agentic;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.net.URI;
import java.time.Duration;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.ai.converter.BeanOutputConverter;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;

class PracticeAiStructuredOutputCallerTest {

    @Test
    void springAiTwoJsonSchemaCompileContractSelectsJsonSchemaMode() {
        var converter = new BeanOutputConverter<>(Answer.class);
        var publishedSchema = PracticeAiJsonSchemaPublisher.publish(converter);
        var responseFormat = OpenAiChatModel.ResponseFormat.builder()
                .jsonSchema(publishedSchema)
                .build();
        var options = OpenAiChatOptions.builder().responseFormat(responseFormat).build();

        assertThat(options.getResponseFormat().getJsonSchema()).isEqualTo(publishedSchema);
        assertThat(options.getResponseFormat().getType().name()).isEqualTo("JSON_SCHEMA");
    }

    @Test
    void schemaPublisherAcceptsMaximumTraversalDepth() {
        assertThat(PracticeAiJsonSchemaPublisher.publish(
                        nestedSchema(PracticeAiJsonSchemaPublisher.MAX_SCHEMA_DEPTH)))
                .isNotBlank();
    }

    @Test
    void schemaPublisherRejectsTraversalBeyondMaximumDepth() {
        assertThatThrownBy(() -> PracticeAiJsonSchemaPublisher.publish(
                        nestedSchema(PracticeAiJsonSchemaPublisher.MAX_SCHEMA_DEPTH + 1)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("practice_ai_json_schema_too_complex");
    }

    @Test
    void schemaPublisherRejectsTraversalBeyondMaximumNodeCount() {
        assertThatThrownBy(() -> PracticeAiJsonSchemaPublisher.publish(
                        wideSchema(PracticeAiJsonSchemaPublisher.MAX_SCHEMA_NODES)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("practice_ai_json_schema_too_complex");
    }

    @Test
    void conversionFailureIsTypedStructuredOutputInvalid() {
        var caller = new PracticeAiStructuredOutputCaller();

        assertThatThrownBy(() -> caller.convertOnce("not-json", Answer.class))
                .isInstanceOf(PracticeAiStructuredOutputCaller.StructuredOutputInvalidException.class)
                .hasMessage("structured_output_invalid");
    }

    @Test
    void convertsValidContentOnce() {
        var caller = new PracticeAiStructuredOutputCaller();

        assertThat(caller.convertOnce("  \n{\"answer\":\"ok\"}\r\n  ", Answer.class))
                .isEqualTo(new Answer("ok"));
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("invalidStrictPayloads")
    void strictConversionRejectsNonConformingPayload(String description, String payload) {
        var caller = new PracticeAiStructuredOutputCaller();

        assertThatThrownBy(() -> caller.convertOnce(payload, Answer.class))
                .isInstanceOf(PracticeAiStructuredOutputCaller.StructuredOutputInvalidException.class)
                .hasMessage("structured_output_invalid");
    }

    private static Stream<Arguments> invalidStrictPayloads() {
        return Stream.of(
                Arguments.of("markdown fenced JSON", "```json\n{\"answer\":\"ok\"}\n```"),
                Arguments.of("unknown extra field", "{\"answer\":\"ok\",\"extra\":true}"),
                Arguments.of("missing required field", "{}"),
                Arguments.of("explicit null", "{\"answer\":null}"),
                Arguments.of("malformed JSON", "{\"answer\":\"ok\""));
    }

    private static String nestedSchema(int depth) {
        var schema = "{}";
        for (var index = 0; index < depth; index++) {
            schema = "{\"items\":" + schema + "}";
        }
        return schema;
    }

    private static String wideSchema(int childCount) {
        var schema = new StringBuilder("{\"anyOf\":[");
        for (var index = 0; index < childCount; index++) {
            if (index > 0) {
                schema.append(',');
            }
            schema.append("{}");
        }
        return schema.append("]}").toString();
    }

    record Answer(String answer) {
        Answer {
            if (answer == null || answer.isBlank()) {
                throw new IllegalArgumentException("answer is required");
            }
        }
    }
}
