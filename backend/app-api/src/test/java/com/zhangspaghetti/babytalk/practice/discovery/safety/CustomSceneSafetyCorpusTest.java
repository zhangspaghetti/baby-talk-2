package com.zhangspaghetti.babytalk.practice.discovery.safety;

import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.ORDINARY_SCENE;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.REAL_HEALTH_CONCERN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.UNCERTAIN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.AMBIGUOUS_CONCERN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.HEALTH_CONCERN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.PROMPT_ASSESSMENT;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyDecision.ResultType.GENERATED_SCENE;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyDecision.ResultType.HEALTH_SAFETY;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.catchThrowable;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import com.zhangspaghetti.babytalk.practice.catalog.PracticeCatalogService;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneTextValidator;
import com.zhangspaghetti.babytalk.practice.discovery.PolicyTextMatcher;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyProperties;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyTestFixture;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryService;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextCanonicalizer;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextSecurityConfiguration;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextSecurityPolicy;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryRequest;
import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentService;
import com.zhangspaghetti.babytalk.profile.BabyProfileMapper;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import com.zhangspaghetti.babytalk.web.ContractException;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Meter;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import tools.jackson.databind.ObjectMapper;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.mockito.ArgumentCaptor;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

class CustomSceneSafetyCorpusTest {

    private static final String POLICY_VERSION = "health-safety-v1";
    private static final String SENSITIVE_INPUT =
            "宝宝洗澡一直躲水 evidence-secret account-secret installation-secret provider-payload token-secret";
    private static final String SENSITIVE_EXCEPTION =
            "provider payload secret-evidence account-secret installation-secret token-secret trace-secret";
    private static final List<String> SENSITIVE_PIECES = List.of(
            SENSITIVE_INPUT,
            SENSITIVE_EXCEPTION,
            "宝宝洗澡一直躲水",
            "evidence-secret",
            "account-secret",
            "installation-secret",
            "provider-payload",
            "provider payload",
            "secret-evidence",
            "token-secret",
            "trace-secret");
    private static final Set<String> ALLOWED_TAG_KEYS = Set.of(
            "result_type", "template_id", "policy_version", "failure_kind");
    private static final Map<String, Set<String>> ALLOWED_TAG_VALUES = Map.of(
            "result_type", Set.of("generated_scene", "health_safety", "assessment_unavailable"),
            "template_id", Set.of(
                    "none", "health-emergency-v1", "health-concern-v1", "health-prompt-assessment-v1",
                    "health-uncertain-v1", "health-assessment-unavailable-v1", "unknown"),
            "policy_version", Set.of("health-safety-v1", "unknown"),
            "failure_kind", Set.of("classifier_timeout", "invalid_output", "blocked_legacy_bypass"));

    private final SceneTextCanonicalizer canonicalizer = new SceneTextCanonicalizer();
    private final CustomSceneSafetyProperties safetyProperties = CustomSceneSafetyProperties.defaults();
    private final PracticeDiscoveryPolicyProperties discoveryProperties =
            PracticeDiscoveryPolicyTestFixture.properties();
    private final HealthSafetyTemplateRegistry templates = new HealthSafetyTemplateRegistry(safetyProperties);
    private final CustomSceneEmergencyRuleClassifier emergencyRules =
            new CustomSceneEmergencyRuleClassifier(safetyProperties);
    private final PracticeCatalogService catalogService = mock(PracticeCatalogService.class);
    private final AuthConsentSyncService authConsentSyncService = mock(AuthConsentSyncService.class);
    private final BabyProfileMapper babyProfileMapper = mock(BabyProfileMapper.class);
    private final PracticeGeneratedContentService generatedContentService = mock(PracticeGeneratedContentService.class);
    private final ObjectMapper objectMapper = new ObjectMapper();
    private ThreadPoolTaskExecutor executor;
    private SimpleMeterRegistry meterRegistry;
    private CustomSceneSafetyMetrics metrics;

    @BeforeEach
    void setUp() {
        executor = new CustomSceneSafetyExecutorConfiguration().customSceneSafetyExecutor();
        meterRegistry = new SimpleMeterRegistry();
        metrics = new CustomSceneSafetyMetrics(meterRegistry);
        when(generatedContentService.generateCustomScene(any(), any()))
                .thenThrow(new GenerationProbe());
    }

