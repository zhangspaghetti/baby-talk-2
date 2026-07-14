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
}
