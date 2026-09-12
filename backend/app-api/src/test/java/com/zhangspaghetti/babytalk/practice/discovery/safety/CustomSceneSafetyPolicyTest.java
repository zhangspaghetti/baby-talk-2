package com.zhangspaghetti.babytalk.practice.discovery.safety;

import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Action.EMERGENCY;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.ORDINARY_SCENE;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.REAL_HEALTH_CONCERN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.UNCERTAIN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.AMBIGUOUS_CONCERN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.FICTIONAL;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.HEALTH_CONCERN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.PROMPT_ASSESSMENT;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyDecision.ResultType.ASSESSMENT_UNAVAILABLE;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyDecision.ResultType.GENERATED_SCENE;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyDecision.ResultType.HEALTH_SAFETY;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.discovery.SceneTextCanonicalizer;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextForms;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

class CustomSceneSafetyPolicyTest {

    private final SceneTextCanonicalizer canonicalizer = new SceneTextCanonicalizer();
    private final CustomSceneSafetyProperties properties = CustomSceneSafetyProperties.defaults();
    private final HealthSafetyTemplateRegistry templates = new HealthSafetyTemplateRegistry(properties);
    private final CustomSceneEmergencyRuleClassifier emergencyRules = Mockito.mock(
            CustomSceneEmergencyRuleClassifier.class);
    private final CustomSceneSafetyClassifier classifier = Mockito.mock(CustomSceneSafetyClassifier.class);
    private final ThreadPoolTaskExecutor executor = new CustomSceneSafetyExecutorConfiguration()
            .customSceneSafetyExecutor();

    @AfterEach
    void stopExecutor() {
        executor.shutdown();
    }

    @Test
    void diarrheaConcernMapsToFixedTemplateAndSendsOnlySafeClassifierPayload() {
        when(classifier.classify(any())).thenReturn(new CustomSceneSafetyClassifier.SemanticResult(
                REAL_HEALTH_CONCERN, List.of(HEALTH_CONCERN)));
        var forms = canonicalizer.derive("宝宝拉肚子哭闹怎么办");

        var decision = policy().assess(forms, "m7_11");

        assertThat(decision.resultType()).isEqualTo(HEALTH_SAFETY);
        assertThat(decision.assessment().templateId()).isEqualTo("health-concern-v1");
        assertThat(decision.assessment().policyVersion()).isEqualTo("health-safety-v1");
        var request = ArgumentCaptor.forClass(CustomSceneSafetyClassifier.ClassifierRequest.class);
        verify(classifier).classify(request.capture());
        assertThat(request.getValue().displayText()).isEqualTo(forms.displayText());
        assertThat(request.getValue().ageRange()).isEqualTo("m7_11");
        assertThat(request.getValue().locale()).isEqualTo("zh-CN");
        assertThat(request.getValue().policyVersion()).isEqualTo("health-safety-v1");
        assertThat(request.getValue().toString())
                .doesNotContain("account", "installation", "token", "name", "trace");
    }

    @Test
    void promptAssessmentUsesPromptTemplate() {
        when(classifier.classify(any())).thenReturn(new CustomSceneSafetyClassifier.SemanticResult(
                REAL_HEALTH_CONCERN, List.of(HEALTH_CONCERN, PROMPT_ASSESSMENT)));

        var decision = policy().assess(canonicalizer.derive("宝宝今天尿明显少了，还拉肚子"), "m7_11");

        assertThat(decision.resultType()).isEqualTo(HEALTH_SAFETY);
        assertThat(decision.assessment().templateId()).isEqualTo("health-prompt-assessment-v1");
    }

    @Test
    void uncertainIntentUsesUncertainTemplate() {
        when(classifier.classify(any())).thenReturn(new CustomSceneSafetyClassifier.SemanticResult(
                UNCERTAIN, List.of(AMBIGUOUS_CONCERN)));

        var decision = policy().assess(canonicalizer.derive("宝宝不对劲，不知道怎么了"), "m7_11");

        assertThat(decision.resultType()).isEqualTo(HEALTH_SAFETY);
        assertThat(decision.assessment().templateId()).isEqualTo("health-uncertain-v1");
    }

    @Test
    void classifierFailureNullAndInconsistentOutputCloseGenerationPath() {
        var forms = canonicalizer.derive("宝宝洗澡一直躲水");

        when(classifier.classify(any())).thenThrow(new CustomSceneSafetyClassifier.UnavailableException());
        assertUnavailable(forms);

        doReturn(null).when(classifier).classify(any());
        assertUnavailable(forms);

        doReturn(new CustomSceneSafetyClassifier.SemanticResult(
                null, List.of())).when(classifier).classify(any());
        assertUnavailable(forms);

        doReturn(new CustomSceneSafetyClassifier.SemanticResult(
                ORDINARY_SCENE, List.of(HEALTH_CONCERN))).when(classifier).classify(any());
        assertUnavailable(forms);

        doReturn(new CustomSceneSafetyClassifier.SemanticResult(
                REAL_HEALTH_CONCERN, List.of(HEALTH_CONCERN, HEALTH_CONCERN))).when(classifier).classify(any());
        assertUnavailable(forms);
    }

