package com.zhangspaghetti.babytalk.practice.agentic;

import com.zhangspaghetti.babytalk.practice.agentic.config.PracticeAiReasoningEffort;
import java.util.Objects;
import org.springframework.ai.converter.BeanOutputConverter;
import org.springframework.ai.converter.ResponseTextCleaner;
import org.springframework.ai.chat.model.ChatResponse;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.util.JacksonUtils;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import tools.jackson.core.StreamReadFeature;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.MapperFeature;
import tools.jackson.databind.cfg.EnumFeature;
import tools.jackson.databind.json.JsonMapper;

@Component
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "agentic"
)
public class PracticeAiStructuredOutputCaller {

    private static final Logger LOGGER = LoggerFactory.getLogger(PracticeAiStructuredOutputCaller.class);
    private static final JsonMapper STRICT_JSON_MAPPER = JsonMapper.builder()
            .addModules(JacksonUtils.instantiateAvailableModules())
            .enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
            .enable(EnumFeature.FAIL_ON_NUMBERS_FOR_ENUMS)
            .disable(MapperFeature.ALLOW_COERCION_OF_SCALARS)
            .enable(StreamReadFeature.STRICT_DUPLICATE_DETECTION)
            .build();
    private static final ResponseTextCleaner IDENTITY_TEXT_CLEANER = content -> content;

    public <T> T call(
            ResolvedProvider provider,
            String systemPrompt,
            String userPrompt,
            Class<T> responseType
    ) {
        return call(provider, systemPrompt, userPrompt, responseType, null);
    }

    private <T> T call(
            ResolvedProvider provider,
            String systemPrompt,
            String userPrompt,
            Class<T> responseType,
            PracticeAiReasoningEffort reasoningEffort
    ) {
        var converter = strictConverter(responseType);
        var options = OpenAiChatOptions.builder()
                .responseFormat(OpenAiChatModel.ResponseFormat.builder()
                        .jsonSchema(PracticeAiJsonSchemaPublisher.publish(converter, responseType))
                        .build());
        if (reasoningEffort != null) {
            options.reasoningEffort(reasoningEffort.wireValue());
        }
        var response = provider.chatClient()
                .prompt()
                .options(options)
                .system(systemPrompt)
                .user(userPrompt)
                .call()
                .chatResponse();
        var metadata = ProviderResponseMetadata.from(response);
        if (metadata.finishReason() == FinishReason.LENGTH) {
            throw invalid(metadata);
        }
        return convertOnce(content(response), converter, metadata);
    }

    /** Calls one typed structured-output request after enforcing its versioned safe budget floor. */
    public <T> T call(
            ResolvedProvider provider,
            String systemPrompt,
            String userPrompt,
            Class<T> responseType,
            int minimumOutputTokens
    ) {
        requireOutputBudget(provider, minimumOutputTokens);
        return call(provider, systemPrompt, userPrompt, responseType);
    }

    /**
     * Calls one typed structured-output request with a bounded explicit reasoning control.
     * Callers must apply provider/model compatibility policy before selecting this overload.
     */
    public <T> T call(
            ResolvedProvider provider,
            String systemPrompt,
            String userPrompt,
            Class<T> responseType,
            int minimumOutputTokens,
            PracticeAiReasoningEffort reasoningEffort
    ) {
        requireOutputBudget(provider, minimumOutputTokens);
        return call(
                provider,
                systemPrompt,
                userPrompt,
                responseType,
                Objects.requireNonNull(reasoningEffort, "reasoningEffort"));
    }

    /**
     * Gets one schema-constrained provider payload without converting it. Callers with a stricter
     * domain parser must use this path so no generic DTO conversion can weaken that contract.
     */
    public <T> String callRaw(
            ResolvedProvider provider,
            String systemPrompt,
            String userPrompt,
            Class<T> responseType
    ) {
        return callRaw(provider, systemPrompt, userPrompt, responseType, null);
    }

    private <T> String callRaw(
            ResolvedProvider provider,
            String systemPrompt,
            String userPrompt,
            Class<T> responseType,
            PracticeAiReasoningEffort reasoningEffort
    ) {
        var converter = strictConverter(responseType);
        var options = OpenAiChatOptions.builder()
                .responseFormat(OpenAiChatModel.ResponseFormat.builder()
                        .jsonSchema(PracticeAiJsonSchemaPublisher.publish(converter, responseType))
                        .build());
        if (reasoningEffort != null) {
            options.reasoningEffort(reasoningEffort.wireValue());
        }
        var response = provider.chatClient()
                .prompt()
                .options(options)
                .system(systemPrompt)
                .user(userPrompt)
                .call()
                .chatResponse();
        var metadata = ProviderResponseMetadata.from(response);
        var content = content(response);
        if (metadata.finishReason() == FinishReason.LENGTH || content == null || content.isBlank()) {
            throw invalid(metadata);
        }
        return content;
    }

    /**
     * Gets one complete schema-constrained payload after enforcing a versioned safe output-budget
     * floor. The configured maximum remains a limit and does not imply actual token consumption.
     */
    public <T> String callRaw(
            ResolvedProvider provider,
            String systemPrompt,
            String userPrompt,
            Class<T> responseType,
            int minimumOutputTokens
    ) {
        requireOutputBudget(provider, minimumOutputTokens);
        return callRaw(provider, systemPrompt, userPrompt, responseType);
    }

