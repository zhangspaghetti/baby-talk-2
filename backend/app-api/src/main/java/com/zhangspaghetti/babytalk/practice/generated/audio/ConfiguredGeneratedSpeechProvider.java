package com.zhangspaghetti.babytalk.practice.generated.audio;

import org.springframework.ai.openai.OpenAiAudioSpeechModel;
import org.springframework.ai.openai.OpenAiAudioSpeechOptions;

final class ConfiguredGeneratedSpeechProvider implements GeneratedSpeechSynthesisPort {

    private final GeneratedSpeechClient speechClient;
    private final GeneratedSpeechProperties properties;

    ConfiguredGeneratedSpeechProvider(GeneratedSpeechProperties properties, String apiKey) {
        this(properties, createSpeechClient(properties, requireApiKey(apiKey)));
    }

    ConfiguredGeneratedSpeechProvider(GeneratedSpeechProperties properties, GeneratedSpeechClient speechClient) {
        this.properties = properties;
        this.speechClient = speechClient;
    }

    private static GeneratedSpeechClient createSpeechClient(GeneratedSpeechProperties properties, String apiKey) {
        var options = OpenAiAudioSpeechOptions.builder()
                .baseUrl(properties.baseUrl())
                .apiKey(apiKey.trim())
                .model(properties.model())
                .voice(properties.voice())
                .responseFormat(properties.format())
                .timeout(properties.timeout())
                .maxRetries(0)
                .build();
        var speechModel = OpenAiAudioSpeechModel.builder().options(options).build();
        return speechModel::call;
    }

    private static String requireApiKey(String apiKey) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new IllegalArgumentException("generated speech provider secret must not be blank");
        }
        return apiKey.trim();
    }

    @Override
    public GeneratedAudioResponse synthesize(GeneratedSpeechRequest request) {
        try {
            var response = speechClient.synthesize(request.approvedEnglishText());
            return new GeneratedAudioResponse(response, properties.mimeType(), properties.voiceVersion());
        } catch (RuntimeException exception) {
            if (isTimeout(exception)) {
                throw GeneratedSpeechSynthesisException.timeout(exception);
            }
            throw GeneratedSpeechSynthesisException.unavailable(exception);
        }
    }

    private boolean isTimeout(RuntimeException exception) {
        for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
            if (cause instanceof java.util.concurrent.TimeoutException) {
                return true;
            }
            var message = cause.getMessage();
            if (message != null && (message.toLowerCase(java.util.Locale.ROOT).contains("timeout")
                    || message.toLowerCase(java.util.Locale.ROOT).contains("timed out"))) {
                return true;
            }
        }
        return false;
    }
}
