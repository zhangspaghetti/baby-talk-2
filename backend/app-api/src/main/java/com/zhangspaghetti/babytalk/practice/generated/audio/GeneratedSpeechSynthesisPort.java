package com.zhangspaghetti.babytalk.practice.generated.audio;

public interface GeneratedSpeechSynthesisPort {

    GeneratedAudioResponse synthesize(GeneratedSpeechRequest request);

    record GeneratedSpeechRequest(String approvedEnglishText) {

        public GeneratedSpeechRequest {
            if (approvedEnglishText == null || approvedEnglishText.isBlank()) {
                throw new IllegalArgumentException("approved English text is required for generated speech");
            }
        }
    }
}
