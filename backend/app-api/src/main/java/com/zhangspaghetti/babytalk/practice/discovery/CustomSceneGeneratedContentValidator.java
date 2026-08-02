package com.zhangspaghetti.babytalk.practice.discovery;

import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.ContentConstraints;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratedPracticeContentCandidate;
import com.zhangspaghetti.babytalk.practice.generated.quality.GeneratedOutputGateResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.GeneratedOutputViolationDiagnostic;
import com.zhangspaghetti.babytalk.practice.generated.quality.GeneratedOutputViolationDiagnostic.FieldPath;
import com.zhangspaghetti.babytalk.practice.generated.quality.GeneratedOutputViolationDiagnostic.LengthUnit;
import com.zhangspaghetti.babytalk.practice.generated.quality.GeneratedOutputViolationCode;
import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.springframework.stereotype.Component;

@Component
public class CustomSceneGeneratedContentValidator {

    private static final int MAX_NEGATION_PREFIX_CODE_POINTS = 32;
    private static final int GENERATION_SOURCE_MAX_CODE_POINTS = 32;
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
    private final List<Pattern> dangerousMedicalCommandPatterns;
    private final List<Pattern> dangerousMedicalNegationPatterns;

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
        this.dangerousMedicalCommandPatterns = compilePolicyPatterns(
                policyProperties.validatorDangerousMedicalCommandPatterns());
        this.dangerousMedicalNegationPatterns = compilePolicyPatterns(
                policyProperties.validatorDangerousMedicalNegationPatterns());
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
                    List.of(),
                    List.of(),
                    List.of());
        }
        if (constraints == null) {
            throw new IllegalArgumentException("content constraints are required");
        }

        var normalized = normalize(candidate);
        var terminal = new ArrayList<GeneratedOutputViolationCode>();
        var repairable = new ArrayList<GeneratedOutputViolationCode>();
        var terminalDiagnostics = new ArrayList<GeneratedOutputViolationDiagnostic>();
        var repairableDiagnostics = new ArrayList<GeneratedOutputViolationDiagnostic>();

        if (containsBidiControl(candidate)) {
            terminal.add(GeneratedOutputViolationCode.OUTPUT_BIDI_CONTROL);
        }
        if (hasMissingCoreContent(normalized)
                || !isTrustedSceneTag(normalized.sceneTagEn())) {
            terminal.add(GeneratedOutputViolationCode.UNTRUSTED_METADATA);
        }
        var applicationOverflow = lengthOverflow(
                GeneratedOutputViolationCode.DATABASE_OVERFLOW,
                FieldPath.GENERATION_SOURCE,
                normalized.generationSource(),
                GENERATION_SOURCE_MAX_CODE_POINTS);
        if (applicationOverflow != null) {
            terminal.add(GeneratedOutputViolationCode.DATABASE_OVERFLOW);
            terminalDiagnostics.add(applicationOverflow);
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
        if (containsDangerousMedicalCommand(normalized)) {
            terminal.add(GeneratedOutputViolationCode.OUTPUT_DANGEROUS_MEDICAL);
        }

        if (terminal.isEmpty()) {
            var providerOverflows = providerContentOverflows(normalized, constraints);
            if (providerOverflows.overflow()) {
                repairable.add(GeneratedOutputViolationCode.PROVIDER_CONTENT_OVERFLOW);
                repairableDiagnostics.addAll(providerOverflows.lengthDiagnostics());
            }
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

        return new GeneratedOutputGateResult(
                normalized,
                terminal,
                repairable,
                terminalDiagnostics,
                repairableDiagnostics);
    }

    public ProvenanceValidationResult evaluateProvenance(
            CompleteGeneratedBundle.ProviderProvenance provenance
    ) {
        if (provenance == null) {
            throw new IllegalArgumentException("provider provenance is required");
        }
        var diagnostics = new ArrayList<GeneratedOutputViolationDiagnostic>();
        addProvenanceOverflow(
                diagnostics,
                FieldPath.PROVIDER_NAME,
                provenance.providerName(),
                CompleteGeneratedBundle.PROVIDER_NAME_MAX_CODE_POINTS);
        addProvenanceOverflow(
                diagnostics,
                FieldPath.MODEL_NAME,
                provenance.modelName(),
                CompleteGeneratedBundle.MODEL_NAME_MAX_CODE_POINTS);
        return new ProvenanceValidationResult(
                diagnostics.isEmpty()
                        ? List.of()
                        : List.of(GeneratedOutputViolationCode.DATABASE_OVERFLOW),
                List.copyOf(diagnostics));
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

    private ProviderContentOverflowResult providerContentOverflows(
            GeneratedPracticeContentCandidate candidate,
            ContentConstraints constraints
    ) {
        var diagnostics = new ArrayList<GeneratedOutputViolationDiagnostic>();
        addLengthOverflow(diagnostics, FieldPath.SPACE_TITLE_ZH, candidate.spaceTitleZh(),
                CompleteGeneratedBundle.SPACE_TITLE_ZH_MAX_CODE_POINTS);
        addLengthOverflow(diagnostics, FieldPath.ACTIVITY_TITLE_ZH, candidate.activityTitleZh(),
                CompleteGeneratedBundle.ACTIVITY_TITLE_ZH_MAX_CODE_POINTS);
        addLengthOverflow(diagnostics, FieldPath.SCENE_TAG_EN, candidate.sceneTagEn(),
                CompleteGeneratedBundle.SCENE_TAG_EN_MAX_CODE_POINTS);
        addLengthOverflow(diagnostics, FieldPath.TPR_ACTION_ZH, candidate.tprActionZh(),
                CompleteGeneratedBundle.TPR_ACTION_ZH_MAX_CODE_POINTS);
        addLengthOverflow(diagnostics, FieldPath.DELIVERY_GUIDANCE_ZH, candidate.deliveryGuidanceZh(),
                CompleteGeneratedBundle.DELIVERY_GUIDANCE_ZH_MAX_CODE_POINTS);
        addLengthOverflow(diagnostics, FieldPath.ENGLISH_TEXT, candidate.englishText(),
                CompleteGeneratedBundle.ENGLISH_TEXT_MAX_CODE_POINTS);
        addLengthOverflow(diagnostics, FieldPath.CHINESE_TEXT, candidate.chineseText(),
                CompleteGeneratedBundle.CHINESE_TEXT_MAX_CODE_POINTS);
        addLengthOverflow(diagnostics, FieldPath.PRONUNCIATION_HINT, candidate.pronunciationHint(),
                CompleteGeneratedBundle.PRONUNCIATION_HINT_MAX_CODE_POINTS);
        addLengthOverflow(diagnostics, FieldPath.DIFFICULTY, candidate.difficulty(),
                CompleteGeneratedBundle.DIFFICULTY_MAX_CODE_POINTS);

        addConstraintOverflow(diagnostics, FieldPath.ENGLISH_TEXT, candidate.englishText(),
                canonicalizer.graphemeLength(candidate.englishText()), constraints.maxEnglishChars());
        addConstraintOverflow(diagnostics, FieldPath.CHINESE_TEXT, candidate.chineseText(),
                canonicalizer.graphemeLength(candidate.chineseText()), constraints.maxChineseChars());
        addConstraintOverflow(diagnostics, FieldPath.SCENE_TAG_EN, candidate.sceneTagEn(),
                canonicalizer.graphemeLength(candidate.sceneTagEn()), constraints.maxSceneTagChars());
        var coachTipGraphemes = coachTipComposer.graphemeLength(
                candidate.tprActionZh(), candidate.deliveryGuidanceZh());
        var coachTip = coachTipComposer.compose(candidate.tprActionZh(), candidate.deliveryGuidanceZh());
        addConstraintOverflow(
                diagnostics, FieldPath.COACH_TIP_ZH, coachTip, coachTipGraphemes, constraints.maxCoachTipChars());
        var englishWords = englishWordCount(candidate.englishText());
        var wordConstraintOverflow = candidate.englishText() != null
                && (englishWords < 1 || englishWords > constraints.maxEnglishWords());
        return new ProviderContentOverflowResult(
                wordConstraintOverflow || !diagnostics.isEmpty(),
                List.copyOf(diagnostics));
    }

    private void addLengthOverflow(
            List<GeneratedOutputViolationDiagnostic> diagnostics,
            FieldPath field,
            String value,
            int limit
    ) {
        var diagnostic = lengthOverflow(
                GeneratedOutputViolationCode.PROVIDER_CONTENT_OVERFLOW,
                field,
                value,
                limit);
        if (diagnostic != null) {
            diagnostics.add(diagnostic);
        }
    }

    private void addProvenanceOverflow(
            List<GeneratedOutputViolationDiagnostic> diagnostics,
            FieldPath field,
            String value,
            int limit
    ) {
        var diagnostic = lengthOverflow(
                GeneratedOutputViolationCode.DATABASE_OVERFLOW,
                field,
                value,
                limit);
        if (diagnostic != null) {
            diagnostics.add(diagnostic);
        }
    }

    private void addConstraintOverflow(
            List<GeneratedOutputViolationDiagnostic> diagnostics,
            FieldPath field,
            String value,
            int measuredLength,
            int limit
    ) {
        if (value != null && measuredLength > limit) {
            diagnostics.add(new GeneratedOutputViolationDiagnostic(
                    GeneratedOutputViolationCode.PROVIDER_CONTENT_OVERFLOW,
                    field,
                    LengthUnit.GRAPHEME,
                    measuredLength,
                    limit));
        }
    }

    private GeneratedOutputViolationDiagnostic lengthOverflow(
            GeneratedOutputViolationCode code,
            FieldPath field,
            String value,
            int limit
    ) {
        if (!exceedsCodePoints(value, limit)) {
            return null;
        }
        return new GeneratedOutputViolationDiagnostic(
                code,
                field,
                LengthUnit.CODE_POINT,
                canonicalizer.codePointLength(value),
                limit);
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

    private boolean containsDangerousMedicalCommand(GeneratedPracticeContentCandidate candidate) {
        return candidateFields(candidate)
                .filter(value -> value != null)
                .anyMatch(this::containsUnnegatedDangerousMedicalCommand);
    }

    private boolean containsUnnegatedDangerousMedicalCommand(String text) {
        var securityText = canonicalizer.derive(text).securityText();
        if (securityText == null) {
            return false;
        }
        for (var commandPattern : dangerousMedicalCommandPatterns) {
            var matcher = commandPattern.matcher(securityText);
            while (matcher.find()) {
                if (!isLocallyNegated(securityText, matcher.start())) {
                    return true;
                }
            }
        }
        return false;
    }

    private boolean isLocallyNegated(String text, int commandStart) {
        var prefixCodePoints = text.codePointCount(0, commandStart);
        var prefixStart = text.offsetByCodePoints(
                0, Math.max(0, prefixCodePoints - MAX_NEGATION_PREFIX_CODE_POINTS));
        var localPrefix = text.substring(prefixStart, commandStart);
        return dangerousMedicalNegationPatterns.stream()
                .anyMatch(pattern -> pattern.matcher(localPrefix).find());
    }

    private static List<Pattern> compilePolicyPatterns(List<String> patterns) {
        var flags = Pattern.CASE_INSENSITIVE
                | Pattern.UNICODE_CASE
                | Pattern.UNICODE_CHARACTER_CLASS;
        return patterns.stream()
                .map(pattern -> Pattern.compile(pattern, flags))
                .toList();
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

        validateDatabaseLength(normalized.spaceTitleZh(),
                CompleteGeneratedBundle.SPACE_TITLE_ZH_MAX_CODE_POINTS, "spaceTitleZh");
        validateDatabaseLength(normalized.activityTitleZh(),
                CompleteGeneratedBundle.ACTIVITY_TITLE_ZH_MAX_CODE_POINTS, "activityTitleZh");
        validateDatabaseLength(normalized.sceneTagEn(),
                CompleteGeneratedBundle.SCENE_TAG_EN_MAX_CODE_POINTS, "sceneTagEn");
        validateDatabaseLength(normalized.tprActionZh(),
                CompleteGeneratedBundle.TPR_ACTION_ZH_MAX_CODE_POINTS, "tprActionZh");
        validateDatabaseLength(normalized.deliveryGuidanceZh(),
                CompleteGeneratedBundle.DELIVERY_GUIDANCE_ZH_MAX_CODE_POINTS, "deliveryGuidanceZh");
        validateDatabaseLength(normalized.englishText(),
                CompleteGeneratedBundle.ENGLISH_TEXT_MAX_CODE_POINTS, "englishText");
        validateDatabaseLength(normalized.chineseText(),
                CompleteGeneratedBundle.CHINESE_TEXT_MAX_CODE_POINTS, "chineseText");
        validateDatabaseLength(normalized.pronunciationHint(),
                CompleteGeneratedBundle.PRONUNCIATION_HINT_MAX_CODE_POINTS, "pronunciationHint");
        validateDatabaseLength(normalized.difficulty(),
                CompleteGeneratedBundle.DIFFICULTY_MAX_CODE_POINTS, "difficulty");
        validateDatabaseLength(normalized.generationSource(),
                GENERATION_SOURCE_MAX_CODE_POINTS, "generationSource");

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
            case PROVIDER_CONTENT_OVERFLOW -> new InvalidGeneratedContentException("provider_content_overflow");
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

    private record ProviderContentOverflowResult(
            boolean overflow,
            List<GeneratedOutputViolationDiagnostic> lengthDiagnostics
    ) {
    }

    public record ProvenanceValidationResult(
            List<GeneratedOutputViolationCode> terminalViolations,
            List<GeneratedOutputViolationDiagnostic> terminalViolationDiagnostics
    ) {
        public ProvenanceValidationResult {
            terminalViolations = List.copyOf(terminalViolations);
            terminalViolationDiagnostics = List.copyOf(terminalViolationDiagnostics);
        }
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
