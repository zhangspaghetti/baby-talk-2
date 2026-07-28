package com.zhangspaghetti.babytalk.practice.generated.audio;

import java.util.Arrays;
import java.util.Objects;

/** Response generated in-memory for one authorized, approved bundle utterance. */
public record GeneratedUtteranceAudio(
        byte[] bytes,
        String mimeType,
        String voiceVersion,
        GeneratedSpeechConfigurationIdentity configurationIdentity
) {

    public GeneratedUtteranceAudio {
        if (bytes == null || bytes.length == 0) {
            throw new IllegalArgumentException("generated utterance audio bytes are required");
        }
        if (mimeType == null || mimeType.isBlank()) {
            throw new IllegalArgumentException("generated utterance audio MIME type is required");
        }
        if (voiceVersion == null || voiceVersion.isBlank()) {
            throw new IllegalArgumentException("generated utterance audio voice version is required");
        }
        bytes = Arrays.copyOf(bytes, bytes.length);
        mimeType = mimeType.trim();
        voiceVersion = voiceVersion.trim();
        configurationIdentity = Objects.requireNonNull(configurationIdentity, "configurationIdentity");
    }

    @Override
    public byte[] bytes() {
        return Arrays.copyOf(bytes, bytes.length);
    }
}
