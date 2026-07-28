package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.agentic.config.GenerationProfile;
import com.zhangspaghetti.babytalk.practice.generated.evidence.FrozenEvidenceBundle;
import java.time.Duration;
import java.util.Set;

public interface CustomSceneGenerator {

    GeneratedPracticeContentCandidate generate(GeneratorRequest request);

    /**
     * Generates a closed six-utterance moment in one provider request. Existing providers that
     * only return a starter remain compatible while the feature is disabled; their bounded
     * supports are derived before any approval transition.
     */
    default GeneratedCareMomentBundle generateCareMoment(GeneratorRequest request) {
        return GeneratedCareMomentBundle.fromStarter(generate(request));
    }

    record GeneratorRequest(
            String generatedContentId,
            int attemptNumber,
            String displayText,
            String ageRange,
            String parentGoal,
            String locale,
            FrozenEvidenceBundle evidenceBundle,
            GenerationProfile generationProfile,
            ContentConstraints constraints
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
            String tprActionZh,
            String deliveryGuidanceZh,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String difficulty,
            String generationSource
    ) {
    }

    enum GenerationUnavailableReason {
        PROVIDER_DISABLED("provider_disabled", false),
        PROVIDER_UNAVAILABLE("provider_unavailable", true),
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
