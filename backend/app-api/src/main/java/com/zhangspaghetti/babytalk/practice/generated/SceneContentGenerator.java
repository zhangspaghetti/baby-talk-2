package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.agentic.config.GenerationProfile;
import com.zhangspaghetti.babytalk.practice.generated.evidence.FrozenEvidenceBundle;
import java.time.Duration;
import java.util.Set;
import java.util.regex.Pattern;

public interface SceneContentGenerator {

    /** Generates one closed six-utterance moment in one provider request. */
    GeneratedCareMomentBundle generateCareMoment(GeneratorRequest request);

    record GeneratorRequest(
            String generatedContentId,
            int attemptNumber,
            String displayText,
            String stableActivityId,
            String ageRange,
            String parentGoal,
            String locale,
            FrozenEvidenceBundle evidenceBundle,
            GenerationProfile generationProfile,
            ContentConstraints constraints,
            GenerationRequestContext context
    ) {
        private static final Pattern SAFE_STABLE_ACTIVITY_ID = Pattern.compile("[a-z0-9][a-z0-9_-]{0,95}");

        public GeneratorRequest(
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
            this(generatedContentId, attemptNumber, displayText, null, ageRange, parentGoal, locale,
                    evidenceBundle, generationProfile, constraints,
                    legacyContext(ageRange, parentGoal, locale));
        }

        public GeneratorRequest(
                String generatedContentId,
                int attemptNumber,
                String displayText,
                String ageRange,
                String parentGoal,
                String locale,
                FrozenEvidenceBundle evidenceBundle,
                GenerationProfile generationProfile,
                ContentConstraints constraints,
                GenerationRequestContext context
        ) {
            this(generatedContentId, attemptNumber, displayText, null, ageRange, parentGoal, locale,
                    evidenceBundle, generationProfile, constraints, context);
        }

        public GeneratorRequest(
                String generatedContentId,
                int attemptNumber,
                String displayText,
                String stableActivityId,
                String ageRange,
                String parentGoal,
                String locale,
                FrozenEvidenceBundle evidenceBundle,
                GenerationProfile generationProfile,
                ContentConstraints constraints
        ) {
            this(generatedContentId, attemptNumber, displayText, stableActivityId, ageRange, parentGoal, locale,
                    evidenceBundle, generationProfile, constraints,
                    legacyContext(ageRange, parentGoal, locale));
        }

        public GeneratorRequest {
            java.util.Objects.requireNonNull(context, "context");
            if (stableActivityId != null
                    && !SAFE_STABLE_ACTIVITY_ID.matcher(stableActivityId).matches()) {
                throw new IllegalArgumentException("stableActivityId must be a safe stable identifier");
            }
            if (!java.util.Objects.equals(ageRange, context.ageRange())
                    || !java.util.Objects.equals(parentGoal, context.parentGoal())
                    || !java.util.Objects.equals(locale, context.locale())) {
                throw new IllegalArgumentException("generator request context must match request profile");
            }
        }

        @Override
        public String toString() {
            return "GeneratorRequest{"
                    + "generatedContentId='" + generatedContentId + '\''
                    + ", attemptNumber=" + attemptNumber
                    + ", locale='" + locale + '\''
                    + '}';
        }

        private static GenerationRequestContext legacyContext(
                String ageRange,
                String parentGoal,
                String locale
        ) {
            return new GenerationRequestContext(
                    "legacy",
                    ageRange == null ? "unknown" : ageRange,
                    parentGoal == null ? "unknown" : parentGoal,
                    locale == null ? "unknown" : locale,
                    "legacy",
                    0,
                    null,
                    "");
        }
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
