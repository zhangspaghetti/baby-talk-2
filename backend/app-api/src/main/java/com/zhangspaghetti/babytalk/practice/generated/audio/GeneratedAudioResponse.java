package com.zhangspaghetti.babytalk.practice.generated.audio;

import java.util.Arrays;

public record GeneratedAudioResponse(byte[] bytes, String mimeType, String voiceVersion) {

    public GeneratedAudioResponse {
        if (bytes == null) {
            throw new IllegalArgumentException("generated audio bytes are required");
        }
        if (mimeType == null || mimeType.isBlank()) {
            throw new IllegalArgumentException("generated audio MIME type is required");
        }
        if (voiceVersion == null || voiceVersion.isBlank()) {
            throw new IllegalArgumentException("generated audio voice version is required");
        }
        bytes = Arrays.copyOf(bytes, bytes.length);
        mimeType = mimeType.trim();
        voiceVersion = voiceVersion.trim();
    }

    @Override
    public byte[] bytes() {
        return Arrays.copyOf(bytes, bytes.length);
    }
}
