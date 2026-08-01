package com.zhangspaghetti.babytalk.practice.agentic;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.RETURNS_DEEP_STUBS;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.net.URI;
import java.time.Duration;
import java.util.ArrayList;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.model.ChatResponse;
import org.springframework.ai.chat.prompt.ChatOptions;
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
    void schemaPublisherAppliesNodeBudgetAfterDeclaredRefinement() {
        var converter = new BeanOutputConverter<>(OverBudgetRefinedAnswer.class);

        assertThatThrownBy(() -> PracticeAiJsonSchemaPublisher.publish(
                        converter, OverBudgetRefinedAnswer.class))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("practice_ai_json_schema_too_complex");
    }

    @Test
    void schemaPublisherAppliesDepthBudgetAfterDeclaredRefinement() {
        var converter = new BeanOutputConverter<>(OverDepthRefinedAnswer.class);

        assertThatThrownBy(() -> PracticeAiJsonSchemaPublisher.publish(
                        converter, OverDepthRefinedAnswer.class))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("practice_ai_json_schema_too_complex");
    }

    @Test
    void schemaPublisherWrapsRefinerConstructionFailure() {
        var converter = new BeanOutputConverter<>(UnconstructableRefinedAnswer.class);

        assertThatThrownBy(() -> PracticeAiJsonSchemaPublisher.publish(
                        converter, UnconstructableRefinedAnswer.class))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("practice_ai_json_schema_refiner_invalid");
    }

    @Test
    @SuppressWarnings({"rawtypes", "unchecked"})
    void callAndCallRawSendDeclaredRefinedSchema() {
        var capturedSchemas = new ArrayList<String>();
        var chatClient = mock(ChatClient.class);
        var request = mock(ChatClient.ChatClientRequestSpec.class);
        var callResponse = mock(ChatClient.CallResponseSpec.class);
        var response = mock(ChatResponse.class, RETURNS_DEEP_STUBS);
        when(chatClient.prompt()).thenReturn(request);
        doAnswer(invocation -> {
            ChatOptions.Builder<?> optionsBuilder = invocation.getArgument(0);
            var options = (OpenAiChatOptions) optionsBuilder.build();
            capturedSchemas.add(options.getResponseFormat().getJsonSchema());
            return request;
        }).when(request).options(any(ChatOptions.Builder.class));
        when(request.system(any(String.class))).thenReturn(request);
        when(request.user(any(String.class))).thenReturn(request);
        when(request.call()).thenReturn(callResponse);
        when(callResponse.chatResponse()).thenReturn(response);
        when(response.getResult().getOutput().getText()).thenReturn("{\"answer\":\"ok\"}");
        var provider = new ResolvedProvider("provider", "openai", "model", chatClient);
        var caller = new PracticeAiStructuredOutputCaller();

        assertThat(caller.call(provider, "system", "user", CapturedRefinedAnswer.class).answer())
                .isEqualTo("ok");
        assertThat(caller.callRaw(provider, "system", "user", CapturedRefinedAnswer.class))
                .isEqualTo("{\"answer\":\"ok\"}");

        assertThat(capturedSchemas).hasSize(2);
        capturedSchemas.forEach(schema -> assertThat(schema)
                .contains("\"title\":\"declared-refiner-applied\""));
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

    @PracticeAiJsonSchemaPublisher.RefinedBy(OverBudgetRefiner.class)
    record OverBudgetRefinedAnswer(String answer) {
    }

    public static final class OverBudgetRefiner
            implements PracticeAiJsonSchemaPublisher.SchemaRefiner {

        @Override
        public void refine(tools.jackson.databind.node.ObjectNode schema) {
            var expansion = schema.putArray("refinerExpansion");
            for (var index = 0; index < PracticeAiJsonSchemaPublisher.MAX_SCHEMA_NODES; index++) {
                expansion.addObject();
            }
        }
    }

    @PracticeAiJsonSchemaPublisher.RefinedBy(OverDepthRefiner.class)
    record OverDepthRefinedAnswer(String answer) {
    }

    public static final class OverDepthRefiner
            implements PracticeAiJsonSchemaPublisher.SchemaRefiner {

        @Override
        public void refine(tools.jackson.databind.node.ObjectNode schema) {
            var current = schema;
            for (var index = 0; index <= PracticeAiJsonSchemaPublisher.MAX_SCHEMA_DEPTH; index++) {
                current = current.putObject("nested");
            }
        }
    }

    @PracticeAiJsonSchemaPublisher.RefinedBy(UnconstructableRefiner.class)
    record UnconstructableRefinedAnswer(String answer) {
    }

    public static final class UnconstructableRefiner
            implements PracticeAiJsonSchemaPublisher.SchemaRefiner {

        private UnconstructableRefiner() {
        }

        @Override
        public void refine(tools.jackson.databind.node.ObjectNode schema) {
            schema.put("title", "unreachable");
        }
    }

    @PracticeAiJsonSchemaPublisher.RefinedBy(CapturedSchemaRefiner.class)
    record CapturedRefinedAnswer(String answer) {
    }

    public static final class CapturedSchemaRefiner
            implements PracticeAiJsonSchemaPublisher.SchemaRefiner {

        @Override
        public void refine(tools.jackson.databind.node.ObjectNode schema) {
            schema.put("title", "declared-refiner-applied");
        }
    }
}