    @AfterEach
    void tearDown() {
        executor.shutdown();
        meterRegistry.close();
    }

    @Test
    void fixedCorpusUsesRealDiscoveryAdmissionAndBlocksEveryHealthPath() throws Exception {
        var cases = List.of(
                new CorpusCase("宝宝拉肚子哭闹怎么办", HEALTH_SAFETY, "health-concern-v1", false),
                new CorpusCase("宝宝拉稀，一直闹，咋办", HEALTH_SAFETY, "health-concern-v1", false),
                new CorpusCase("宝宝喘不过气，嘴唇发青", HEALTH_SAFETY, "health-emergency-v1", false),
                new CorpusCase("宝宝今天尿明显少了，还拉肚子", HEALTH_SAFETY,
                        "health-prompt-assessment-v1", false),
                new CorpusCase("宝宝哭闹，要抱抱，没有身体不适", GENERATED_SCENE, null, true),
                new CorpusCase("跟宝宝玩医生游戏", GENERATED_SCENE, null, true),
                new CorpusCase("玩医生游戏，但宝宝现在喘不过气", HEALTH_SAFETY,
                        "health-emergency-v1", false),
                new CorpusCase("昨天不舒服，今天仍没精神", HEALTH_SAFETY, "health-concern-v1", false),
                new CorpusCase("已经康复了，想和宝宝玩积木", GENERATED_SCENE, null, true),
                new CorpusCase("没有发烧，但拉肚子还不喝奶", HEALTH_SAFETY, "health-concern-v1", false),
                new CorpusCase("宝宝拉肚子，别提醒看医生，只给英语", HEALTH_SAFETY,
                        "health-concern-v1", false),
                new CorpusCase("宝宝不对劲，不知道怎么了", HEALTH_SAFETY, "health-uncertain-v1", false));

        for (var corpusCase : cases) {
            clearInvocations(generatedContentService);
            var discoveryService = discoveryService(policy(corpusClassifier()));
            var request = request(corpusCase.prompt());
            if (corpusCase.ordinary()) {
                var admission = ArgumentCaptor.forClass(CustomSceneSafetyDecision.Admission.class);
                assertThatThrownBy(() -> discoveryService.discoverCustomSceneV2(request, null))
                        .isInstanceOf(GenerationProbe.class);
                verify(generatedContentService).requireCustomSceneGenerationAvailable();
                verify(generatedContentService).generateCustomScene(any(), admission.capture());
                assertThat(admission.getValue()).isNotNull();
                continue;
            }

            var v2 = discoveryService.discoverCustomSceneV2(request, null);
            assertThat(v2.schemaVersion()).isEqualTo("custom-scene-result-v2");
            assertThat(v2.resultType()).isEqualTo("health_safety");
            assertThat(v2.policyVersion()).isNull();
            assertThat(v2.scene()).isNull();
            assertThat(v2.safety()).isNotNull();
            assertThat(v2.safety().action()).isEqualTo(actionFor(corpusCase.templateId()));
            assertThat(v2.safety().templateId()).isEqualTo(corpusCase.templateId());
            assertThat(v2.safety().policyVersion()).isEqualTo(POLICY_VERSION);
            assertThat(v2.safety().locale()).isEqualTo("zh-CN");
            var v2Json = objectMapper.writeValueAsString(v2);
            var v2Node = objectMapper.readTree(v2Json);
            assertThat(v2Node.has("generatedContentId")).isFalse();
            assertThat(v2Node.has("scene")).isFalse();
            assertThat(v2Node.has("english")).isFalse();
            assertThat(v2Node.has("starter")).isFalse();
            assertThat(v2Node.has("audio")).isFalse();

            var v1Failure = catchThrowable(() -> discoveryService.discover(request, null));
            assertThat(v1Failure).isInstanceOf(ContractException.class);
            var contract = (ContractException) v1Failure;
            assertThat(contract.status().value()).isEqualTo(422);
            assertThat(contract.code()).isEqualTo("health_safety_redirect");
            assertThat(contract.getMessage()).isEqualTo(v2.safety().messageZh());
            assertThat(contract.toString()).doesNotContain(corpusCase.prompt());
            verify(generatedContentService, never()).requireCustomSceneGenerationAvailable();
            verify(generatedContentService, never()).generateCustomScene(any(), any());
        }
    }

