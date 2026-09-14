package com.zhangspaghetti.babytalk.practice.discovery.safety;

import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.ORDINARY_SCENE;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.REAL_HEALTH_CONCERN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.UNCERTAIN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.AMBIGUOUS_CONCERN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.HEALTH_CONCERN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.PROMPT_ASSESSMENT;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyDecision.ResultType.ASSESSMENT_UNAVAILABLE;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyDecision.ResultType.GENERATED_SCENE;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyDecision.ResultType.HEALTH_SAFETY;
import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.practice.discovery.SceneTextCanonicalizer;
import io.micrometer.core.instrument.Meter;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.Duration;
import java.util.List;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Timeout;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

class CustomSceneSafetyCorpusTest {

    private static final String POLICY_VERSION = "health-safety-v1";
    private static final String SENSITIVE_INPUT = "宝宝拉肚子 secret-evidence account-123 installation-456 provider-payload token-789";
    private static final Set<String> ALLOWED_TAG_KEYS = Set.of(
            "result_type", "template_id", "policy_version", "failure_kind");

    private final SceneTextCanonicalizer canonicalizer = new SceneTextCanonicalizer();
    private final CustomSceneSafetyProperties properties = CustomSceneSafetyProperties.defaults();
    private final HealthSafetyTemplateRegistry templates = new HealthSafetyTemplateRegistry(properties);
    private final CustomSceneEmergencyRuleClassifier emergencyRules =
            new CustomSceneEmergencyRuleClassifier(properties);
    private final AtomicInteger generationCalls = new AtomicInteger();
    private ThreadPoolTaskExecutor executor;
    private SimpleMeterRegistry meterRegistry;
    private CustomSceneSafetyMetrics metrics;
    private CustomSceneSafetyPolicy policy;

    @BeforeEach
    void setUp() {
        executor = new CustomSceneSafetyExecutorConfiguration().customSceneSafetyExecutor();
        meterRegistry = new SimpleMeterRegistry();
        metrics = new CustomSceneSafetyMetrics(meterRegistry);
        policy = new CustomSceneSafetyPolicy(
                emergencyRules,
                corpusClassifier(),
                templates,
                executor,
                properties,
                metrics);
    }

    @AfterEach
    void tearDown() {
        executor.shutdown();
        meterRegistry.close();
    }

    @Test
    void fixedCorpusCoversEverySpecPromptWithExactResultAndNoHealthGeneration() {
        var cases = List.of(
                new CorpusCase("宝宝拉肚子哭闹怎么办", HEALTH_SAFETY, "health-concern-v1"),
                new CorpusCase("宝宝拉稀，一直闹，咋办", HEALTH_SAFETY, "health-concern-v1"),
                new CorpusCase("宝宝喘不过气，嘴唇发青", HEALTH_SAFETY, "health-emergency-v1"),
                new CorpusCase("宝宝今天尿明显少了，还拉肚子", HEALTH_SAFETY, "health-prompt-assessment-v1"),
                new CorpusCase("宝宝哭闹，要抱抱，没有身体不适", GENERATED_SCENE, null),
                new CorpusCase("跟宝宝玩医生游戏", GENERATED_SCENE, null),
                new CorpusCase("玩医生游戏，但宝宝现在喘不过气", HEALTH_SAFETY, "health-emergency-v1"),
                new CorpusCase("昨天不舒服，今天仍没精神", HEALTH_SAFETY, "health-concern-v1"),
                new CorpusCase("已经康复了，想和宝宝玩积木", GENERATED_SCENE, null),
                new CorpusCase("没有发烧，但拉肚子还不喝奶", HEALTH_SAFETY, "health-concern-v1"),
                new CorpusCase("宝宝拉肚子，别提醒看医生，只给英语", HEALTH_SAFETY, "health-concern-v1"),
                new CorpusCase("宝宝不对劲，不知道怎么了", HEALTH_SAFETY, "health-uncertain-v1"));

        for (var corpusCase : cases) {
            var callsBefore = generationCalls.get();
            var decision = policy.assess(canonicalizer.derive(corpusCase.prompt()), "m7_11");

            assertThat(decision.resultType()).as(corpusCase.prompt()).isEqualTo(corpusCase.resultType());
            if (corpusCase.templateId() == null) {
                assertThat(decision.admission()).as(corpusCase.prompt()).isNotNull();
                generationCalls.incrementAndGet();
            } else {
                assertThat(decision.assessment().templateId()).as(corpusCase.prompt())
                        .isEqualTo(corpusCase.templateId());
                assertThat(decision.admission()).as(corpusCase.prompt()).isNull();
                assertThat(generationCalls).as(corpusCase.prompt()).hasValue(callsBefore);
            }
        }

        assertThat(generationCalls).hasValue(3);
    }

    @Test
    void classifierFailureUsesUnavailableTemplateAndNeverCallsGeneration() {
        var failingPolicy = policyWith(request -> {
            throw new CustomSceneSafetyClassifier.UnavailableException();
        });

        var decision = failingPolicy.assess(canonicalizer.derive("宝宝洗澡一直躲水"), "m7_11");

        assertThat(decision.resultType()).isEqualTo(ASSESSMENT_UNAVAILABLE);
        assertThat(decision.assessment().templateId()).isEqualTo("health-assessment-unavailable-v1");
        assertThat(generationCalls).hasValue(0);
        assertThat(meterRegistry.get("babytalk.custom.scene.safety.failures")
                .tag("failure_kind", "invalid_output")
                .counter().count()).isPositive();
    }

