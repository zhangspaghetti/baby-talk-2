package com.zhangspaghetti.babytalk.practice.discovery.safety;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.TreeMap;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.Bindable;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.context.properties.bind.ConstructorBinding;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.core.env.StandardEnvironment;
import org.springframework.core.io.ClassPathResource;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "babytalk.practice.health-safety")
public record CustomSceneSafetyProperties(
        String policyVersion,
        Duration classifierTimeout,
        PromptRef classifierPrompt,
        Map<String, Template> templates,
        Map<String, List<String>> emergencySignals
) {

    private static final String DEFAULT_POLICY_VERSION = "health-safety-v1";
    private static final String POLICY_RESOURCE = "config/practice-health-safety-v1.yml";
    private static final String DEFAULT_CLASSIFIER_PROMPT_VERSION = "custom-scene-safety-classifier-v1";
    private static final String DEFAULT_CLASSIFIER_PROMPT_PATH =
            "config/practice-ai/prompts/custom-scene-safety-classifier-v1.txt";
    private static final String DEFAULT_LOCALE = "zh-CN";
    private static final Set<String> APPROVED_TEMPLATE_IDS = Set.of(
            "health-emergency-v1",
            "health-concern-v1",
            "health-prompt-assessment-v1",
            "health-uncertain-v1",
            "health-assessment-unavailable-v1");
    private static final Set<String> APPROVED_SIGNAL_KEYS = Set.of(
            "breathing-difficulty",
            "blue-lips",
            "cannot-wake",
            "seizure",
            "suspected-poisoning",
            "child-green-vomit");
    private static final Set<String> APPROVED_ACTIONS = Set.of("emergency", "seek_medical_help", "uncertain");
    private static final List<String> TREATMENT_FIELDS = List.of("剂量", "服用", "诊断为");

    @ConstructorBinding
    public CustomSceneSafetyProperties {
        policyVersion = requiredText(policyVersion, "policy version");
        if (!DEFAULT_POLICY_VERSION.equals(policyVersion)) {
            throw new IllegalArgumentException("health safety policy version must be health-safety-v1");
        }
        classifierTimeout = requiredPositive(classifierTimeout, "classifier timeout");
        classifierPrompt = Objects.requireNonNull(classifierPrompt, "classifier prompt");
        templates = immutableTemplates(templates);
        emergencySignals = immutableSignals(emergencySignals);
    }

    public CustomSceneSafetyProperties(
            String policyVersion,
            Duration classifierTimeout,
            Map<String, Template> templates,
            Map<String, List<String>> emergencySignals
    ) {
        this(
                policyVersion,
                classifierTimeout,
                new PromptRef(DEFAULT_CLASSIFIER_PROMPT_VERSION, DEFAULT_CLASSIFIER_PROMPT_PATH),
                templates,
                emergencySignals);
    }

    public static CustomSceneSafetyProperties defaults() {
        try {
            var resource = new ClassPathResource(POLICY_RESOURCE);
            if (!resource.exists()) {
                throw new IllegalStateException("missing health safety policy resource");
            }
            var environment = new StandardEnvironment();
            for (var source : new YamlPropertySourceLoader().load("practice-health-safety-v1", resource)) {
                environment.getPropertySources().addFirst(source);
            }
            return Binder.get(environment)
                    .bind("babytalk.practice.health-safety", Bindable.of(CustomSceneSafetyProperties.class))
                    .orElseThrow(() -> new IllegalStateException("health safety policy did not bind"));
        } catch (java.io.IOException exception) {
            throw new IllegalStateException("unable to load health safety policy resource", exception);
        }
    }

    /** Stable policy content hash used as the opaque audit boundary value. */
    public String contentHash() {
        var canonical = new StringBuilder()
                .append(policyVersion).append('\n')
                .append(classifierTimeout).append('\n')
                .append(classifierPrompt.version()).append('|')
                .append(classifierPrompt.resourcePath()).append('\n');
        new TreeMap<>(templates).forEach((id, template) -> canonical
                .append(id).append('|')
                .append(template.action()).append('|')
                .append(template.locale()).append('|')
                .append(template.titleZh()).append('|')
                .append(template.messageZh()).append('\n'));
        new TreeMap<>(emergencySignals).forEach((id, markers) -> canonical
                .append(id).append('|')
                .append(String.join("\u001f", markers)).append('\n'));
        try {
            var digest = MessageDigest.getInstance("SHA-256")
                    .digest(canonical.toString().getBytes(StandardCharsets.UTF_8));
            var hash = new StringBuilder(digest.length * 2);
            for (var value : digest) {
                hash.append(String.format("%02x", value));
            }
            return hash.toString();
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }

    private static String requiredText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("health safety " + field + " must not be blank");
        }
        return value.trim();
    }

    private static Duration requiredPositive(Duration value, String field) {
        if (value == null || value.isZero() || value.isNegative()) {
            throw new IllegalArgumentException("health safety " + field + " must be positive");
        }
        return value;
    }

    private static Map<String, Template> immutableTemplates(
            Map<String, Template> values
    ) {
        if (values == null || values.isEmpty()) {
            throw new IllegalArgumentException("health safety templates must not be empty");
        }
        var copied = new LinkedHashMap<String, Template>();
        values.forEach((key, value) -> {
            var normalizedKey = requiredText(key, "template id");
            if (copied.containsKey(normalizedKey)) {
                throw new IllegalArgumentException("health safety template ids must be unique");
            }
            if (value == null) {
                throw new IllegalArgumentException("health safety template must not be null");
            }
            var expectedAction = switch (normalizedKey) {
                case "health-emergency-v1" -> "emergency";
                case "health-concern-v1", "health-prompt-assessment-v1" -> "seek_medical_help";
                case "health-uncertain-v1", "health-assessment-unavailable-v1" -> "uncertain";
                default -> null;
            };
            if (expectedAction == null || !expectedAction.equals(value.action())) {
                throw new IllegalArgumentException("health safety template action does not match approved template");
            }
            copied.put(normalizedKey, value);
        });
        if (!APPROVED_TEMPLATE_IDS.equals(copied.keySet())) {
            throw new IllegalArgumentException("health safety template ids are incomplete or unknown");
        }
        return Collections.unmodifiableMap(copied);
    }

    private static Map<String, List<String>> immutableSignals(Map<String, List<String>> values) {
        if (values == null || values.isEmpty()) {
            throw new IllegalArgumentException("health safety emergency signals must not be empty");
        }
        var copied = new LinkedHashMap<String, List<String>>();
        values.forEach((key, markers) -> {
            var normalizedKey = requiredText(key, "emergency signal");
            if (copied.containsKey(normalizedKey)) {
                throw new IllegalArgumentException("health safety emergency signal keys must be unique");
            }
            if (markers == null || markers.isEmpty()) {
                throw new IllegalArgumentException("health safety emergency signal markers must not be empty");
            }
            var normalizedMarkers = new ArrayList<String>();
            markers.forEach(marker -> {
                var normalizedMarker = requiredText(marker, "emergency signal marker").toLowerCase(Locale.ROOT);
                if (!normalizedMarkers.contains(normalizedMarker)) {
                    normalizedMarkers.add(normalizedMarker);
                }
            });
            if (normalizedMarkers.isEmpty()) {
                throw new IllegalArgumentException("health safety emergency signal markers must not be empty");
            }
            copied.put(normalizedKey, List.copyOf(normalizedMarkers));
        });
        if (!APPROVED_SIGNAL_KEYS.equals(copied.keySet())) {
            throw new IllegalArgumentException("health safety emergency signal keys are incomplete or unknown");
        }
        return Collections.unmodifiableMap(copied);
    }

    public record Template(
            String action,
            String locale,
            String titleZh,
            String messageZh
    ) {

        public Template {
            action = requiredText(action, "template action");
            if (!APPROVED_ACTIONS.contains(action)) {
                throw new IllegalArgumentException("health safety template action is not approved");
            }
            locale = requiredText(locale, "template locale");
            titleZh = requiredText(titleZh, "template title");
            messageZh = requiredText(messageZh, "template message");
            if (!DEFAULT_LOCALE.equals(locale)) {
                throw new IllegalArgumentException("health safety template locale must be zh-CN");
            }
            if (TREATMENT_FIELDS.stream().anyMatch(messageZh::contains)) {
                throw new IllegalArgumentException("health safety template message must not contain treatment fields");
            }
        }
    }

    public record PromptRef(String version, String resourcePath) {

        public PromptRef {
            version = requiredText(version, "classifier prompt version");
            resourcePath = requiredText(resourcePath, "classifier prompt resource path");
            if (!DEFAULT_CLASSIFIER_PROMPT_VERSION.equals(version)
                    || !DEFAULT_CLASSIFIER_PROMPT_PATH.equals(resourcePath)) {
                throw new IllegalArgumentException("health safety classifier prompt reference is not approved");
            }
        }
    }
}