    @Test
    void emergencyHardRuleRunsBeforeSemanticClassifier() {
        var urgent = new CustomSceneSafetyAssessment(
                REAL_HEALTH_CONCERN, EMERGENCY, "health-emergency-v1", "health-safety-v1");
        when(emergencyRules.classify(any(SceneTextForms.class))).thenReturn(java.util.Optional.of(urgent));

        var decision = policy().assess(canonicalizer.derive("宝宝现在喘不过气"), "m7_11");

        assertThat(decision.resultType()).isEqualTo(HEALTH_SAFETY);
        assertThat(decision.assessment()).isEqualTo(urgent);
        verify(classifier, never()).classify(any());
    }

    @Test
    void onlyExplicitOrdinaryIntentGetsOpaqueAdmission() {
        when(classifier.classify(any())).thenReturn(new CustomSceneSafetyClassifier.SemanticResult(
                ORDINARY_SCENE, List.of()));
        var raw = "宝宝洗澡一直躲水，秘密编号-123";

        var decision = policy().assess(canonicalizer.derive(raw), "m7_11");

        assertThat(decision.resultType()).isEqualTo(GENERATED_SCENE);
        assertThat(decision.admission()).isNotNull();
        assertThat(decision.admission().toString()).doesNotContain(raw, "秘密编号", "123");
        assertThat(decision.toString()).doesNotContain(raw, "秘密编号", "123");
    }

    @Test
    void fictionalSignalCannotDowngradeRealHealthIntent() {
        when(classifier.classify(any())).thenReturn(new CustomSceneSafetyClassifier.SemanticResult(
                REAL_HEALTH_CONCERN, List.of(HEALTH_CONCERN, FICTIONAL)));

        var decision = policy().assess(canonicalizer.derive("故事里宝宝拉肚子"), "m7_11");

        assertThat(decision.resultType()).isEqualTo(HEALTH_SAFETY);
        assertThat(decision.assessment().templateId()).isEqualTo("health-concern-v1");
    }

    @Test
    @Timeout(value = 3500, unit = TimeUnit.MILLISECONDS)
    void blockingClassifierFailsClosedWithinThreeAndAHalfSecondsAndIsInterrupted() throws Exception {
        var started = new CountDownLatch(1);
        var interrupted = new CountDownLatch(1);
        when(classifier.classify(any())).thenAnswer(invocation -> {
            started.countDown();
            try {
                Thread.sleep(Duration.ofSeconds(30).toMillis());
            } catch (InterruptedException exception) {
                interrupted.countDown();
                throw new CustomSceneSafetyClassifier.UnavailableException();
            }
            return new CustomSceneSafetyClassifier.SemanticResult(ORDINARY_SCENE, List.of());
        });

        var startedAt = System.nanoTime();
        var decision = policy().assess(canonicalizer.derive("宝宝洗澡一直躲水"), "m7_11");
        var elapsedMillis = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startedAt);

        assertThat(started.await(100, TimeUnit.MILLISECONDS)).isTrue();
        assertThat(decision.resultType()).isEqualTo(ASSESSMENT_UNAVAILABLE);
        assertThat(elapsedMillis).isLessThan(3500);
        assertThat(interrupted.await(500, TimeUnit.MILLISECONDS)).isTrue();
    }

    @Test
    void saturatedExecutorRejectsWithoutRunningClassifierOnRequestThread() throws Exception {
        var release = new CountDownLatch(1);
        var workerThreads = java.util.concurrent.ConcurrentHashMap.<String>newKeySet();
        for (var index = 0; index < 20; index++) {
            executor.execute(() -> {
                workerThreads.add(Thread.currentThread().getName());
                try {
                    release.await();
                } catch (InterruptedException exception) {
                    Thread.currentThread().interrupt();
                }
            });
        }
        var classifierThread = new AtomicReference<String>();
        when(classifier.classify(any())).thenAnswer(invocation -> {
            classifierThread.set(Thread.currentThread().getName());
            return new CustomSceneSafetyClassifier.SemanticResult(ORDINARY_SCENE, List.of());
        });

        var requestThread = Thread.currentThread().getName();
        var decision = policy().assess(canonicalizer.derive("宝宝洗澡一直躲水"), "m7_11");

        assertThat(decision.resultType()).isEqualTo(ASSESSMENT_UNAVAILABLE);
        assertThat(classifierThread).hasValue(null);
        assertThat(workerThreads).allMatch(name -> !requestThread.equals(name));
        release.countDown();
    }

    private void assertUnavailable(SceneTextForms forms) {
        var decision = policy().assess(forms, "m7_11");
        assertThat(decision.resultType()).isEqualTo(ASSESSMENT_UNAVAILABLE);
        assertThat(decision.assessment().templateId()).isEqualTo("health-assessment-unavailable-v1");
        assertThat(decision.admission()).isNull();
    }

    private CustomSceneSafetyPolicy policy() {
        return new CustomSceneSafetyPolicy(emergencyRules, classifier, templates, executor, properties);
    }
}
