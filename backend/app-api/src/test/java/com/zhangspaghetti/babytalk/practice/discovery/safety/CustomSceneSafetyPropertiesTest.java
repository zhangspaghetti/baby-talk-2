package com.zhangspaghetti.babytalk.practice.discovery.safety;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;
import org.junit.jupiter.api.Test;

class CustomSceneSafetyPropertiesTest {

    @Test
    void defaultPolicyIsVersionedWithThreeSecondClassifierBudgetAndFiveTemplates() {
        var properties = CustomSceneSafetyProperties.defaults();

        assertThat(properties.policyVersion()).isEqualTo("health-safety-v1");
        assertThat(properties.classifierTimeout()).isEqualTo(Duration.ofSeconds(3));
        assertThat(properties.templates()).hasSize(5);
        assertThat(properties.emergencySignals()).containsKeys(
                "breathing-difficulty",
                "blue-lips",
                "cannot-wake",
                "seizure",
                "suspected-poisoning",
                "child-green-vomit");
    }

    @Test
    void policyValuesAreDefensivelyCopied() {
        var properties = CustomSceneSafetyProperties.defaults();

        assertThat(properties.templates()).isUnmodifiable();
        assertThat(properties.emergencySignals()).isUnmodifiable();
        assertThat(properties.emergencySignals().get("seizure")).isUnmodifiable();
    }

    @Test
    void blankPolicyVersionIsRejected() {
        var defaults = CustomSceneSafetyProperties.defaults();

        assertThatThrownBy(() -> new CustomSceneSafetyProperties(
                " ", defaults.classifierTimeout(), defaults.templates(), defaults.emergencySignals()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("policy version");
    }

    @Test
    void nonPositiveClassifierTimeoutIsRejected() {
        var defaults = CustomSceneSafetyProperties.defaults();

        assertThatThrownBy(() -> new CustomSceneSafetyProperties(
                defaults.policyVersion(), Duration.ZERO, defaults.templates(), defaults.emergencySignals()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("classifier timeout");
    }
}
