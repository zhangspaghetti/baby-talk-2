package com.zhangspaghetti.babytalk.practice.discovery.safety;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import java.util.Objects;
import org.springframework.stereotype.Component;

/** Aggregate safety metrics with a deliberately closed tag vocabulary. */
@Component
public final class CustomSceneSafetyMetrics {

    public static final String RESULT_COUNTER = "babytalk.custom.scene.safety.results";
    public static final String FAILURE_COUNTER = "babytalk.custom.scene.safety.failures";
    public static final String CLASSIFIER_TIMER = "babytalk.custom.scene.safety.classifier.duration";
    public static final String RESULT_TYPE_TAG = "result_type";
    public static final String TEMPLATE_ID_TAG = "template_id";
    public static final String POLICY_VERSION_TAG = "policy_version";
    public static final String FAILURE_KIND_TAG = "failure_kind";

    private static final String POLICY_VERSION = "health-safety-v1";
    private static final String NO_TEMPLATE = "none";

    private final MeterRegistry meterRegistry;
    private final boolean enabled;

    public CustomSceneSafetyMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = Objects.requireNonNull(meterRegistry, "meterRegistry");
        this.enabled = true;
    }

    private CustomSceneSafetyMetrics() {
        this.meterRegistry = null;
        this.enabled = false;
    }

    /** Keeps focused policy tests that do not provide an application registry side-effect free. */
    public static CustomSceneSafetyMetrics noop() {
        return new CustomSceneSafetyMetrics();
    }

    public void recordResult(CustomSceneSafetyDecision decision) {
        if (!enabled || decision == null || decision.resultType() == null) {
            return;
        }
        var resultType = MetricResultType.from(decision.resultType());
        var templateId = TemplateId.from(decision);
        var policyVersion = PolicyVersion.from(policyVersion(decision));
        Counter.builder(RESULT_COUNTER)
                .description("Custom scene safety decisions by fixed result type")
                .tags(
                        RESULT_TYPE_TAG, resultType.wireValue(),
                        TEMPLATE_ID_TAG, templateId.wireValue(),
                        POLICY_VERSION_TAG, policyVersion.wireValue())
                .register(meterRegistry)
                .increment();
    }

    public void recordClassifierTimeout() {
        recordFailure(FailureKind.CLASSIFIER_TIMEOUT);
    }

    public void recordInvalidOutput() {
        recordFailure(FailureKind.INVALID_OUTPUT);
    }

    public void recordBlockedLegacyBypass() {
        recordFailure(FailureKind.BLOCKED_LEGACY_BYPASS);
    }

    public void recordFailure(FailureKind failureKind) {
        if (!enabled || failureKind == null) {
            return;
        }
        Counter.builder(FAILURE_COUNTER)
                .description("Custom scene safety failures by fixed failure kind")
                .tags(
                        RESULT_TYPE_TAG, MetricResultType.ASSESSMENT_UNAVAILABLE.wireValue(),
                        TEMPLATE_ID_TAG, TemplateId.ASSESSMENT_UNAVAILABLE.wireValue(),
                        POLICY_VERSION_TAG, PolicyVersion.HEALTH_SAFETY_V1.wireValue(),
                        FAILURE_KIND_TAG, failureKind.wireValue())
                .register(meterRegistry)
                .increment();
    }

    public Timer.Sample startClassifierTimer() {
        return enabled ? Timer.start(meterRegistry) : null;
    }

    public void recordClassifierDuration(Timer.Sample sample) {
        if (sample == null || !enabled) {
            return;
        }
        sample.stop(Timer.builder(CLASSIFIER_TIMER)
                .description("Custom scene safety classifier duration")
                .tag(POLICY_VERSION_TAG, PolicyVersion.HEALTH_SAFETY_V1.wireValue())
                .register(meterRegistry));
    }

    private String policyVersion(CustomSceneSafetyDecision decision) {
        if (decision.assessment() == null || decision.assessment().policyVersion() == null) {
            return POLICY_VERSION;
        }
        return decision.assessment().policyVersion();
    }

    public enum FailureKind {
        CLASSIFIER_TIMEOUT("classifier_timeout"),
        INVALID_OUTPUT("invalid_output"),
        BLOCKED_LEGACY_BYPASS("blocked_legacy_bypass");

        private final String wireValue;

        FailureKind(String wireValue) {
            this.wireValue = wireValue;
        }

        public String wireValue() {
            return wireValue;
        }
    }

    private enum MetricResultType {
        GENERATED_SCENE("generated_scene"),
        HEALTH_SAFETY("health_safety"),
        ASSESSMENT_UNAVAILABLE("assessment_unavailable");

        private final String wireValue;

        MetricResultType(String wireValue) {
            this.wireValue = wireValue;
        }

        private String wireValue() {
            return wireValue;
        }

        private static MetricResultType from(CustomSceneSafetyDecision.ResultType resultType) {
            return switch (resultType) {
                case GENERATED_SCENE -> GENERATED_SCENE;
                case HEALTH_SAFETY -> HEALTH_SAFETY;
                case ASSESSMENT_UNAVAILABLE -> ASSESSMENT_UNAVAILABLE;
            };
        }
    }

    private enum PolicyVersion {
        HEALTH_SAFETY_V1("health-safety-v1"),
        UNKNOWN("unknown");

        private final String wireValue;

        PolicyVersion(String wireValue) {
            this.wireValue = wireValue;
        }

        private String wireValue() {
            return wireValue;
        }

        private static PolicyVersion from(String value) {
            if (HEALTH_SAFETY_V1.wireValue.equals(value)) {
                return HEALTH_SAFETY_V1;
            }
            return UNKNOWN;
        }
    }

    private enum TemplateId {
        NONE(NO_TEMPLATE),
        HEALTH_EMERGENCY("health-emergency-v1"),
        HEALTH_CONCERN("health-concern-v1"),
        HEALTH_PROMPT_ASSESSMENT("health-prompt-assessment-v1"),
        HEALTH_UNCERTAIN("health-uncertain-v1"),
        ASSESSMENT_UNAVAILABLE("health-assessment-unavailable-v1"),
        UNKNOWN("unknown");

        private final String wireValue;

        TemplateId(String wireValue) {
            this.wireValue = wireValue;
        }

        private String wireValue() {
            return wireValue;
        }

        private static TemplateId from(CustomSceneSafetyDecision decision) {
            if (decision.resultType() == CustomSceneSafetyDecision.ResultType.GENERATED_SCENE) {
                return NONE;
            }
            var assessment = decision.assessment();
            if (assessment == null || assessment.templateId() == null) {
                return UNKNOWN;
            }
            return switch (assessment.templateId()) {
                case "health-emergency-v1" -> HEALTH_EMERGENCY;
                case "health-concern-v1" -> HEALTH_CONCERN;
                case "health-prompt-assessment-v1" -> HEALTH_PROMPT_ASSESSMENT;
                case "health-uncertain-v1" -> HEALTH_UNCERTAIN;
                case "health-assessment-unavailable-v1" -> ASSESSMENT_UNAVAILABLE;
                default -> UNKNOWN;
            };
        }
    }
}
