package com.zhangspaghetti.babytalk.practice.agentic;

import org.springframework.ai.converter.BeanOutputConverter;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "agentic"
)
public class PracticeAiStructuredOutputCaller {

    public <T> T call(
            ResolvedProvider provider,
            String systemPrompt,
            String userPrompt,
            Class<T> responseType
    ) {
        var converter = new BeanOutputConverter<>(responseType);
        var options = OpenAiChatOptions.builder()
                .responseFormat(OpenAiChatModel.ResponseFormat.builder()
                        .jsonSchema(converter.getJsonSchema())
                        .build());
        var content = provider.chatClient()
                .prompt()
                .options(options)
                .system(systemPrompt)
                .user(userPrompt)
                .call()
                .content();
        return convertOnce(content, converter);
    }

    <T> T convertOnce(String content, Class<T> responseType) {
        return convertOnce(content, new BeanOutputConverter<>(responseType));
    }

    private <T> T convertOnce(String content, BeanOutputConverter<T> converter) {
        try {
            var converted = converter.convert(content);
            if (converted == null) {
                throw new StructuredOutputInvalidException();
            }
            return converted;
        } catch (StructuredOutputInvalidException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            throw new StructuredOutputInvalidException();
        }
    }

    public static final class StructuredOutputInvalidException extends RuntimeException {
        public StructuredOutputInvalidException() {
            super("structured_output_invalid");
        }
    }
}
