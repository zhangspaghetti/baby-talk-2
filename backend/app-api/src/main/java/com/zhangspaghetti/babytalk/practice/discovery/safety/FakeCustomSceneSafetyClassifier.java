package com.zhangspaghetti.babytalk.practice.discovery.safety;

import java.util.List;
import java.util.Locale;
import java.util.Objects;

/** Deterministic fixture classifier for local development and tests. */
public final class FakeCustomSceneSafetyClassifier implements CustomSceneSafetyClassifier {

    private static final String POLICY_VERSION = "health-safety-v1";
    private static final String LOCALE = "zh-CN";

    private final Fixture fixture;

    public FakeCustomSceneSafetyClassifier() {
        this(Fixture.AUTO);
    }

    public FakeCustomSceneSafetyClassifier(Fixture fixture) {
        this.fixture = Objects.requireNonNull(fixture, "fixture");
    }

    public FakeCustomSceneSafetyClassifier(String mode) {
        this(parseFixture(mode));
    }

    public FakeCustomSceneSafetyClassifier(boolean enabled) {
        this(enabled ? Fixture.AUTO : Fixture.DISABLED);
    }

    @Override
    public SemanticResult classify(ClassifierRequest request) {
        validateRequest(request);
        return switch (fixture) {
            case AUTO -> classifyFixture(request.displayText());
            case ORDINARY, ORDINARY_SCENE -> new SemanticResult(
                    CustomSceneSafetyAssessment.Intent.ORDINARY_SCENE, List.of());
            case HEALTH, HEALTH_CONCERN -> new SemanticResult(
                    CustomSceneSafetyAssessment.Intent.REAL_HEALTH_CONCERN,
                    List.of(Signal.HEALTH_CONCERN));
            case PROMPT, PROMPT_ASSESSMENT -> new SemanticResult(
                    CustomSceneSafetyAssessment.Intent.REAL_HEALTH_CONCERN,
                    List.of(Signal.HEALTH_CONCERN, Signal.PROMPT_ASSESSMENT));
            case UNCERTAIN -> new SemanticResult(
                    CustomSceneSafetyAssessment.Intent.UNCERTAIN,
                    List.of(Signal.AMBIGUOUS_CONCERN));
            case DISABLED, UNAVAILABLE -> throw unavailable();
        };
    }

    public Fixture fixture() {
        return fixture;
    }

    public static FakeCustomSceneSafetyClassifier ordinary() {
        return new FakeCustomSceneSafetyClassifier(Fixture.ORDINARY_SCENE);
    }

    public static FakeCustomSceneSafetyClassifier health() {
        return new FakeCustomSceneSafetyClassifier(Fixture.HEALTH_CONCERN);
    }

    public static FakeCustomSceneSafetyClassifier uncertain() {
        return new FakeCustomSceneSafetyClassifier(Fixture.UNCERTAIN);
    }

    public static FakeCustomSceneSafetyClassifier disabled() {
        return new FakeCustomSceneSafetyClassifier(Fixture.DISABLED);
    }

    private SemanticResult classifyFixture(String text) {
        var normalized = text.toLowerCase(Locale.ROOT);
        if (containsAny(normalized, "不对劲", "不知道", "不确定", "说不上", "怎么回事")) {
            return new SemanticResult(
                    CustomSceneSafetyAssessment.Intent.UNCERTAIN,
                    List.of(Signal.AMBIGUOUS_CONCERN));
        }
        if (containsAny(
                normalized,
                "拉肚子", "拉稀", "腹泻", "不喝奶", "尿明显少", "尿少", "发烧",
                "呕吐", "没精神", "肚子疼", "咳嗽", "疼痛")) {
            var signals = containsAny(normalized, "需要评估", "请联系医生", "儿科医生", "及时就医")
                    ? List.of(Signal.HEALTH_CONCERN, Signal.PROMPT_ASSESSMENT)
                    : List.of(Signal.HEALTH_CONCERN);
            return new SemanticResult(CustomSceneSafetyAssessment.Intent.REAL_HEALTH_CONCERN, signals);
        }
        if (containsAny(normalized, "没有身体不适", "无身体不适", "没有不舒服", "无不舒服")) {
            return new SemanticResult(
                    CustomSceneSafetyAssessment.Intent.ORDINARY_SCENE, List.of());
        }
        if (containsAny(normalized, "身体不适", "不舒服")) {
            return new SemanticResult(
                    CustomSceneSafetyAssessment.Intent.REAL_HEALTH_CONCERN,
                    List.of(Signal.HEALTH_CONCERN));
        }
        if (containsAny(normalized, "康复", "恢复", "好了", "没事了")) {
            return new SemanticResult(
                    CustomSceneSafetyAssessment.Intent.ORDINARY_SCENE, List.of(Signal.RECOVERED));
        }
        if (containsAny(normalized, "医生游戏", "故事里", "故事中", "小说里", "只是游戏")) {
            return new SemanticResult(
                    CustomSceneSafetyAssessment.Intent.ORDINARY_SCENE, List.of(Signal.FICTIONAL));
        }
        return new SemanticResult(CustomSceneSafetyAssessment.Intent.ORDINARY_SCENE, List.of());
    }

    private void validateRequest(ClassifierRequest request) {
        if (request == null
                || isBlank(request.displayText())
                || isBlank(request.ageRange())
                || !LOCALE.equals(request.locale())
                || !POLICY_VERSION.equals(request.policyVersion())) {
            throw unavailable();
        }
    }

    private static Fixture parseFixture(String value) {
        var normalized = value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
        return switch (normalized) {
            case "", "auto", "fake", "enabled" -> Fixture.AUTO;
            case "ordinary", "ordinary_scene" -> Fixture.ORDINARY_SCENE;
            case "health", "health_concern", "health-concern" -> Fixture.HEALTH_CONCERN;
            case "prompt", "prompt_assessment", "prompt-assessment" -> Fixture.PROMPT_ASSESSMENT;
            case "uncertain" -> Fixture.UNCERTAIN;
            case "disabled" -> Fixture.DISABLED;
            case "unavailable" -> Fixture.UNAVAILABLE;
            default -> throw new IllegalArgumentException("unknown fake classifier fixture");
        };
    }

    private static boolean containsAny(String value, String... markers) {
        for (var marker : markers) {
            if (value.contains(marker)) {
                return true;
            }
        }
        return false;
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private static CustomSceneSafetyClassifier.UnavailableException unavailable() {
        return new CustomSceneSafetyClassifier.UnavailableException();
    }

    public enum Fixture {
        AUTO,
        ORDINARY,
        ORDINARY_SCENE,
        HEALTH,
        HEALTH_CONCERN,
        PROMPT,
        PROMPT_ASSESSMENT,
        UNCERTAIN,
        DISABLED,
        UNAVAILABLE
    }
}
