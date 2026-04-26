package com.zhangspaghetti.babytalk.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.Arrays;
import org.junit.jupiter.api.Test;
import org.springframework.ai.embedding.EmbeddingModel;

class EmbeddingConfigurationTest {

    private final EmbeddingConfiguration embeddingConfiguration = new EmbeddingConfiguration();

    @Test
    void openAiModeRejectsComposePlaceholderKey() {
        assertThatThrownBy(() -> embeddingConfiguration.embeddingModel(new EmbeddingProperties(
                EmbeddingProperties.Mode.OPENAI,
                "https://models.inference.ai.azure.com",
                "dev-placeholder-key",
                "text-embedding-3-small",
                1536
        )))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("placeholder key");
    }

    @Test
    void devHashModeReturnsDeterministicVectors() {
        EmbeddingModel embeddingModel = embeddingConfiguration.embeddingModel(new EmbeddingProperties(
                EmbeddingProperties.Mode.DEV_HASH,
                "",
                "",
                "dev-hash-v1",
                32
        ));

        float[] first = embeddingModel.embed("语言发展需要重复和回应");
        float[] second = embeddingModel.embed("语言发展需要重复和回应");
        float[] third = embeddingModel.embed("完全不同的文本");

        assertThat(embeddingModel.dimensions()).isEqualTo(32);
        assertThat(Arrays.equals(first, second)).isTrue();
        assertThat(Arrays.equals(first, third)).isFalse();
    }
}
