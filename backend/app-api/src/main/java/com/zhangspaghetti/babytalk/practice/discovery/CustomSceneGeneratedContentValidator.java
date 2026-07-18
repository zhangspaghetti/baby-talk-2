package com.zhangspaghetti.babytalk.practice.discovery;

import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.ContentConstraints;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratedPracticeContentCandidate;
import com.zhangspaghetti.babytalk.practice.generated.quality.GeneratedOutputGateResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.GeneratedOutputViolationCode;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.springframework.stereotype.Component;

@Component
public class CustomSceneGeneratedContentValidator {

    private static final Pattern ENGLISH_WORD_PATTERN = Pattern.compile("[A-Za-z]+(?:'[A-Za-z]+)?");
    private static final Pattern TRUSTED_SCENE_TAG_PATTERN = Pattern.compile("[A-Za-z0-9][A-Za-z0-9 _-]*");
    private static final Pattern MARKDOWN_OR_TEMPLATE_PATTERN = Pattern.compile(
            "(?m)(?:```|~~~|\\{\\{|\\}\\}|\\$\\{|</?[A-Za-z][^>]*>|"
                    + "(?:^|\\R)\\s{0,3}(?:#{1,6}\\s|[-*+]\\s|\\d+[.)]\\s)|"
                    + "\\*\\*|__|`[^`]+`|\\[[^]]+]\\([^)]+\\)|"
                    + "\"[A-Za-z][A-Za-z0-9_]*\"\\s*:)");

