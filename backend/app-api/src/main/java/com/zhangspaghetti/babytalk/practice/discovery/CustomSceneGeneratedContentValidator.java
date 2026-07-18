package com.zhangspaghetti.babytalk.practice.discovery;

import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.ContentConstraints;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratedPracticeContentCandidate;
import java.util.Locale;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

@Component
public class CustomSceneGeneratedContentValidator {

    private static final Pattern ENGLISH_WORD_PATTERN = Pattern.compile("[A-Za-z]+(?:'[A-Za-z]+)?");
    private final PracticeDiscoveryPolicyProperties policyProperties;
    private final CustomSceneIntentClassifier intentClassifier;
    private final PolicyTextMatcher policyTextMatcher;
    private final SceneTextCanonicalizer canonicalizer;
    private final GeneratedCoachTipComposer coachTipComposer;

    public CustomSceneGeneratedContentValidator(
            PracticeDiscoveryPolicyProperties policyProperties,
            CustomSceneIntentClassifier intentClassifier
    ) {
        this(policyProperties, intentClassifier, new SceneTextCanonicalizer());
    }

    private CustomSceneGeneratedContentValidator(
            PracticeDiscoveryPolicyProperties policyProperties,
            CustomSceneIntentClassifier intentClassifier,
            SceneTextCanonicalizer canonicalizer
    ) {
        this(policyProperties, intentClassifier, new PolicyTextMatcher(canonicalizer), canonicalizer);
    }

    public CustomSceneGeneratedContentValidator(
            PracticeDiscoveryPolicyProperties policyProperties,
            CustomSceneIntentClassifier intentClassifier,
            PolicyTextMatcher policyTextMatcher
    ) {
        this(policyProperties, intentClassifier, policyTextMatcher, new SceneTextCanonicalizer());
    }

    public CustomSceneGeneratedContentValidator(
            PracticeDiscoveryPolicyProperties policyProperties,
            CustomSceneIntentClassifier intentClassifier,
            PolicyTextMatcher policyTextMatcher,
            SceneTextCanonicalizer canonicalizer
    ) {
        this(
                policyProperties,
                intentClassifier,
                policyTextMatcher,
                canonicalizer,
                new GeneratedCoachTipComposer());
    }

    @org.springframework.beans.factory.annotation.Autowired
    public CustomSceneGeneratedContentValidator(
            PracticeDiscoveryPolicyProperties policyProperties,
            CustomSceneIntentClassifier intentClassifier,
            PolicyTextMatcher policyTextMatcher,
            SceneTextCanonicalizer canonicalizer,
            GeneratedCoachTipComposer coachTipComposer
    ) {
        if (policyProperties == null
                || intentClassifier == null
                || policyTextMatcher == null
                || canonicalizer == null
                || coachTipComposer == null) {
            throw new IllegalArgumentException("practice discovery policy properties are required");
        }
        this.policyProperties = policyProperties;
        this.intentClassifier = intentClassifier;
        this.policyTextMatcher = policyTextMatcher;
        this.canonicalizer = canonicalizer;
        this.coachTipComposer = coachTipComposer;
    }

    public GeneratedPracticeContentCandidate normalizeAndValidate(
            GeneratedPracticeContentCandidate candidate,
            ContentConstraints constraints
    ) {
        return normalizeAndValidate(candidate, constraints, new GeneratedOutputValidationContext(null));
    }

    public GeneratedPracticeContentCandidate normalizeAndValidate(
            GeneratedPracticeContentCandidate candidate,
            ContentConstraints constraints,
            GeneratedOutputValidationContext context
    ) {
        if (candidate == null) {
            throw new InvalidGeneratedContentException("candidate_missing");
        }

        var normalized = new GeneratedPracticeContentCandidate(
                required(candidate.spaceTitleZh(), "spaceTitleZh"),
                required(candidate.activityTitleZh(), "activityTitleZh"),
                required(candidate.sceneTagEn(), "sceneTagEn"),
                required(candidate.tprActionZh(), "tprActionZh"),
                required(candidate.deliveryGuidanceZh(), "deliveryGuidanceZh"),
                required(candidate.englishText(), "englishText"),
                required(candidate.chineseText(), "chineseText"),
                trimToNull(candidate.pronunciationHint()),
                required(candidate.difficulty(), "difficulty"),
                required(candidate.generationSource(), "generationSource")
        );

        validateDatabaseLength(normalized.spaceTitleZh(), 120, "spaceTitleZh");
        validateDatabaseLength(normalized.activityTitleZh(), 120, "activityTitleZh");
        validateDatabaseLength(normalized.sceneTagEn(), 120, "sceneTagEn");
        validateDatabaseLength(normalized.tprActionZh(), 240, "tprActionZh");
        validateDatabaseLength(normalized.deliveryGuidanceZh(), 240, "deliveryGuidanceZh");
        validateDatabaseLength(normalized.englishText(), 120, "englishText");
        validateDatabaseLength(normalized.chineseText(), 120, "chineseText");
        validateDatabaseLength(normalized.pronunciationHint(), 120, "pronunciationHint");
        validateDatabaseLength(normalized.difficulty(), 16, "difficulty");
        validateDatabaseLength(normalized.generationSource(), 32, "generationSource");
        validateEnglishStarter(normalized.englishText(), constraints);
        validateMaxLength(normalized.chineseText(), constraints.maxChineseChars(), "chineseText");
        if (coachTipComposer.graphemeLength(
                normalized.tprActionZh(), normalized.deliveryGuidanceZh()) > constraints.maxCoachTipChars()) {
            throw new InvalidGeneratedContentException("coachTipZh");
        }
        validateMaxLength(normalized.sceneTagEn(), constraints.maxSceneTagChars(), "sceneTagEn");

        if (!constraints.allowedDifficulties().contains(normalized.difficulty())) {
            throw new InvalidGeneratedContentException("difficulty");
        }
        if (!constraints.allowedGenerationSources().contains(normalized.generationSource())) {
            throw new InvalidGeneratedContentException("generationSource");
        }

        var combined = combined(normalized);
        if (policyProperties.compiledPhonePattern().matcher(combined).find()
                || policyProperties.compiledEmailPattern().matcher(combined).find()
                || policyProperties.compiledBabyNamePattern().matcher(combined).find()
                || policyTextMatcher.containsAny(combined, policyProperties.validatorPiiMarkers())) {
            throw new RejectedGeneratedContentException("output_pii_leakage");
        }
        if (containsPromptEcho(context == null ? null : context.normalizedSceneText(), combined)) {
            throw new RejectedGeneratedContentException("custom_scene_prompt_echo");
        }
        rejectIfContains(combined, policyProperties.validatorPromptEcho(), "prompt_injection_echo");
        rejectIfContains(combined, policyProperties.validatorBlockedFraming(), "unsupported_learning_framing");
        rejectIfContains(combined, policyProperties.validatorMedicalLegal(), "unsafe_medical_legal");
        rejectIfContains(combined, policyProperties.validatorAdultViolentSexual(), "unsafe_adult_violent_sexual");
        rejectIfContains(combined, policyProperties.validatorUnsupportedClaims(), "unsupported_claim");
        rejectIfContains(combined, policyProperties.validatorUnsuitable03(), "unsuitable_0_3_content");
        var classifiedIntents = intentClassifier.classifyAll(
                context == null ? null : context.normalizedSceneText());
        if (!classifiedIntents.isEmpty()
                && classifiedIntents.stream().noneMatch(intent -> intentClassifier.matchesOutput(intent, combined))) {
            throw new RejectedGeneratedContentException("scene_intent_mismatch");
        }

        return normalized;
    }

