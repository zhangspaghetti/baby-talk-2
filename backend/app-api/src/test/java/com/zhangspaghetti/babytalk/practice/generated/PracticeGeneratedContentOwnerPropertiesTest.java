package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class PracticeGeneratedContentOwnerPropertiesTest {

    @Test
    void trimsCurrentVersionAndSecret() {
        var properties = new PracticeGeneratedContentOwnerProperties(" v1 ", " secret-value ");

        assertThat(properties.keyVersion()).isEqualTo("v1");
        assertThat(properties.keySecret()).isEqualTo("secret-value");
    }

    @Test
    void blankCurrentVersionFailsFast() {
        assertThatThrownBy(() -> new PracticeGeneratedContentOwnerProperties(" ", "secret"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("key version");
    }

    @Test
    void currentVersionLongerThanDatabaseColumnFailsFast() {
        assertThatThrownBy(() -> new PracticeGeneratedContentOwnerProperties("v".repeat(33), "secret"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("32");
    }
}
