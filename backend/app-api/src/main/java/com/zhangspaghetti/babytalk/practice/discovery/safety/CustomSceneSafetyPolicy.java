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

    private final CustomSceneEmergencyRuleClassifier emergencyRules;
    private final CustomSceneSafetyClassifier classifier;
    private final HealthSafetyTemplateRegistry templates;
    private final AsyncTaskExecutor executor;
    private final Duration classifierTimeout;
    private final String policyVersion;

    @Autowired
    public CustomSceneSafetyPolicy(
            CustomSceneEmergencyRuleClassifier emergencyRules,
            ObjectProvider<CustomSceneSafetyClassifier> classifierProvider,
            HealthSafetyTemplateRegistry templates,
            @Qualifier(CustomSceneSafetyExecutorConfiguration.EXECUTOR_BEAN_NAME)
            AsyncTaskExecutor executor,
            CustomSceneSafetyProperties properties
    ) {
        this(emergencyRules, classifierProvider == null ? null : classifierProvider.getIfAvailable(), templates, executor,
                properties.classifierTimeout(), properties.policyVersion());
    }

    public CustomSceneSafetyPolicy(
            CustomSceneEmergencyRuleClassifier emergencyRules,
            CustomSceneSafetyClassifier classifier,
            HealthSafetyTemplateRegistry templates,
            AsyncTaskExecutor executor,
            CustomSceneSafetyProperties properties
    ) {
        this(emergencyRules, classifier, templates, executor,
                properties.classifierTimeout(), properties.policyVersion());
    }

    public CustomSceneSafetyPolicy(
            CustomSceneEmergencyRuleClassifier emergencyRules,
            CustomSceneSafetyClassifier classifier,
            HealthSafetyTemplateRegistry templates,
            AsyncTaskExecutor executor,
            Duration classifierTimeout,
            String policyVersion
    ) {
        this.emergencyRules = Objects.requireNonNull(emergencyRules, "emergencyRules");
        this.classifier = classifier;
        this.templates = Objects.requireNonNull(templates, "templates");
        this.executor = Objects.requireNonNull(executor, "executor");
        this.classifierTimeout = requirePositive(classifierTimeout);
        this.policyVersion = requirePolicyVersion(policyVersion);
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

    public CustomSceneSafetyPolicy(
            CustomSceneEmergencyRuleClassifier emergencyRules,
            CustomSceneSafetyClassifier classifier,
            HealthSafetyTemplateRegistry templates,
            CustomSceneSafetyProperties properties
    ) {
        this(emergencyRules, classifier, templates,
                new CustomSceneSafetyExecutorConfiguration().customSceneSafetyExecutor(), properties);
    }

    public CustomSceneSafetyDecision assess(SceneTextForms forms, String ageRange) {
        Optional<CustomSceneSafetyAssessment> urgent;
        try {
            urgent = emergencyRules.classify(forms);
        } catch (RuntimeException failure) {
            return unavailable();
        }
        if (urgent != null && urgent.isPresent()) {
            var assessment = urgent.orElse(null);
            if (isEmergencyAssessment(assessment)) {
                return CustomSceneSafetyDecision.health(assessment);
            }
            return unavailable();
        }

        if (classifier == null || forms == null || isBlank(forms.displayText()) || isBlank(ageRange)) {
            return unavailable();
        }

        var request = new CustomSceneSafetyClassifier.ClassifierRequest(
                forms.displayText(), ageRange.trim(), LOCALE, policyVersion);
        var result = new CompletableFuture<CustomSceneSafetyClassifier.SemanticResult>();
        Future<?> submitted = null;
        try {
            submitted = executor.submit(() -> classifyInto(result, request));
            result.orTimeout(timeoutMillis(classifierTimeout), TimeUnit.MILLISECONDS);
            return mapSemantic(result.join(), forms, request.ageRange());
        } catch (RuntimeException failure) {
            cancel(submitted, result);
            return unavailable();
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
            String ageRange
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
                        CustomSceneSafetyDecision.bindAdmission(forms, ageRange, policyVersion));
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
