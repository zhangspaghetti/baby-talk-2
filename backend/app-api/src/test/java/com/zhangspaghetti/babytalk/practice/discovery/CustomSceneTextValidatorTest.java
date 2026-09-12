package com.zhangspaghetti.babytalk.practice.discovery;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.web.ContractException;
import org.junit.jupiter.api.Test;

class CustomSceneTextValidatorTest {

    private final SceneTextCanonicalizer canonicalizer = new SceneTextCanonicalizer();
    private final CustomSceneTextValidator validator = new CustomSceneTextValidator(
            canonicalizer,
            new PolicyTextMatcher(canonicalizer),
            PracticeDiscoveryPolicyTestFixture.properties());

    @Test
    void rejectsNullShortOverlongGraphemeAndCodePointInputs() {
        assertInvalid(null);
        assertInvalid("abc");
        assertInvalid("澡".repeat(81));
        assertInvalid("👨‍👩‍👧‍👦".repeat(23));
    }

    @Test
    void acceptsTextWithinBothLengthLimits() {
        assertThatCode(() -> validator.requireValid(canonicalizer.derive("洗澡后哄睡")))
                .doesNotThrowAnyException();
    }

    private void assertInvalid(String rawText) {
        assertThatThrownBy(() -> validator.requireValid(canonicalizer.derive(rawText)))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    org.assertj.core.api.Assertions.assertThat(contract.code())
                            .isEqualTo("invalid_custom_scene_text");
                });
    }
}
