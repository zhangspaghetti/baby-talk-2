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
        var responseFormat = OpenAiChatModel.ResponseFormat.builder()
                .jsonSchema(converter.getJsonSchema())
                .build();
        var options = OpenAiChatOptions.builder().responseFormat(responseFormat).build();

        assertThat(options.getResponseFormat().getJsonSchema()).isEqualTo(converter.getJsonSchema());
        assertThat(options.getResponseFormat().getType().name()).isEqualTo("JSON_SCHEMA");
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

    record Answer(String answer) {
        Answer {
            if (answer == null || answer.isBlank()) {
                throw new IllegalArgumentException("answer is required");
            }
        }
    }
}
