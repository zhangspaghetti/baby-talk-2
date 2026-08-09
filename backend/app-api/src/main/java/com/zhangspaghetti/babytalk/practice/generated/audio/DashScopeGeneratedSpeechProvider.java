package com.zhangspaghetti.babytalk.practice.generated.audio;

final class DashScopeGeneratedSpeechProvider implements GeneratedSpeechSynthesisPort {

    private final GeneratedSpeechProperties properties;
    private final GeneratedSpeechClient speechClient;

    DashScopeGeneratedSpeechProvider(GeneratedSpeechProperties properties, String apiKey) {
        this(properties, new DashScopeGeneratedSpeechHttpClient(properties, apiKey));
    }

    DashScopeGeneratedSpeechProvider(GeneratedSpeechProperties properties, GeneratedSpeechClient speechClient) {
        this.properties = properties;
        this.speechClient = speechClient;
    }

    @Override
    public GeneratedAudioResponse synthesize(GeneratedSpeechRequest request) {
        try {
            var audio = speechClient.synthesize(request.approvedEnglishText());
            return new GeneratedAudioResponse(audio, properties.mimeType(), properties.voiceVersion());
        } catch (GeneratedSpeechSynthesisException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            throw GeneratedSpeechSynthesisException.unavailable(null);
        }
    }
}
