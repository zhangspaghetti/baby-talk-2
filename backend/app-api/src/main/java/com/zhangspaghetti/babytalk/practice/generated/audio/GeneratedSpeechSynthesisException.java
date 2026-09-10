package com.zhangspaghetti.babytalk.practice.generated.audio;

public final class GeneratedSpeechSynthesisException extends RuntimeException {

    public enum Kind {
        DISABLED,
        TIMEOUT,
        UNAVAILABLE
    }

    private final Kind kind;

    private GeneratedSpeechSynthesisException(Kind kind, Throwable cause) {
        super(kind.name().toLowerCase(), cause);
        this.kind = kind;
    }

    public static GeneratedSpeechSynthesisException disabled() {
        return new GeneratedSpeechSynthesisException(Kind.DISABLED, null);
    }

    public static GeneratedSpeechSynthesisException timeout(Throwable cause) {
        return new GeneratedSpeechSynthesisException(Kind.TIMEOUT, cause);
    }

    public static GeneratedSpeechSynthesisException unavailable(Throwable cause) {
        return new GeneratedSpeechSynthesisException(Kind.UNAVAILABLE, cause);
    }

    public Kind kind() {
        return kind;
    }
}