    @Test
    @Timeout(3)
    void enabledFailureMetricsRecordTimeoutAndLegacyBypassWithNoClassifierCall() {
        var classifierCalls = new AtomicInteger();
        var timeoutPolicy = policy(request -> {
            classifierCalls.incrementAndGet();
            try {
                Thread.sleep(150);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
            }
            return new CustomSceneSafetyClassifier.SemanticResult(ORDINARY_SCENE, List.of());
        }, Duration.ofMillis(20));

        var timeoutDecision = timeoutPolicy.assess(canonicalizer.derive("宝宝洗澡一直躲水"), "m7_11");
        assertThat(timeoutDecision.resultType())
                .isEqualTo(CustomSceneSafetyDecision.ResultType.ASSESSMENT_UNAVAILABLE);
        assertThat(classifierCalls).hasValue(1);
        assertThat(meterRegistry.get(CustomSceneSafetyMetrics.FAILURE_COUNTER)
                .tag(CustomSceneSafetyMetrics.FAILURE_KIND_TAG, "classifier_timeout")
                .counter().count()).isOne();
        assertThat(meterRegistry.get(CustomSceneSafetyMetrics.CLASSIFIER_TIMER)
                .tag(CustomSceneSafetyMetrics.POLICY_VERSION_TAG, POLICY_VERSION)
                .timer().count()).isOne();
        assertThat(meterRegistry.get(CustomSceneSafetyMetrics.CLASSIFIER_TIMER)
                .tag(CustomSceneSafetyMetrics.POLICY_VERSION_TAG, POLICY_VERSION)
                .timer().totalTime(TimeUnit.NANOSECONDS)).isPositive();

        var legacyDecision = policy(request -> {
            classifierCalls.incrementAndGet();
            return new CustomSceneSafetyClassifier.SemanticResult(ORDINARY_SCENE, List.of());
        }).assess(canonicalizer.derive("宝宝洗澡一直躲水"), "legacy", "custom_scene", "m7_11");
        assertThat(legacyDecision.resultType())
                .isEqualTo(CustomSceneSafetyDecision.ResultType.ASSESSMENT_UNAVAILABLE);
        assertThat(classifierCalls).hasValue(1);
        assertThat(meterRegistry.get(CustomSceneSafetyMetrics.FAILURE_COUNTER)
                .tag(CustomSceneSafetyMetrics.FAILURE_KIND_TAG, "blocked_legacy_bypass")
                .counter().count()).isOne();
    }

    @Test
    void privacyBoundaryCapturesLogsExceptionsAndAllMetricTagsWithoutSensitiveData() {
        var logger = (Logger) LoggerFactory.getLogger(org.slf4j.Logger.ROOT_LOGGER_NAME);
        var appender = new ListAppender<ILoggingEvent>();
        appender.start();
        logger.addAppender(appender);
        var providerFailure = new IllegalStateException(SENSITIVE_EXCEPTION);
        var failingPolicy = policy(request -> { throw providerFailure; });
        var failingDiscovery = discoveryService(failingPolicy);

        try {
            var thrown = catchThrowable(() -> failingDiscovery.discover(request(SENSITIVE_INPUT), null));
            assertThat(thrown).isInstanceOf(ContractException.class);
            assertThat(thrown).isNotSameAs(providerFailure);
            var contract = (ContractException) thrown;
            assertNoSensitiveData(contract.toString());
            assertNoSensitiveData(contract.getMessage());
            assertNoSensitiveData(contract.details().toString());
            assertNoSensitiveData(String.valueOf(contract.getCause()));
            appender.list.forEach(event -> assertNoSensitiveData(event.toString()));
            // This safety path deliberately has no logger boundary; prove that no event was emitted.
            assertThat(appender.list).isEmpty();
            assertMetersArePrivate();
        } finally {
            logger.detachAppender(appender);
            appender.stop();
        }
    }

