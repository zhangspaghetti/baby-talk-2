package com.zhangspaghetti.babytalk.practice.discovery;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.ConstructorBinding;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "babytalk.practice.discovery.policy")
public record PracticeDiscoveryPolicyProperties(
        String policyVersion,
        String babyNamePattern,
        String phonePattern,
        String emailPattern,
        List<String> piiMarkers,
        List<String> validatorPiiMarkers,
        List<String> promptInjectionMarkers,
        List<String> unsupportedIntents,
        List<String> careContextMarkers,
        List<String> generatedCareKeywords,
        List<String> validatorBlockedFraming,
        List<String> validatorMedicalLegal,
        List<String> validatorDangerousMedicalCommands,
        List<String> validatorAdultViolentSexual,
        List<String> validatorUnsupportedClaims,
        List<String> validatorUnsuitable03,
        List<String> validatorPromptEcho,
        List<String> validatorTprActionMarkers,
        List<String> validatorDeliveryGuidanceMarkers,
        Map<String, SceneIntentPolicy> sceneIntents
) {

    @ConstructorBinding
    public PracticeDiscoveryPolicyProperties {
        policyVersion = requiredText(policyVersion, "policyVersion");
        if (policyVersion.codePointCount(0, policyVersion.length()) > 48) {
            throw new IllegalArgumentException("practice discovery policy policyVersion must not exceed 48 characters");
        }
        babyNamePattern = requiredText(babyNamePattern, "babyNamePattern");
        phonePattern = requiredText(phonePattern, "phonePattern");
        emailPattern = requiredText(emailPattern, "emailPattern");
        compilePattern(babyNamePattern, "babyNamePattern");
        compilePattern(phonePattern, "phonePattern");
        compilePattern(emailPattern, "emailPattern");
        piiMarkers = normalizedRequiredList(piiMarkers, "piiMarkers");
        validatorPiiMarkers = normalizedRequiredList(validatorPiiMarkers, "validatorPiiMarkers");
        promptInjectionMarkers = normalizedRequiredList(promptInjectionMarkers, "promptInjectionMarkers");
        unsupportedIntents = normalizedRequiredList(unsupportedIntents, "unsupportedIntents");
        careContextMarkers = normalizedRequiredList(careContextMarkers, "careContextMarkers", true);
        generatedCareKeywords = normalizedRequiredList(generatedCareKeywords, "generatedCareKeywords");
        validatorBlockedFraming = normalizedRequiredList(validatorBlockedFraming, "validatorBlockedFraming");
        validatorMedicalLegal = normalizedRequiredList(validatorMedicalLegal, "validatorMedicalLegal");
        validatorDangerousMedicalCommands = normalizedRequiredList(
                validatorDangerousMedicalCommands, "validatorDangerousMedicalCommands");
        validatorAdultViolentSexual = normalizedRequiredList(validatorAdultViolentSexual, "validatorAdultViolentSexual");
        validatorUnsupportedClaims = normalizedRequiredList(validatorUnsupportedClaims, "validatorUnsupportedClaims");
        validatorUnsuitable03 = normalizedRequiredList(validatorUnsuitable03, "validatorUnsuitable03");
        validatorPromptEcho = normalizedRequiredList(validatorPromptEcho, "validatorPromptEcho");
        validatorTprActionMarkers = normalizedRequiredList(
                validatorTprActionMarkers, "validatorTprActionMarkers");
        validatorDeliveryGuidanceMarkers = normalizedRequiredList(
                validatorDeliveryGuidanceMarkers, "validatorDeliveryGuidanceMarkers");
        sceneIntents = normalizedSceneIntents(sceneIntents);
    }

    public PracticeDiscoveryPolicyProperties(
            String policyVersion,
            String babyNamePattern,
            String phonePattern,
            String emailPattern,
            List<String> piiMarkers,
            List<String> promptInjectionMarkers,
            List<String> unsupportedIntents,
            List<String> careContextMarkers,
            List<String> generatedCareKeywords,
            List<String> validatorBlockedFraming,
            List<String> validatorMedicalLegal,
            List<String> validatorDangerousMedicalCommands,
            List<String> validatorAdultViolentSexual,
            List<String> validatorUnsupportedClaims,
            List<String> validatorUnsuitable03,
            List<String> validatorPromptEcho,
            List<String> validatorTprActionMarkers,
            List<String> validatorDeliveryGuidanceMarkers,
            Map<String, SceneIntentPolicy> sceneIntents
    ) {
        this(policyVersion, babyNamePattern, phonePattern, emailPattern, piiMarkers, piiMarkers,
                promptInjectionMarkers, unsupportedIntents, careContextMarkers, generatedCareKeywords,
                validatorBlockedFraming, validatorMedicalLegal, validatorDangerousMedicalCommands,
                validatorAdultViolentSexual,
                validatorUnsupportedClaims, validatorUnsuitable03, validatorPromptEcho,
                validatorTprActionMarkers, validatorDeliveryGuidanceMarkers, sceneIntents);
    }

    public Pattern compiledBabyNamePattern() {
        return Pattern.compile(babyNamePattern, Pattern.CASE_INSENSITIVE);
    }

    public Pattern compiledPhonePattern() {
        return Pattern.compile(phonePattern, Pattern.CASE_INSENSITIVE);
    }

    public Pattern compiledEmailPattern() {
        return Pattern.compile(emailPattern, Pattern.CASE_INSENSITIVE);
    }

    private static void compilePattern(String value, String field) {
        try {
            Pattern.compile(value, Pattern.CASE_INSENSITIVE);
        } catch (RuntimeException exception) {
            throw new IllegalArgumentException("invalid practice discovery policy " + field, exception);
        }
    }

    private static String requiredText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("practice discovery policy " + field + " must not be blank");
        }
        return value.trim();
    }

    private static List<String> normalizedRequiredList(List<String> values, String field) {
        return normalizedRequiredList(values, field, false);
    }

    private static List<String> normalizedRequiredList(
            List<String> values,
            String field,
            boolean allowsOneCharacterCjkMarkers
    ) {
        if (values == null || values.isEmpty()) {
            throw new IllegalArgumentException("practice discovery policy " + field + " must not be empty");
        }
        var normalized = values.stream()
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .map(value -> value.toLowerCase(Locale.ROOT))
                .distinct()
                .toList();
        if (normalized.isEmpty()) {
            throw new IllegalArgumentException("practice discovery policy " + field + " must not be empty");
        }
        for (var marker : normalized) {
            if (!allowsOneCharacterCjkMarkers
                    && marker.codePointCount(0, marker.length()) == 1
                    && Character.UnicodeScript.of(marker.codePointAt(0))
                    == Character.UnicodeScript.HAN) {
                throw new IllegalArgumentException(
                        "practice discovery policy " + field
                                + " must not contain ambiguous one-character CJK markers: " + marker);
            }
        }
        return normalized;
    }

    private static Map<String, SceneIntentPolicy> normalizedSceneIntents(
            Map<String, SceneIntentPolicy> values
    ) {
        if (values == null || values.isEmpty()) {
            throw new IllegalArgumentException("practice discovery policy sceneIntents must not be empty");
        }
        var normalized = new LinkedHashMap<String, SceneIntentPolicy>();
        values.forEach((key, value) -> {
            var normalizedKey = requiredText(key, "sceneIntents key").toLowerCase(Locale.ROOT);
            if (value == null) {
                throw new IllegalArgumentException("practice discovery policy sceneIntents value must not be null");
            }
            normalized.put(normalizedKey, new SceneIntentPolicy(
                    normalizedRequiredList(value.requestMarkers(), normalizedKey + " requestMarkers"),
                    normalizedRequiredList(value.outputMarkers(), normalizedKey + " outputMarkers")));
        });
        return Collections.unmodifiableMap(normalized);
    }

    public record SceneIntentPolicy(
            List<String> requestMarkers,
            List<String> outputMarkers
    ) {
    }
}
