package com.zhangspaghetti.babytalk.practice.discovery.safety;

import com.zhangspaghetti.babytalk.practice.discovery.SceneTextForms;
import java.time.Duration;
import java.util.EnumSet;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.core.task.AsyncTaskExecutor;
import org.springframework.stereotype.Component;

import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Action.EMERGENCY;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Action.SEEK_MEDICAL_HELP;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Action.UNCERTAIN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.ORDINARY_SCENE;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.REAL_HEALTH_CONCERN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.UNCERTAIN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.AMBIGUOUS_CONCERN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.HEALTH_CONCERN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.PROMPT_ASSESSMENT;

@Component
public final class CustomSceneSafetyPolicy {

    private static final String LOCALE = "zh-CN";
    private static final String HEALTH_SAFETY_POLICY_VERSION = "health-safety-v1";
    private static final String DEFAULT_SURFACE = "care_path";
    private static final String CUSTOM_SCENE_MODE = "custom_scene";

    private final CustomSceneEmergencyRuleClassifier emergencyRules;
    private final CustomSceneSafetyClassifier classifier;
    private final HealthSafetyTemplateRegistry templates;
    private final AsyncTaskExecutor executor;
    private final Duration classifierTimeout;
    private final String policyVersion;
    private final CustomSceneSafetyMetrics metrics;

    @Autowired
    public CustomSceneSafetyPolicy(
            CustomSceneEmergencyRuleClassifier emergencyRules,
            ObjectProvider<CustomSceneSafetyClassifier> classifierProvider,
            HealthSafetyTemplateRegistry templates,
            @Qualifier(CustomSceneSafetyExecutorConfiguration.EXECUTOR_BEAN_NAME)
            AsyncTaskExecutor executor,
            CustomSceneSafetyProperties properties,
            CustomSceneSafetyMetrics metrics
    ) {
        this(emergencyRules, classifierProvider == null ? null : classifierProvider.getIfAvailable(), templates, executor,
                properties.classifierTimeout(), properties.policyVersion(), metrics);
    }

    public CustomSceneSafetyPolicy(
            CustomSceneEmergencyRuleClassifier emergencyRules,
            CustomSceneSafetyClassifier classifier,
            HealthSafetyTemplateRegistry templates,
            AsyncTaskExecutor executor,
            CustomSceneSafetyProperties properties
    ) {
        this(emergencyRules, classifier, templates, executor,
                properties.classifierTimeout(), properties.policyVersion(), CustomSceneSafetyMetrics.noop());
    }

    public CustomSceneSafetyPolicy(
            CustomSceneEmergencyRuleClassifier emergencyRules,
            CustomSceneSafetyClassifier classifier,
            HealthSafetyTemplateRegistry templates,
            AsyncTaskExecutor executor,
            CustomSceneSafetyProperties properties,
            CustomSceneSafetyMetrics metrics
    ) {
        this(emergencyRules, classifier, templates, executor,
                properties.classifierTimeout(), properties.policyVersion(), metrics);
    }

    public CustomSceneSafetyPolicy(
            CustomSceneEmergencyRuleClassifier emergencyRules,
            CustomSceneSafetyClassifier classifier,
            HealthSafetyTemplateRegistry templates,
            AsyncTaskExecutor executor,
            Duration classifierTimeout,
            String policyVersion
    ) {
        this(emergencyRules, classifier, templates, executor, classifierTimeout, policyVersion,
                CustomSceneSafetyMetrics.noop());
    }

    public CustomSceneSafetyPolicy(
            CustomSceneEmergencyRuleClassifier emergencyRules,
            CustomSceneSafetyClassifier classifier,
            HealthSafetyTemplateRegistry templates,
            AsyncTaskExecutor executor,
            Duration classifierTimeout,
            String policyVersion,
            CustomSceneSafetyMetrics metrics
    ) {
        this.emergencyRules = Objects.requireNonNull(emergencyRules, "emergencyRules");
        this.classifier = classifier;
        this.templates = Objects.requireNonNull(templates, "templates");
        this.executor = Objects.requireNonNull(executor, "executor");
        this.classifierTimeout = requirePositive(classifierTimeout);
        this.policyVersion = requirePolicyVersion(policyVersion);
        this.metrics = Objects.requireNonNull(metrics, "metrics");
    }

