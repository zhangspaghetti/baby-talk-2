package com.zhangspaghetti.babytalk.practice.generated.audio;

public interface GeneratedSpeechSynthesisPort {

    GeneratedAudioResponse synthesize(GeneratedSpeechRequest request);

    record GeneratedSpeechRequest(String generatedContentId, String utteranceId, String approvedEnglishText) {

        public GeneratedSpeechRequest {
            if (generatedContentId == null || generatedContentId.isBlank()) {
                throw new IllegalArgumentException("generated content identity is required for generated speech");
            }
            if (utteranceId == null || utteranceId.isBlank()) {
                throw new IllegalArgumentException("utterance identity is required for generated speech");
            }
            if (approvedEnglishText == null || approvedEnglishText.isBlank()) {
                throw new IllegalArgumentException("approved English text is required for generated speech");
            }
        }
    }
}
