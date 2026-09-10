package com.zhangspaghetti.babytalk.practice.generated.audio;

final class DisabledGeneratedSpeechSynthesisProvider implements GeneratedSpeechSynthesisPort {

    @Override
    public GeneratedAudioResponse synthesize(GeneratedSpeechRequest request) {
        throw GeneratedSpeechSynthesisException.disabled();
    }
}
