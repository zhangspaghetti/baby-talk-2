package com.zhangspaghetti.babytalk.practice.discovery;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;

class PolicyTextMatcherTest {

    private final PolicyTextMatcher matcher =
            new PolicyTextMatcher(new SceneTextCanonicalizer());

    @Test
    void latinMarkersUseWordBoundaries() {
        assertThat(matcher.containsAny("Let's test the water.", List.of("test"))).isTrue();
        assertThat(matcher.containsAny("A useful skill.", List.of("kill"))).isFalse();
        assertThat(matcher.containsAny("Take a quiz.", List.of("quiz"))).isTrue();
    }

    @Test
    void cjkMarkersMatchPhrasesWithoutSingleCharacterFalsePositives() {
        assertThat(matcher.containsAny("注意安全性。", List.of("性行为", "色情内容"))).isFalse();
        assertThat(matcher.containsAny("内容涉及色情内容。", List.of("性行为", "色情内容"))).isTrue();
    }

    @Test
    void matchingUsesTheSameNfkcNormalizationAsPersistence() {
        assertThat(matcher.containsAny("ＷＥＣＨＡＴ abc", List.of("wechat"))).isTrue();
    }
}