    public CustomSceneSafetyPolicy(
            CustomSceneEmergencyRuleClassifier emergencyRules,
            CustomSceneSafetyClassifier classifier,
            HealthSafetyTemplateRegistry templates,
            AsyncTaskExecutor executor,
            Duration classifierTimeout
    ) {
        this(emergencyRules, classifier, templates, executor,
                classifierTimeout, HEALTH_SAFETY_POLICY_VERSION);
    }

    public CustomSceneSafetyDecision assess(SceneTextForms forms, String ageRange) {
        return assess(forms, DEFAULT_SURFACE, CUSTOM_SCENE_MODE, ageRange);
    }

    /** Assesses a custom-scene request while binding its exact surface and mode into admission. */
    public CustomSceneSafetyDecision assess(
            SceneTextForms forms,
            String surface,
            String mode,
            String ageRange
    ) {
        Optional<CustomSceneSafetyAssessment> urgent;
        try {
            urgent = emergencyRules.classify(forms);
        } catch (RuntimeException failure) {
            return unavailable(CustomSceneSafetyMetrics.FailureKind.INVALID_OUTPUT);
        }
        if (urgent == null) {
            return unavailable(CustomSceneSafetyMetrics.FailureKind.INVALID_OUTPUT);
        }
        if (urgent.isPresent()) {
            var assessment = urgent.orElse(null);
            if (isEmergencyAssessment(assessment)) {
                return record(CustomSceneSafetyDecision.health(
                        assessment, templates.template("health-emergency-v1")));
            }
            return unavailable(CustomSceneSafetyMetrics.FailureKind.INVALID_OUTPUT);
        }

        if (!supportedGenerationContext(surface, mode)) {
            metrics.recordBlockedLegacyBypass();
            return record(unavailable());
        }
        if (classifier == null || forms == null || isBlank(forms.displayText()) || isBlank(ageRange)) {
            return unavailable(CustomSceneSafetyMetrics.FailureKind.INVALID_OUTPUT);
        }

        var request = new CustomSceneSafetyClassifier.ClassifierRequest(
                forms.displayText(), ageRange.trim(), LOCALE, policyVersion);
        var result = new CompletableFuture<CustomSceneSafetyClassifier.SemanticResult>();
        Future<?> submitted = null;
        var timer = metrics.startClassifierTimer();
        try {
            submitted = executor.submit(() -> classifyInto(result, request));
            result.orTimeout(timeoutMillis(classifierTimeout), TimeUnit.MILLISECONDS);
            var decision = mapSemantic(result.join(), forms, request.ageRange(), surface, mode);
            if (decision.resultType() == CustomSceneSafetyDecision.ResultType.ASSESSMENT_UNAVAILABLE) {
                metrics.recordInvalidOutput();
            }
            return record(decision);
        } catch (RuntimeException failure) {
            cancel(submitted, result);
            if (hasCause(failure, TimeoutException.class)) {
                metrics.recordClassifierTimeout();
            } else {
                metrics.recordInvalidOutput();
            }
            return record(unavailable());
        } finally {
            metrics.recordClassifierDuration(timer);
        }
    }

    private void classifyInto(
            CompletableFuture<CustomSceneSafetyClassifier.SemanticResult> result,
            CustomSceneSafetyClassifier.ClassifierRequest request
    ) {
        try {
            result.complete(classifier.classify(request));
        } catch (Throwable failure) {
            result.completeExceptionally(new CustomSceneSafetyClassifier.UnavailableException());
        }
    }

