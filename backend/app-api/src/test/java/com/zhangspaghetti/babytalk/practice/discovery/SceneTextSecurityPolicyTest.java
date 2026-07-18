package com.zhangspaghetti.babytalk.practice.discovery;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.web.ContractException;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class SceneTextSecurityPolicyTest {

    private final SceneTextCanonicalizer canonicalizer = new SceneTextCanonicalizer();
    private final SceneTextSecurityPolicy policy = new SceneTextSecurityPolicy(
            PracticeDiscoveryPolicyTestFixture.properties(),
            new PolicyTextMatcher(canonicalizer));

    @Test
    void rejectsBidiControlsWithSafe422ContractDetails() {
        var rawText = "宝宝\u202Eabc";

        assertThatThrownBy(() -> policy.requireSafe(canonicalizer.derive(rawText)))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY);
                    assertThat(contract.code()).isEqualTo("unsafe_custom_scene_text");
                    assertThat(contract.details()).containsEntry("reason", "bidi_control");
                    assertThat(contract.details().toString()).doesNotContain(rawText, "宝宝", "abc");
                });
    }

    @Test
    void catchesFullWidthAndConfusablePiiMarkers() {
        assertThatThrownBy(() -> policy.requireSafe(canonicalizer.derive("请加ＷｅＣｈａｔ联系")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> assertThat(((ContractException) error).code())
                        .isEqualTo("unsafe_custom_scene_text"));
        assertThatThrownBy(() -> policy.requireSafe(canonicalizer.derive("请加WeСhat联系")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> assertThat(((ContractException) error).code())
                        .isEqualTo("unsafe_custom_scene_text"));
    }

    @Test
    void allowsOrdinaryChineseEnglishCareScene() {
        assertThatCode(() -> policy.requireSafe(canonicalizer.derive("宝宝不想穿鞋，need a calm transition")))
                .doesNotThrowAnyException();
    }
}
