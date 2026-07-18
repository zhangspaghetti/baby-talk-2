package com.zhangspaghetti.babytalk.practice.discovery;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.ibm.icu.text.SpoofChecker;
import com.zhangspaghetti.babytalk.web.ContractException;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.http.HttpStatus;
import org.springframework.test.util.ReflectionTestUtils;

class SceneTextSecurityPolicyTest {

    private final SceneTextCanonicalizer canonicalizer = new SceneTextCanonicalizer();
    private final SceneTextSecurityPolicy policy = new SceneTextSecurityPolicy(
            PracticeDiscoveryPolicyTestFixture.properties(),
            new PolicyTextMatcher(canonicalizer),
            new SpoofChecker.Builder().build());

    @Test
    void springProductionWiringInjectsConfiguredSpoofChecker() {
        try (var context = new AnnotationConfigApplicationContext()) {
            context.register(SceneTextSecurityConfiguration.class, SceneTextCanonicalizer.class,
                    PolicyTextMatcher.class, SceneTextSecurityPolicy.class);
            context.registerBean(PracticeDiscoveryPolicyProperties.class,
                    PracticeDiscoveryPolicyTestFixture::properties);
            context.refresh();

            var configuredSpoofChecker = context.getBean(SpoofChecker.class);
            var wiredPolicy = context.getBean(SceneTextSecurityPolicy.class);

            assertThat(ReflectionTestUtils.getField(wiredPolicy, "spoofChecker"))
                    .isSameAs(configuredSpoofChecker);
        }
    }

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