    private final PracticeDiscoveryPolicyProperties policyProperties;
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
        this.policyTextMatcher = policyTextMatcher;
        this.canonicalizer = canonicalizer;
        this.coachTipComposer = coachTipComposer;
    }

    public GeneratedOutputGateResult evaluate(
            GeneratedPracticeContentCandidate candidate,
            GeneratedOutputValidationContext context
    ) {
        return evaluate(candidate, ContentConstraints.defaults(), context);
    }

    public GeneratedOutputGateResult evaluate(
            GeneratedPracticeContentCandidate candidate,
            ContentConstraints constraints,
            GeneratedOutputValidationContext context
    ) {
        if (candidate == null) {
            return new GeneratedOutputGateResult(
                    null,
                    List.of(GeneratedOutputViolationCode.UNTRUSTED_METADATA),
                    List.of());
        }
        if (constraints == null) {
            throw new IllegalArgumentException("content constraints are required");
        }

        var normalized = normalize(candidate);
        var terminal = new ArrayList<GeneratedOutputViolationCode>();
        var repairable = new ArrayList<GeneratedOutputViolationCode>();

        if (containsBidiControl(candidate)) {
            terminal.add(GeneratedOutputViolationCode.OUTPUT_BIDI_CONTROL);
        }
        if (hasMissingCoreContent(normalized)
                || !isTrustedSceneTag(normalized.sceneTagEn())) {
            terminal.add(GeneratedOutputViolationCode.UNTRUSTED_METADATA);
        }
        if (exceedsStorageOrSchemaLimits(normalized, constraints)) {
            terminal.add(GeneratedOutputViolationCode.DATABASE_OVERFLOW);
        }
        if ((normalized.difficulty() != null
                && !constraints.allowedDifficulties().contains(normalized.difficulty()))
                || (normalized.generationSource() != null
                && !constraints.allowedGenerationSources().contains(normalized.generationSource()))) {
            terminal.add(GeneratedOutputViolationCode.INVALID_ENUM);
        }

        var combined = combined(normalized);
        if (containsPii(combined)) {
            terminal.add(GeneratedOutputViolationCode.OUTPUT_PII);
        }
        if (policyTextMatcher.containsAny(
                combined, policyProperties.validatorAdultViolentSexual())) {
            terminal.add(GeneratedOutputViolationCode.OUTPUT_ADULT_VIOLENT);
        }
        if (policyTextMatcher.containsAny(
                combined, policyProperties.validatorDangerousMedicalCommands())) {
            terminal.add(GeneratedOutputViolationCode.OUTPUT_DANGEROUS_MEDICAL);
        }

        if (terminal.isEmpty()) {
            var hasActionSignal = policyTextMatcher.containsAny(
                    normalized.tprActionZh(), policyProperties.validatorTprActionMarkers());
            var hasDeliverySignal = policyTextMatcher.containsAny(
                    normalized.deliveryGuidanceZh(), policyProperties.validatorDeliveryGuidanceMarkers());
            if (!hasActionSignal) {
                repairable.add(GeneratedOutputViolationCode.MISSING_TPR_ACTION);
            }
            if (!hasDeliverySignal) {
                repairable.add(GeneratedOutputViolationCode.MISSING_DELIVERY_GUIDANCE);
            }
            if (!hasActionSignal
                    && !hasDeliverySignal
                    && policyTextMatcher.containsAny(
                            normalized.tprActionZh(), policyProperties.validatorDeliveryGuidanceMarkers())
                    && policyTextMatcher.containsAny(
                            normalized.deliveryGuidanceZh(), policyProperties.validatorTprActionMarkers())) {
                repairable.add(GeneratedOutputViolationCode.FIELD_ROLE_MISMATCH);
            }
            if (policyTextMatcher.containsAny(combined, policyProperties.validatorPromptEcho())) {
                repairable.add(GeneratedOutputViolationCode.META_INSTRUCTION);
            }
            if (policyTextMatcher.containsAny(combined, policyProperties.validatorBlockedFraming())) {
                repairable.add(GeneratedOutputViolationCode.COURSE_OR_SCORING_FRAMING);
            }
            if (containsMarkdownOrTemplate(normalized)) {
                repairable.add(GeneratedOutputViolationCode.MARKDOWN_OR_TEMPLATE);
            }
        }

        return new GeneratedOutputGateResult(normalized, terminal, repairable);
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
        var result = evaluate(candidate, constraints, context);
        validateLegacyStructure(candidate, result.normalizedCandidate(), constraints);
        if (!result.terminalViolations().isEmpty()) {
            throw legacyException(result.terminalViolations().get(0));
        }
        if (!result.repairableViolations().isEmpty()) {
            throw legacyException(result.repairableViolations().get(0));
        }
        return result.normalizedCandidate();
    }

    public record GeneratedOutputValidationContext(String normalizedSceneText) {
    }

    private GeneratedPracticeContentCandidate normalize(GeneratedPracticeContentCandidate candidate) {
        return new GeneratedPracticeContentCandidate(
                canonicalizer.canonicalize(candidate.spaceTitleZh()),
                canonicalizer.canonicalize(candidate.activityTitleZh()),
                canonicalizer.canonicalize(candidate.sceneTagEn()),
                canonicalizer.canonicalize(candidate.tprActionZh()),
                canonicalizer.canonicalize(candidate.deliveryGuidanceZh()),
                canonicalizer.canonicalize(candidate.englishText()),
                canonicalizer.canonicalize(candidate.chineseText()),
                canonicalizer.canonicalize(candidate.pronunciationHint()),
                canonicalizer.canonicalize(candidate.difficulty()),
                canonicalizer.canonicalize(candidate.generationSource()));
    }

    private boolean containsBidiControl(GeneratedPracticeContentCandidate candidate) {
        return candidateFields(candidate)
                .filter(value -> value != null)
                .map(canonicalizer::derive)
                .anyMatch(forms -> forms.riskSignals().bidiControlPresent());
    }

    private boolean hasMissingCoreContent(GeneratedPracticeContentCandidate candidate) {
        return candidate.spaceTitleZh() == null
                || candidate.activityTitleZh() == null
                || candidate.sceneTagEn() == null
                || candidate.englishText() == null
                || candidate.chineseText() == null
                || candidate.difficulty() == null
                || candidate.generationSource() == null;
    }

    private boolean isTrustedSceneTag(String sceneTagEn) {
        return sceneTagEn == null || TRUSTED_SCENE_TAG_PATTERN.matcher(sceneTagEn).matches();
    }

    private boolean exceedsStorageOrSchemaLimits(
            GeneratedPracticeContentCandidate candidate,
            ContentConstraints constraints
    ) {
        return exceedsCodePoints(candidate.spaceTitleZh(), 120)
                || exceedsCodePoints(candidate.activityTitleZh(), 120)
                || exceedsCodePoints(candidate.sceneTagEn(), 120)
                || exceedsCodePoints(candidate.tprActionZh(), 240)
                || exceedsCodePoints(candidate.deliveryGuidanceZh(), 240)
                || exceedsCodePoints(candidate.englishText(), 120)
                || exceedsCodePoints(candidate.chineseText(), 120)
                || exceedsCodePoints(candidate.pronunciationHint(), 120)
                || exceedsCodePoints(candidate.difficulty(), 16)
                || exceedsCodePoints(candidate.generationSource(), 32)
                || canonicalizer.graphemeLength(candidate.englishText()) > constraints.maxEnglishChars()
                || (candidate.englishText() != null
                && (englishWordCount(candidate.englishText()) < 1
                || englishWordCount(candidate.englishText()) > constraints.maxEnglishWords()))
                || canonicalizer.graphemeLength(candidate.chineseText()) > constraints.maxChineseChars()
                || coachTipComposer.graphemeLength(
                        candidate.tprActionZh(), candidate.deliveryGuidanceZh()) > constraints.maxCoachTipChars()
                || canonicalizer.graphemeLength(candidate.sceneTagEn()) > constraints.maxSceneTagChars();
    }

    private boolean exceedsCodePoints(String value, int maxCodePoints) {
        return value != null && canonicalizer.codePointLength(value) > maxCodePoints;
    }

    private int englishWordCount(String englishText) {
        if (englishText == null) {
            return 0;
        }
        var matcher = ENGLISH_WORD_PATTERN.matcher(englishText);
        var words = 0;
        while (matcher.find()) {
            words++;
        }
        return words;
    }

    private boolean containsPii(String combined) {
        return policyProperties.compiledPhonePattern().matcher(combined).find()
                || policyProperties.compiledEmailPattern().matcher(combined).find()
                || policyProperties.compiledBabyNamePattern().matcher(combined).find()
                || policyTextMatcher.containsAny(combined, policyProperties.validatorPiiMarkers());
    }

    private boolean containsMarkdownOrTemplate(GeneratedPracticeContentCandidate candidate) {
        return candidateFields(candidate)
                .filter(value -> value != null)
                .anyMatch(value -> MARKDOWN_OR_TEMPLATE_PATTERN.matcher(value).find());
    }

    private Stream<String> candidateFields(GeneratedPracticeContentCandidate candidate) {
        return Stream.of(
                candidate.spaceTitleZh(),
                candidate.activityTitleZh(),
                candidate.sceneTagEn(),
                candidate.tprActionZh(),
                candidate.deliveryGuidanceZh(),
                candidate.englishText(),
                candidate.chineseText(),
                candidate.pronunciationHint(),
                candidate.difficulty(),
                candidate.generationSource());
    }

    private String combined(GeneratedPracticeContentCandidate candidate) {
        return String.join(" ", candidateFields(candidate)
                .map(this::nullToEmpty)
                .toList());
    }

    private void validateLegacyStructure(
            GeneratedPracticeContentCandidate original,
            GeneratedPracticeContentCandidate normalized,
            ContentConstraints constraints
    ) {
        if (original == null) {
            throw new InvalidGeneratedContentException("candidate_missing");
        }
        require(normalized.spaceTitleZh(), "spaceTitleZh");
        require(normalized.activityTitleZh(), "activityTitleZh");
        require(normalized.sceneTagEn(), "sceneTagEn");
        require(normalized.tprActionZh(), "tprActionZh");
        require(normalized.deliveryGuidanceZh(), "deliveryGuidanceZh");
        require(normalized.englishText(), "englishText");
        require(normalized.chineseText(), "chineseText");
        require(normalized.difficulty(), "difficulty");
        require(normalized.generationSource(), "generationSource");

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
    }

    private void validateEnglishStarter(String englishText, ContentConstraints constraints) {
        if (canonicalizer.graphemeLength(englishText) > constraints.maxEnglishChars()
                || englishWordCount(englishText) < 1
                || englishWordCount(englishText) > constraints.maxEnglishWords()) {
            throw new InvalidGeneratedContentException("englishText");
        }
    }

    private void validateMaxLength(String value, int maxChars, String fieldName) {
        if (canonicalizer.graphemeLength(value) > maxChars) {
            throw new InvalidGeneratedContentException(fieldName);
        }
    }

    private void validateDatabaseLength(String value, int maxCodePoints, String fieldName) {
        if (exceedsCodePoints(value, maxCodePoints)) {
            throw new InvalidGeneratedContentException(fieldName);
        }
    }

    private void require(String value, String fieldName) {
        if (value == null) {
            throw new InvalidGeneratedContentException(fieldName);
        }
    }

    private RuntimeException legacyException(GeneratedOutputViolationCode violation) {
        return switch (violation) {
            case OUTPUT_PII -> new RejectedGeneratedContentException("output_pii_leakage");
            case OUTPUT_BIDI_CONTROL -> new RejectedGeneratedContentException("output_bidi_control");
            case OUTPUT_ADULT_VIOLENT ->
                    new RejectedGeneratedContentException("unsafe_adult_violent_sexual");
            case OUTPUT_DANGEROUS_MEDICAL ->
                    new RejectedGeneratedContentException("unsafe_medical_legal");
            case UNTRUSTED_METADATA -> new RejectedGeneratedContentException("untrusted_metadata");
            case DATABASE_OVERFLOW -> new InvalidGeneratedContentException("database_overflow");
            case INVALID_ENUM -> new InvalidGeneratedContentException("invalid_enum");
            case MISSING_TPR_ACTION -> new RejectedGeneratedContentException("missing_tpr_action");
            case MISSING_DELIVERY_GUIDANCE ->
                    new RejectedGeneratedContentException("missing_delivery_guidance");
            case FIELD_ROLE_MISMATCH -> new RejectedGeneratedContentException("field_role_mismatch");
            case META_INSTRUCTION -> new RejectedGeneratedContentException("prompt_injection_echo");
            case COURSE_OR_SCORING_FRAMING ->
                    new RejectedGeneratedContentException("unsupported_learning_framing");
            case MARKDOWN_OR_TEMPLATE -> new RejectedGeneratedContentException("markdown_or_template");
        };
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