    private CustomSceneSafetyDecision mapSemantic(
            CustomSceneSafetyClassifier.SemanticResult result,
            SceneTextForms forms,
            String ageRange,
            String surface,
            String mode
    ) {
        if (result == null || result.intent() == null || result.signals() == null) {
            return unavailable();
        }
        var signals = validateSignals(result.signals());
        if (signals == null) {
            return unavailable();
        }
        return switch (result.intent()) {
            case REAL_HEALTH_CONCERN -> healthAssessment(
                    signals.contains(PROMPT_ASSESSMENT)
                            ? "health-prompt-assessment-v1"
                            : "health-concern-v1",
                    REAL_HEALTH_CONCERN,
                    SEEK_MEDICAL_HELP);
            case UNCERTAIN -> healthAssessment(
                    "health-uncertain-v1", CustomSceneSafetyAssessment.Intent.UNCERTAIN,
                    CustomSceneSafetyAssessment.Action.UNCERTAIN);
            case ORDINARY_SCENE -> {
                if (signals.contains(HEALTH_CONCERN)
                        || signals.contains(PROMPT_ASSESSMENT)
                        || signals.contains(AMBIGUOUS_CONCERN)) {
                    yield unavailable();
                }
                yield CustomSceneSafetyDecision.generatedScene(
                        CustomSceneSafetyDecision.Admission.forPolicy(
                                forms,
                                surface,
                                mode,
                                ageRange,
                                LOCALE,
                                CustomSceneSafetyDecision.ownerContextPlaceholder(),
                                CustomSceneSafetyDecision.profileContextPlaceholder(),
                                policyVersion));
            }
        };
    }

    private CustomSceneSafetyDecision healthAssessment(
            String templateId,
            CustomSceneSafetyAssessment.Intent intent,
            CustomSceneSafetyAssessment.Action action
    ) {
        var template = templates.template(templateId);
        return CustomSceneSafetyDecision.health(new CustomSceneSafetyAssessment(
                intent, action, templateId, policyVersion), template);
    }

    private Set<CustomSceneSafetyClassifier.Signal> validateSignals(
            List<CustomSceneSafetyClassifier.Signal> values
    ) {
        var signals = EnumSet.noneOf(CustomSceneSafetyClassifier.Signal.class);
        for (var signal : values) {
            if (signal == null || !signals.add(signal)) {
                return null;
            }
        }
        return signals;
    }

    private boolean isEmergencyAssessment(CustomSceneSafetyAssessment assessment) {
        return assessment != null
                && assessment.intent() == REAL_HEALTH_CONCERN
                && assessment.action() == EMERGENCY
                && "health-emergency-v1".equals(assessment.templateId())
                && policyVersion.equals(assessment.policyVersion());
    }

    private boolean supportedGenerationContext(String surface, String mode) {
        return ("care_path".equals(surface) || "onboarding".equals(surface))
                && "custom_scene".equals(mode);
    }

    private CustomSceneSafetyDecision unavailable() {
        try {
            return CustomSceneSafetyDecision.assessmentUnavailable(
                    templates.template("health-assessment-unavailable-v1"));
        } catch (RuntimeException failure) {
            return CustomSceneSafetyDecision.assessmentUnavailable(new CustomSceneSafetyAssessment(
                    CustomSceneSafetyAssessment.Intent.UNCERTAIN,
                    CustomSceneSafetyAssessment.Action.UNCERTAIN,
                    "health-assessment-unavailable-v1",
                    HEALTH_SAFETY_POLICY_VERSION));
        }
    }

    private CustomSceneSafetyDecision unavailable(CustomSceneSafetyMetrics.FailureKind failureKind) {
        metrics.recordFailure(failureKind);
        return record(unavailable());
    }

    private CustomSceneSafetyDecision record(CustomSceneSafetyDecision decision) {
        metrics.recordResult(decision);
        return decision;
    }

    private void cancel(
            Future<?> submitted,
            CompletableFuture<?> result
    ) {
        if (submitted != null) {
            submitted.cancel(true);
        }
        result.cancel(true);
    }

    private static long timeoutMillis(Duration timeout) {
        return Math.max(1L, timeout.toMillis());
    }

    private static boolean hasCause(Throwable failure, Class<? extends Throwable> type) {
        for (var cause = failure; cause != null; cause = cause.getCause()) {
            if (type.isInstance(cause)) {
                return true;
            }
        }
        return false;
    }

    private static Duration requirePositive(Duration timeout) {
        if (timeout == null || timeout.isZero() || timeout.isNegative()) {
            throw new IllegalArgumentException("classifier timeout must be positive");
        }
        return timeout;
    }

    private static String requirePolicyVersion(String value) {
        if (!HEALTH_SAFETY_POLICY_VERSION.equals(value)) {
            throw new IllegalArgumentException("health safety policy version must be health-safety-v1");
        }
        return value;
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