    /**
     * Gets one complete schema-constrained payload with a bounded explicit reasoning control.
     * Callers must apply provider/model compatibility policy before selecting this overload.
     */
    public <T> String callRaw(
            ResolvedProvider provider,
            String systemPrompt,
            String userPrompt,
            Class<T> responseType,
            int minimumOutputTokens,
            PracticeAiReasoningEffort reasoningEffort
    ) {
        requireOutputBudget(provider, minimumOutputTokens);
        return callRaw(
                provider,
                systemPrompt,
                userPrompt,
                responseType,
                Objects.requireNonNull(reasoningEffort, "reasoningEffort"));
    }

    private void requireOutputBudget(ResolvedProvider provider, int minimumOutputTokens) {
        Objects.requireNonNull(provider, "provider");
        if (minimumOutputTokens <= 0) {
            throw new IllegalArgumentException("minimumOutputTokens must be positive");
        }
        if (provider.outputTokenLimit() < minimumOutputTokens) {
            LOGGER.warn(
                    "Practice AI output budget rejected before request: configuredLimit={}, safeMinimum={}",
                    provider.outputTokenLimit(),
                    minimumOutputTokens);
            throw new OutputBudgetTooSmallException(provider.outputTokenLimit(), minimumOutputTokens);
        }
    }

    <T> T convertOnce(String content, Class<T> responseType) {
        return convertOnce(content, strictConverter(responseType), ProviderResponseMetadata.unknown());
    }

    private <T> BeanOutputConverter<T> strictConverter(Class<T> responseType) {
        return new BeanOutputConverter<>(responseType, STRICT_JSON_MAPPER, IDENTITY_TEXT_CLEANER);
    }

    private String content(ChatResponse response) {
        if (response == null || response.getResult() == null || response.getResult().getOutput() == null) {
            return null;
        }
        return response.getResult().getOutput().getText();
    }

    private <T> T convertOnce(
            String content,
            BeanOutputConverter<T> converter,
            ProviderResponseMetadata metadata
    ) {
        try {
            var converted = converter.convert(content);
            if (converted == null) {
                throw invalid(metadata);
            }
            return converted;
        } catch (StructuredOutputInvalidException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            throw invalid(metadata);
        }
    }

    private StructuredOutputInvalidException invalid(ProviderResponseMetadata metadata) {
        var failureCode = metadata.finishReason() == FinishReason.LENGTH
                ? "output_truncated"
                : "structured_output_invalid";
        LOGGER.warn(
                "Practice AI structured output rejected: failureCode={}, finishReason={}, "
                        + "promptTokens={}, completionTokens={}, totalTokens={}",
                failureCode,
                metadata.finishReason(),
                metadata.promptTokens(),
                metadata.completionTokens(),
                metadata.totalTokens());
        return new StructuredOutputInvalidException(failureCode, metadata);
    }

    public enum FinishReason {
        STOP,
        LENGTH,
        CONTENT_FILTER,
        TOOL_CALLS,
        OTHER,
        UNKNOWN;

        private static FinishReason from(String value) {
            if (value == null || value.isBlank()) {
                return UNKNOWN;
            }
            return switch (value.trim().toLowerCase(java.util.Locale.ROOT)) {
                case "stop" -> STOP;
                case "length" -> LENGTH;
                case "content_filter" -> CONTENT_FILTER;
                case "tool_calls", "function_call" -> TOOL_CALLS;
                default -> OTHER;
            };
        }
    }

    public record ProviderResponseMetadata(
            FinishReason finishReason,
            Integer promptTokens,
            Integer completionTokens,
            Integer totalTokens
    ) {
        private static ProviderResponseMetadata from(ChatResponse response) {
            if (response == null) {
                return unknown();
            }
            var result = response.getResult();
            var finishReason = result == null || result.getMetadata() == null
                    ? FinishReason.UNKNOWN
                    : FinishReason.from(result.getMetadata().getFinishReason());
            var responseMetadata = response.getMetadata();
            var usage = responseMetadata == null ? null : responseMetadata.getUsage();
            return new ProviderResponseMetadata(
                    finishReason,
                    usage == null ? null : nonNegative(usage.getPromptTokens()),
                    usage == null ? null : nonNegative(usage.getCompletionTokens()),
                    usage == null ? null : nonNegative(usage.getTotalTokens()));
        }

        private static ProviderResponseMetadata unknown() {
            return new ProviderResponseMetadata(FinishReason.UNKNOWN, null, null, null);
        }

        private static Integer nonNegative(Integer value) {
            return value == null || value < 0 ? null : value;
        }
    }

    public static final class StructuredOutputInvalidException extends RuntimeException {
        private final String failureCode;
        private final ProviderResponseMetadata providerResponseMetadata;

        public StructuredOutputInvalidException() {
            this("structured_output_invalid", ProviderResponseMetadata.unknown());
        }

        private StructuredOutputInvalidException(
                String failureCode,
                ProviderResponseMetadata providerResponseMetadata
        ) {
            super(failureCode);
            this.failureCode = failureCode;
            this.providerResponseMetadata = providerResponseMetadata;
        }

        public String failureCode() {
            return failureCode;
        }

        public ProviderResponseMetadata providerResponseMetadata() {
            return providerResponseMetadata;
        }
    }

    public static final class OutputBudgetTooSmallException extends RuntimeException {
        private final int configuredLimit;
        private final int safeMinimum;

        private OutputBudgetTooSmallException(int configuredLimit, int safeMinimum) {
            super("output_budget_too_small");
            this.configuredLimit = configuredLimit;
            this.safeMinimum = safeMinimum;
        }

        public int configuredLimit() {
            return configuredLimit;
        }

        public int safeMinimum() {
            return safeMinimum;
        }
    }
}