    public record GeneratedOutputValidationContext(String normalizedSceneText) {
    }

    private void validateEnglishStarter(
            String englishText,
            ContentConstraints constraints
    ) {
        if (canonicalizer.graphemeLength(englishText) > constraints.maxEnglishChars()) {
            throw new InvalidGeneratedContentException("englishText");
        }
        var matcher = ENGLISH_WORD_PATTERN.matcher(englishText);
        var words = 0;
        while (matcher.find()) {
            words++;
        }
        if (words < 1 || words > constraints.maxEnglishWords()) {
            throw new InvalidGeneratedContentException("englishText");
        }
    }

    private void validateMaxLength(String value, int maxChars, String fieldName) {
        if (canonicalizer.graphemeLength(value) > maxChars) {
            throw new InvalidGeneratedContentException(fieldName);
        }
    }

    private void validateDatabaseLength(String value, int maxCodePoints, String fieldName) {
        if (value != null && canonicalizer.codePointLength(value) > maxCodePoints) {
            throw new InvalidGeneratedContentException(fieldName);
        }
    }

    private String required(String value, String fieldName) {
        var normalized = canonicalizer.canonicalize(value);
        if (normalized == null) {
            throw new InvalidGeneratedContentException(fieldName);
        }
        return normalized;
    }

    private String trimToNull(String value) {
        return canonicalizer.canonicalize(value);
    }

    private String combined(GeneratedPracticeContentCandidate candidate) {
        return (candidate.spaceTitleZh()
                + " "
                + candidate.activityTitleZh()
                + " "
                + candidate.sceneTagEn()
                + " "
                + candidate.tprActionZh()
                + " "
                + candidate.deliveryGuidanceZh()
                + " "
                + candidate.englishText()
                + " "
                + candidate.chineseText()
                + " "
                + nullToEmpty(candidate.pronunciationHint()))
                .toLowerCase(Locale.ROOT);
    }

    private boolean containsPromptEcho(String sceneText, String outputText) {
        var scene = canonicalizer.canonicalize(sceneText);
        var output = canonicalizer.canonicalize(outputText);
        if (scene == null || output == null) {
            return false;
        }
        var searchableOutput = output.toLowerCase(Locale.ROOT);
        var searchableScene = scene.toLowerCase(Locale.ROOT);
        if (canonicalizer.codePointLength(searchableScene) >= 8
                && searchableOutput.contains(searchableScene)) {
            return true;
        }
        var codePoints = searchableScene.codePoints().toArray();
        var windowSize = 16;
        for (var start = 0; start + windowSize <= codePoints.length; start++) {
            var window = new String(codePoints, start, windowSize);
            if (searchableOutput.contains(window)) {
                return true;
            }
        }
        return false;
    }

    private void rejectIfContains(String text, java.util.Collection<String> needles, String reason) {
        if (policyTextMatcher.containsAny(text, needles)) {
            throw new RejectedGeneratedContentException(reason);
        }
    }

    private String nullToEmpty(String value) {
        return value == null ? "" : value;
    }

    public static class RejectedGeneratedContentException extends RuntimeException {

        private final String reason;

        public RejectedGeneratedContentException(String reason) {
            super(reason);
            this.reason = reason;
        }

        public String reason() {
            return reason;
        }
    }

    public static class InvalidGeneratedContentException extends RuntimeException {

        private final String fieldName;

        public InvalidGeneratedContentException(String fieldName) {
            super(fieldName);
            this.fieldName = fieldName;
        }

        public String fieldName() {
            return fieldName;
        }
    }
}
