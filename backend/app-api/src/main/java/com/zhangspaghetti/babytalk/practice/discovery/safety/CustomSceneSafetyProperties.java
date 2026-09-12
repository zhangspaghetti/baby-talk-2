package com.zhangspaghetti.babytalk.practice.discovery.safety;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
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
        Map<String, Template> templates,
        Map<String, List<String>> emergencySignals
) {

    private static final String DEFAULT_POLICY_VERSION = "health-safety-v1";
    private static final String POLICY_RESOURCE = "config/practice-health-safety-v1.yml";
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
        templates = immutableTemplates(templates);
        emergencySignals = immutableSignals(emergencySignals);
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
}