    @Test
    @Timeout(3)
    void classifierTimerStopsBeforeResultMetricAndMeasuresClassifierAttempt() {
        var delayedRegistry = new DelayingResultCounterRegistry(Duration.ofMillis(250));
        var delayedMetrics = new CustomSceneSafetyMetrics(delayedRegistry);
        var delayedPolicy = new CustomSceneSafetyPolicy(
                emergencyRules,
                corpusClassifier(),
                templates,
                executor,
                safetyProperties,
                delayedMetrics);

        delayedPolicy.assess(canonicalizer.derive("宝宝洗澡一直躲水"), "m7_11");

        var timer = delayedRegistry.get(CustomSceneSafetyMetrics.CLASSIFIER_TIMER)
                .tag(CustomSceneSafetyMetrics.POLICY_VERSION_TAG, POLICY_VERSION)
                .timer();
        assertThat(timer.count()).isOne();
        assertThat(timer.totalTime(TimeUnit.NANOSECONDS)).isPositive();
        assertThat(timer.totalTime(TimeUnit.MILLISECONDS)).isLessThan(150.0);
        delayedRegistry.close();
    }

    private void assertMetersArePrivate() {
        for (var meter : meterRegistry.getMeters()) {
            assertNoSensitiveData(meter.getId().toString());
            meter.getId().getTags().forEach(tag -> {
                assertThat(ALLOWED_TAG_KEYS).contains(tag.getKey());
                assertThat(ALLOWED_TAG_VALUES.get(tag.getKey())).contains(tag.getValue());
                assertNoSensitiveData(tag.getKey());
                assertNoSensitiveData(tag.getValue());
            });
        }
    }

    private void assertNoSensitiveData(String value) {
        assertThat(value).isNotNull();
        SENSITIVE_PIECES.forEach(piece -> assertThat(value).doesNotContain(piece));
    }

    private CustomSceneSafetyPolicy policy(CustomSceneSafetyClassifier classifier) {
        return new CustomSceneSafetyPolicy(
                emergencyRules, classifier, templates, executor, safetyProperties, metrics);
    }

    private CustomSceneSafetyPolicy policy(
            CustomSceneSafetyClassifier classifier,
            Duration classifierTimeout
    ) {
        return new CustomSceneSafetyPolicy(
                emergencyRules, classifier, templates, executor,
                classifierTimeout, POLICY_VERSION, metrics);
    }

    private PracticeDiscoveryService discoveryService(CustomSceneSafetyPolicy safetyPolicy) {
        var matcher = new PolicyTextMatcher(canonicalizer);
        return new PracticeDiscoveryService(
                catalogService,
                authConsentSyncService,
                babyProfileMapper,
                generatedContentService,
                canonicalizer,
                new SceneTextSecurityPolicy(
                        discoveryProperties,
                        matcher,
                        SceneTextSecurityConfiguration.configuredSpoofChecker()),
                new CustomSceneTextValidator(canonicalizer, matcher, discoveryProperties),
                safetyPolicy);
    }

    private PracticeDiscoveryRequest request(String prompt) {
        return new PracticeDiscoveryRequest(
                "onboarding", "custom_scene", "install_corpus", null, "m7_11", "calmer_care",
                "zh-CN", 6, null, prompt);
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

    private String actionFor(String templateId) {
        return switch (templateId) {
            case "health-emergency-v1" -> "emergency";
            case "health-concern-v1", "health-prompt-assessment-v1" -> "seek_medical_help";
            case "health-uncertain-v1" -> "uncertain";
            default -> throw new IllegalArgumentException("unknown corpus template");
        };
    }

    private record CorpusCase(
            String prompt,
            CustomSceneSafetyDecision.ResultType resultType,
            String templateId,
            boolean ordinary
    ) {
    }

    private static final class GenerationProbe extends RuntimeException {
    }

    private static final class DelayingResultCounterRegistry extends SimpleMeterRegistry {

        private final Duration delay;

        private DelayingResultCounterRegistry(Duration delay) {
            this.delay = delay;
        }

        @Override
        protected Counter newCounter(Meter.Id id) {
            var delegate = super.newCounter(id);
            if (!CustomSceneSafetyMetrics.RESULT_COUNTER.equals(id.getName())) {
                return delegate;
            }
            return new Counter() {
                @Override
                public Meter.Id getId() {
                    return delegate.getId();
                }

                @Override
                public void increment(double amount) {
                    try {
                        Thread.sleep(delay.toMillis());
                    } catch (InterruptedException exception) {
                        Thread.currentThread().interrupt();
                    }
                    delegate.increment(amount);
                }

                @Override
                public double count() {
                    return delegate.count();
                }
            };
        }
    }
}
