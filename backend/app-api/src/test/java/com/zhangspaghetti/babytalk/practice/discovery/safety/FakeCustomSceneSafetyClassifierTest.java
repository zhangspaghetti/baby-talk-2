package com.zhangspaghetti.babytalk.practice.discovery.safety;

import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.ORDINARY_SCENE;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.REAL_HEALTH_CONCERN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.UNCERTAIN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.AMBIGUOUS_CONCERN;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyClassifier.Signal.HEALTH_CONCERN;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class FakeCustomSceneSafetyClassifierTest {

    private static final String LOCALE = "zh-CN";
    private static final String POLICY = "health-safety-v1";

    @Test
    void deterministicFixturesReturnOnlySemanticValues() {
        var request = request("宝宝拉肚子哭闹怎么办");

        var ordinary = new FakeCustomSceneSafetyClassifier(
                FakeCustomSceneSafetyClassifier.Fixture.ORDINARY_SCENE).classify(request);
        var health = new FakeCustomSceneSafetyClassifier(
                FakeCustomSceneSafetyClassifier.Fixture.HEALTH_CONCERN).classify(request);
        var uncertain = new FakeCustomSceneSafetyClassifier(
                FakeCustomSceneSafetyClassifier.Fixture.UNCERTAIN).classify(request);

        assertThat(ordinary.intent()).isEqualTo(ORDINARY_SCENE);
        assertThat(ordinary.signals()).isEmpty();
        assertThat(health.intent()).isEqualTo(REAL_HEALTH_CONCERN);
        assertThat(health.signals()).containsExactly(HEALTH_CONCERN);
        assertThat(uncertain.intent()).isEqualTo(UNCERTAIN);
        assertThat(uncertain.signals()).containsExactly(AMBIGUOUS_CONCERN);
        assertThat(ordinary.toString()).doesNotContain("建议", "剂量", "医生");
        assertThat(health.toString()).doesNotContain("建议", "剂量", "医生");
        assertThat(uncertain.toString()).doesNotContain("建议", "剂量", "医生");
    }

    @Test
    void autoFixtureClassifiesKnownHealthUncertainAndOrdinaryExamplesDeterministically() {
        var classifier = new FakeCustomSceneSafetyClassifier();

        assertThat(classifier.classify(request("宝宝拉肚子哭闹怎么办")).intent())
                .isEqualTo(REAL_HEALTH_CONCERN);
        assertThat(classifier.classify(request("宝宝不对劲，不知道怎么了")).intent())
                .isEqualTo(UNCERTAIN);
        assertThat(classifier.classify(request("宝宝哭闹，要抱抱，没有身体不适")).intent())
                .isEqualTo(ORDINARY_SCENE);
    }

    @Test
    void laterHealthSignalWinsAfterEarlierNoConcernClause() {
        var result = new FakeCustomSceneSafetyClassifier().classify(
                request("宝宝没有身体不适，但宝宝拉肚子"));

        assertThat(result.intent()).isEqualTo(REAL_HEALTH_CONCERN);
        assertThat(result.signals()).containsExactly(HEALTH_CONCERN);
    }

    @Test
    void disabledAndUnavailableFixturesFailClosedWithoutAdvice() {
        var request = request("宝宝洗澡一直躲水");

        assertThatThrownBy(() -> new FakeCustomSceneSafetyClassifier(
                FakeCustomSceneSafetyClassifier.Fixture.DISABLED).classify(request))
                .isInstanceOf(CustomSceneSafetyClassifier.UnavailableException.class)
                .hasMessage("custom scene safety classifier unavailable");
        assertThatThrownBy(() -> new FakeCustomSceneSafetyClassifier("disabled").classify(request))
                .isInstanceOf(CustomSceneSafetyClassifier.UnavailableException.class)
                .hasMessage("custom scene safety classifier unavailable");
        assertThatThrownBy(() -> new FakeCustomSceneSafetyClassifier("unavailable").classify(request))
                .isInstanceOf(CustomSceneSafetyClassifier.UnavailableException.class)
                .hasMessage("custom scene safety classifier unavailable");
    }

    private CustomSceneSafetyClassifier.ClassifierRequest request(String text) {
        return new CustomSceneSafetyClassifier.ClassifierRequest(text, "m7_11", LOCALE, POLICY);
    }
}
