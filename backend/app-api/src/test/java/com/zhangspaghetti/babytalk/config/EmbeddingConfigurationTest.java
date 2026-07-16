package com.zhangspaghetti.babytalk.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

import java.time.Duration;
import java.util.Arrays;
import org.junit.jupiter.api.Test;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.ai.openai.OpenAiEmbeddingModel;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.jdbc.core.JdbcTemplate;

class EmbeddingConfigurationTest {

    private final EmbeddingConfiguration embeddingConfiguration = new EmbeddingConfiguration();
    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withUserConfiguration(EmbeddingConfiguration.class)
            .withBean(JdbcTemplate.class, () -> mock(JdbcTemplate.class));

    @Test
    void contextCreatesNativeOpenAiEmbeddingModelWithExplicitOptionsWithoutCallingProvider() {
        contextRunner.withPropertyValues(
                "app.embedding.mode=openai",
                "app.embedding.base-url=https://models.inference.ai.azure.com",
                "app.embedding.api-key=test-api-key",
                "app.embedding.model=text-embedding-3-small",
                "app.embedding.dimensions=1024"
        ).run(context -> {
            EmbeddingModel embeddingModel = context.getBean(EmbeddingModel.class);

            assertThat(embeddingModel).isInstanceOf(OpenAiEmbeddingModel.class);
            OpenAiEmbeddingModel nativeModel = (OpenAiEmbeddingModel) embeddingModel;
            assertThat(nativeModel.getOptions().getBaseUrl())
                    .isEqualTo("https://models.inference.ai.azure.com/v1");
            assertThat(nativeModel.getOptions().getApiKey()).isEqualTo("test-api-key");
            assertThat(nativeModel.getOptions().getModel()).isEqualTo("text-embedding-3-small");
            assertThat(nativeModel.getOptions().getTimeout()).isEqualTo(Duration.ofSeconds(60));
            assertThat(nativeModel.getOptions().getDimensions()).isEqualTo(1024);
        });
    }

    @Test
    void alreadyVersionedBaseUrlIsNotDuplicated() {
        contextRunner.withPropertyValues(
                "app.embedding.mode=openai",
                "app.embedding.base-url=https://router.example.com/api/v1/",
                "app.embedding.api-key=test-api-key",
                "app.embedding.model=text-embedding-3-small",
                "app.embedding.dimensions=1024"
        ).run(context -> {
            OpenAiEmbeddingModel model = context.getBean(OpenAiEmbeddingModel.class);

            assertThat(model.getOptions().getBaseUrl())
                    .isEqualTo("https://router.example.com/api/v1");
        });
    }

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
