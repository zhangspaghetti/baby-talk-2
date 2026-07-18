package com.zhangspaghetti.babytalk.practice.agentic;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.net.URI;
import java.time.Duration;
import org.junit.jupiter.api.Test;
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

        assertThat(caller.convertOnce("{\"answer\":\"ok\"}", Answer.class))
                .isEqualTo(new Answer("ok"));
    }

    record Answer(String answer) {
    }
}
