package com.zhangspaghetti.babytalk.practice.discovery;

import java.time.Duration;
import java.util.Set;

public interface CustomSceneGenerationService {

    GeneratedPracticeContentCandidate generateCustomSceneStarter(CustomSceneGenerationRequest request);

    record CustomSceneGenerationRequest(
            String generatedContentId,
            String canonicalSceneText,
            PracticeDiscoverySurface surface,
            PracticeDiscoveryMode mode,
            String ageRange,
            String parentGoal,
            String locale,
            String traceId,
            Duration timeout,
            ContentConstraints constraints,
            String promptVersion,
            String strategyVersion
    ) {
    }

    record ContentConstraints(
            int maxEnglishWords,
            int maxEnglishChars,
            int maxChineseChars,
            int maxCoachTipChars,
            int maxSceneTagChars,
            Set<String> allowedDifficulties,
            Set<String> allowedGenerationSources
    ) {

        public static ContentConstraints defaults() {
            return new ContentConstraints(
                    6,
                    40,
                    24,
                    80,
                    60,
                    Set.of("starter", "easy", "medium", "hard"),
                    Set.of("agentic_search", "rag_generation", "manual")
            );
        }

        public static ContentConstraints fakeProviderDefaults() {
            return new ContentConstraints(
                    6,
                    40,
                    24,
                    80,
                    60,
                    Set.of("starter", "easy", "medium", "hard"),
                    Set.of("fake")
            );
        }
    }

    record GeneratedPracticeContentCandidate(
            String spaceTitleZh,
            String activityTitleZh,
            String sceneTagEn,
            String coachTipZh,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String difficulty,
            String generationSource,
            String providerTraceId,
            String retrievalTraceId,
            String modelName
    ) {
    }

    enum GenerationUnavailableReason {
        PROVIDER_DISABLED("provider_disabled", false),
        PROVIDER_UNAVAILABLE("provider_unavailable", true),
        AGENTIC_NOT_IMPLEMENTED("agentic_not_implemented", false),
        FAKE_SCENE_NOT_SUPPORTED("fake_scene_not_supported", false);

        private final String code;
        private final boolean retryable;

        GenerationUnavailableReason(String code, boolean retryable) {
            this.code = code;
            this.retryable = retryable;
        }

        public String code() {
            return code;
        }

        public boolean retryable() {
            return retryable;
        }
    }

    class GenerationUnavailableException extends RuntimeException {

        private final GenerationUnavailableReason reason;

        public GenerationUnavailableException(GenerationUnavailableReason reason) {
            super(reason.code());
            this.reason = reason;
        }

        public String reason() {
            return reason.code();
        }

        public boolean retryable() {
            return reason.retryable();
        }
    }

    class GenerationTimeoutException extends RuntimeException {

        private final Duration timeout;

        public GenerationTimeoutException() {
            this(null);
        }

        public GenerationTimeoutException(Duration timeout) {
            super("custom scene generation timed out");
            this.timeout = timeout;
        }

        public Duration timeout() {
            return timeout;
        }
    }
}
