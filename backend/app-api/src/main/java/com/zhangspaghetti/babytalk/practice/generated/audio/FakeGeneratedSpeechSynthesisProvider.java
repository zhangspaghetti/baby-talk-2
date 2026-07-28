package com.zhangspaghetti.babytalk.practice.generated.audio;

final class FakeGeneratedSpeechSynthesisProvider implements GeneratedSpeechSynthesisPort {

    private static final byte[] FAKE_MP3_BYTES = {0x49, 0x44, 0x33, 0x04, 0x00, 0x00};

    private final GeneratedSpeechProperties properties;

    FakeGeneratedSpeechSynthesisProvider(GeneratedSpeechProperties properties) {
        this.properties = properties;
    }

    @Override
    public GeneratedAudioResponse synthesize(GeneratedSpeechRequest request) {
        return new GeneratedAudioResponse(FAKE_MP3_BYTES, properties.mimeType(), properties.voiceVersion());
    }
}