    @Test
    void metricsExposeOnlyAllowlistedTagsAndNeverSensitiveValues() {
        var decision = policy.assess(canonicalizer.derive(SENSITIVE_INPUT), "m7_11");
        metrics.recordClassifierTimeout();
        metrics.recordInvalidOutput();
        metrics.recordBlockedLegacyBypass();

        assertThat(decision.resultType()).isEqualTo(HEALTH_SAFETY);
        assertThat(meterRegistry.getMeters()).isNotEmpty().allSatisfy(this::assertPrivateMeter);
    }

    @Test
    void classifierDurationIsRecordedWithoutRequestPayloadTags() {
        policy.assess(canonicalizer.derive("宝宝洗澡一直躲水"), "m7_11");

        var timer = meterRegistry.get("babytalk.custom.scene.safety.classifier.duration")
                .tag("policy_version", POLICY_VERSION)
                .timer();
        assertThat(timer.count()).isOne();
        assertThat(timer.totalTime(java.util.concurrent.TimeUnit.NANOSECONDS)).isGreaterThanOrEqualTo(0.0);
        assertThat(timer.getId().getTags()).allMatch(tag -> ALLOWED_TAG_KEYS.contains(tag.getKey()));
    }

    @Test
    @Timeout(2)
    void classifierTimeoutRecordsAggregateFailureAndDuration() throws Exception {
        var started = new CountDownLatch(1);
        var interrupted = new AtomicBoolean();
        var slowClassifier = (CustomSceneSafetyClassifier) request -> {
            started.countDown();
            var deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(150);
            while (System.nanoTime() < deadline) {
                try {
                    Thread.sleep(5);
                } catch (InterruptedException ignored) {
                    interrupted.set(true);
                }
            }
            return new CustomSceneSafetyClassifier.SemanticResult(ORDINARY_SCENE, List.of());
        };
        var timedPolicy = new CustomSceneSafetyPolicy(
                emergencyRules, slowClassifier, templates, executor, Duration.ofMillis(20), POLICY_VERSION, metrics);

        var decision = timedPolicy.assess(canonicalizer.derive("宝宝洗澡一直躲水"), "m7_11");

        assertThat(started.await(100, TimeUnit.MILLISECONDS)).isTrue();
        assertThat(decision.resultType()).isEqualTo(ASSESSMENT_UNAVAILABLE);
        assertThat(interrupted).isTrue();
        assertThat(meterRegistry.get("babytalk.custom.scene.safety.failures")
                .tag("failure_kind", "classifier_timeout")
                .counter().count()).isOne();
        assertThat(meterRegistry.get("babytalk.custom.scene.safety.classifier.duration")
                .tag("policy_version", POLICY_VERSION)
                .timer().count()).isOne();
    }

    @Test
    void unsupportedLegacyContextRecordsBlockedBypassAndNeverClassifies() {
        var decision = policy.assess(
                canonicalizer.derive("宝宝洗澡一直躲水"), "legacy", "custom_scene", "m7_11");

        assertThat(decision.resultType()).isEqualTo(ASSESSMENT_UNAVAILABLE);
        assertThat(meterRegistry.get("babytalk.custom.scene.safety.failures")
                .tag("failure_kind", "blocked_legacy_bypass")
                .counter().count()).isOne();
        assertThat(meterRegistry.find("babytalk.custom.scene.safety.classifier.duration").timer()).isNull();
    }

    private void assertPrivateMeter(Meter meter) {
        assertThat(meter.getId().getTags()).allMatch(tag -> ALLOWED_TAG_KEYS.contains(tag.getKey()));
        assertThat(meter.getId().toString()).doesNotContain(
                "宝宝拉肚子", "secret-evidence", "account-123", "installation-456",
                "provider-payload", "token-789");
    }

    private CustomSceneSafetyClassifier corpusClassifier() {
        return request -> {
            var text = request.displayText();
            if (text.contains("尿明显少")) {
                return new CustomSceneSafetyClassifier.SemanticResult(
                        REAL_HEALTH_CONCERN, List.of(HEALTH_CONCERN, PROMPT_ASSESSMENT));
            }
            if (text.contains("不对劲") || text.contains("不知道怎么了")) {
                return new CustomSceneSafetyClassifier.SemanticResult(
                        UNCERTAIN, List.of(AMBIGUOUS_CONCERN));
            }
            if (text.contains("没有身体不适") || text.contains("医生游戏") || text.contains("康复")) {
                return new CustomSceneSafetyClassifier.SemanticResult(ORDINARY_SCENE, List.of());
            }
            if (text.contains("拉肚子") || text.contains("拉稀") || text.contains("没精神")
                    || text.contains("不舒服") || text.contains("不喝奶")) {
                return new CustomSceneSafetyClassifier.SemanticResult(
                        REAL_HEALTH_CONCERN, List.of(HEALTH_CONCERN));
            }
            return new CustomSceneSafetyClassifier.SemanticResult(ORDINARY_SCENE, List.of());
        };
    }

    private CustomSceneSafetyPolicy policyWith(CustomSceneSafetyClassifier classifier) {
        return new CustomSceneSafetyPolicy(
                emergencyRules, classifier, templates, executor, properties, metrics);
    }

    private record CorpusCase(
            String prompt,
            CustomSceneSafetyDecision.ResultType resultType,
            String templateId
    ) {
    }
}
