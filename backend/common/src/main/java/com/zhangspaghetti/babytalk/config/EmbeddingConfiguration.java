package com.zhangspaghetti.babytalk.config;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.document.Document;
import org.springframework.ai.document.MetadataMode;
import org.springframework.ai.embedding.Embedding;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.ai.embedding.EmbeddingRequest;
import org.springframework.ai.embedding.EmbeddingResponse;
import org.springframework.ai.openai.OpenAiEmbeddingModel;
import org.springframework.ai.openai.OpenAiEmbeddingOptions;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.ai.vectorstore.pgvector.PgVectorStore;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * 手动构建 EmbeddingModel + PgVectorStore bean。
 */
@Configuration
@EnableConfigurationProperties(EmbeddingProperties.class)
public class EmbeddingConfiguration {

    private static final Logger log = LoggerFactory.getLogger(EmbeddingConfiguration.class);
    private static final String DEV_PLACEHOLDER_KEY = "dev-placeholder-key";

    @Bean
    public EmbeddingModel embeddingModel(EmbeddingProperties properties) {
        log.info("初始化 EmbeddingModel: mode={}, model={}, dimensions={}",
                properties.mode(), properties.model(), properties.dimensions());

        if (properties.usesDevHashMode()) {
            log.warn("EmbeddingModel 使用 deterministic dev hash mode；仅用于 local/compose 演示与测试。model={}",
                    properties.model());
            return new DeterministicHashEmbeddingModel(properties.dimensions());
        }

        if (DEV_PLACEHOLDER_KEY.equals(properties.apiKey())) {
            throw new IllegalStateException(
                    "app.embedding.mode=openai 但仍在使用 compose placeholder key；请显式切到 dev-hash mode 或提供真实密钥");
        }

        return OpenAiEmbeddingModel.builder()
                .options(OpenAiEmbeddingOptions.builder()
                        .baseUrl(OpenAiV1BaseUrl.fromProviderRoot(properties.baseUrl()))
                        .apiKey(properties.apiKey())
                        .model(properties.model())
                        .timeout(Duration.ofSeconds(60))
                        .dimensions(properties.dimensions())
                        .build())
                .metadataMode(MetadataMode.EMBED)
                .build();
    }

    @Bean
    public VectorStore vectorStore(JdbcTemplate jdbcTemplate, EmbeddingModel embeddingModel,
                                   EmbeddingProperties properties) {
        log.info("初始化 PgVectorStore: initializeSchema=false, dimensions={}, embeddingMode={}",
                properties.dimensions(), properties.mode());

        return PgVectorStore.builder(jdbcTemplate, embeddingModel)
                .dimensions(properties.dimensions())
                .initializeSchema(false)
                .build();
    }

    private static final class DeterministicHashEmbeddingModel implements EmbeddingModel {

        private final int dimensions;

        private DeterministicHashEmbeddingModel(int dimensions) {
            this.dimensions = dimensions;
        }

        @Override
        public EmbeddingResponse call(EmbeddingRequest request) {
            List<String> instructions = request.getInstructions();
            List<Embedding> embeddings = new ArrayList<>(instructions.size());
            for (int index = 0; index < instructions.size(); index++) {
                embeddings.add(new Embedding(embedText(instructions.get(index)), index));
            }
            return new EmbeddingResponse(embeddings);
        }

        @Override
        public float[] embed(Document document) {
            return embedText(getEmbeddingContent(document));
        }

        @Override
        public int dimensions() {
            return dimensions;
        }

        private float[] embedText(String text) {
            String normalized = (text == null || text.isBlank()) ? "[empty]" : text.trim();
            byte[] bytes = normalized.getBytes(StandardCharsets.UTF_8);
            float[] vector = new float[dimensions];
            for (int index = 0; index < bytes.length; index++) {
                int unsigned = Byte.toUnsignedInt(bytes[index]);
                int primaryBucket = Math.floorMod((unsigned * 31) + index, dimensions);
                int secondaryBucket = Math.floorMod((unsigned * 131) + (index * 17), dimensions);
                vector[primaryBucket] += 1.0f;
                vector[secondaryBucket] -= 0.35f;
            }
            if (bytes.length == 0) {
                vector[0] = 1.0f;
            }
            normalize(vector);
            return vector;
        }

        private void normalize(float[] vector) {
            double norm = 0.0d;
            for (float value : vector) {
                norm += value * value;
            }
            if (norm == 0.0d) {
                vector[0] = 1.0f;
                return;
            }
            float scale = (float) (1.0d / Math.sqrt(norm));
            for (int index = 0; index < vector.length; index++) {
                vector[index] = vector[index] * scale;
            }
        }
    }
}
