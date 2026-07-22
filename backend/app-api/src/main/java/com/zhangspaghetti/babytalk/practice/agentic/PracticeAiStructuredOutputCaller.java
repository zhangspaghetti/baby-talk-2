package com.zhangspaghetti.babytalk.practice.agentic;

import org.springframework.ai.converter.BeanOutputConverter;
import org.springframework.ai.converter.ResponseTextCleaner;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.util.JacksonUtils;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.json.JsonMapper;

@Component
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "agentic"
)
public class PracticeAiStructuredOutputCaller {

    private static final JsonMapper STRICT_JSON_MAPPER = JsonMapper.builder()
            .addModules(JacksonUtils.instantiateAvailableModules())
            .enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            .build();
    private static final ResponseTextCleaner IDENTITY_TEXT_CLEANER = content -> content;

    public <T> T call(
            ResolvedProvider provider,
            String systemPrompt,
            String userPrompt,
            Class<T> responseType
    ) {
        var converter = strictConverter(responseType);
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
        return convertOnce(content, strictConverter(responseType));
    }

    private <T> BeanOutputConverter<T> strictConverter(Class<T> responseType) {
        return new BeanOutputConverter<>(responseType, STRICT_JSON_MAPPER, IDENTITY_TEXT_CLEANER);
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
