package com.zhangspaghetti.babytalk.practice.discovery;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class SceneTextCanonicalizerTest {

    private final SceneTextCanonicalizer canonicalizer = new SceneTextCanonicalizer();

    @Test
    void canonicalizesCompatibilityCharactersAndWhitespace() {
        assertThat(canonicalizer.canonicalize("  宝宝　　不肯\n穿鞋  "))
                .isEqualTo("宝宝 不肯 穿鞋");
        assertThat(canonicalizer.canonicalize("ＡＢＣ１２３"))
                .isEqualTo("ABC123");
    }

    @Test
    void equivalentSceneTextHasOneCanonicalRepresentation() {
        assertThat(canonicalizer.canonicalize("宝宝不肯穿鞋"))
                .isEqualTo(canonicalizer.canonicalize("  宝宝不肯穿鞋  "));
        assertThat(canonicalizer.canonicalize("宝宝  不肯穿鞋"))
                .isEqualTo(canonicalizer.canonicalize("宝宝　不肯穿鞋"));
    }

    @Test
    void canonicalizesUnicodeControlWhitespace() {
        assertThat(canonicalizer.canonicalize("宝宝\u0085不肯\u0085穿鞋"))
                .isEqualTo("宝宝 不肯 穿鞋");
    }

    @Test
    void exposesGraphemeAndDatabaseCodePointLengthsSeparately() {
        var family = "👨‍👩‍👧‍👦".repeat(80);
        assertThat(canonicalizer.graphemeLength(family)).isEqualTo(80);
        assertThat(canonicalizer.codePointLength(family)).isGreaterThan(160);
    }

    @Test
    void treatsEmojiZwjSequenceAsOneExtendedGrapheme() {
        assertThat(canonicalizer.graphemeLength("👨‍👩‍👧‍👦")).isEqualTo(1);
    }

    @Test
    void derivesReadableDisplayAndNfkcCasefoldSecurityText() {
        var forms = canonicalizer.derive("  ＷｅＣｈａｔ\uFEFF  宝宝  ");

        assertThat(forms.displayText()).isEqualTo("WeChat 宝宝");
        assertThat(forms.securityText()).isEqualTo("wechat 宝宝");
        assertThat(forms.riskSignals().removedInvisible()).isTrue();
    }

    @Test
    void preservesEmojiZwjButRejectsBidiOverrideAndIsolateSignals() {
        var emoji = canonicalizer.derive("爸爸👨‍👩‍👧‍👦抱抱宝宝");
        assertThat(emoji.displayText()).contains("👨‍👩‍👧‍👦");
        assertThat(emoji.riskSignals().bidiControlPresent()).isFalse();

        assertThat(canonicalizer.derive("宝宝\u202Eabc").riskSignals().bidiControlPresent()).isTrue();
        assertThat(canonicalizer.derive("宝宝\u2066abc\u2069").riskSignals().bidiControlPresent()).isTrue();
    }

    @Test
    void reportsMixedDigitSystemsOnlyWhenTheyFormOneSensitiveRun() {
        assertThat(canonicalizer.derive("第２次洗澡").riskSignals().mixedDigitSystems()).isFalse();
        assertThat(canonicalizer.derive("电话１２345678901").riskSignals().mixedDigitSystems()).isTrue();
        assertThat(canonicalizer.derive("电话１２345678901").riskSignals().longDigitRun()).isTrue();
    }
}
