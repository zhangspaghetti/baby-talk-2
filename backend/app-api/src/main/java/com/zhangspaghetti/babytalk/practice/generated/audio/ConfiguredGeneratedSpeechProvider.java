package com.zhangspaghetti.babytalk.practice.generated.audio;

import org.springframework.ai.openai.OpenAiAudioSpeechModel;
import org.springframework.ai.openai.OpenAiAudioSpeechOptions;

final class ConfiguredGeneratedSpeechProvider implements GeneratedSpeechSynthesisPort {

    private final OpenAiAudioSpeechModel speechModel;
    private final GeneratedSpeechProperties properties;

    ConfiguredGeneratedSpeechProvider(GeneratedSpeechProperties properties, String apiKey) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new IllegalArgumentException("generated speech provider secret must not be blank");
        }
        this.properties = properties;
        var options = OpenAiAudioSpeechOptions.builder()
                .baseUrl(properties.baseUrl())
                .apiKey(apiKey.trim())
                .model(properties.model())
                .voice(properties.voice())
                .responseFormat(properties.format())
                .timeout(properties.timeout())
                .maxRetries(0)
                .build();
        this.speechModel = OpenAiAudioSpeechModel.builder().options(options).build();
    }

    @Override
    public GeneratedAudioResponse synthesize(GeneratedSpeechRequest request) {
        try {
            var response = speechModel.call(request.approvedEnglishText());
            return new GeneratedAudioResponse(response, properties.mimeType(), properties.voiceVersion());
        } catch (RuntimeException exception) {
            if (isTimeout(exception)) {
                throw GeneratedSpeechSynthesisException.timeout(exception);
            }
            throw GeneratedSpeechSynthesisException.unavailable(exception);
        }
    }

    private boolean isTimeout(RuntimeException exception) {
        var message = exception.getMessage();
        return message != null && message.toLowerCase(java.util.Locale.ROOT).contains("timeout");
    }
}
