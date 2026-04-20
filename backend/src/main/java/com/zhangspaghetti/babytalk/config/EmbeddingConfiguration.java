package com.zhangspaghetti.babytalk.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.document.MetadataMode;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.ai.openai.OpenAiEmbeddingModel;
import org.springframework.ai.openai.OpenAiEmbeddingOptions;
import org.springframework.ai.openai.api.OpenAiApi;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.ai.vectorstore.pgvector.PgVectorStore;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * 手动构建 EmbeddingModel + PgVectorStore bean。
 * 所有 Spring AI 自动配置已排除（OpenAiEmbeddingAutoConfiguration、PgVectorStoreAutoConfiguration），
 * 因此需要手动配置 embedding 管道。
 *
 * <p>PgVectorStore 设置 initializeSchema=false，因为 V10 迁移已创建 vector_store 表。
 */
@Configuration
@EnableConfigurationProperties(EmbeddingProperties.class)
public class EmbeddingConfiguration {

    private static final Logger log = LoggerFactory.getLogger(EmbeddingConfiguration.class);

    @Bean
    public EmbeddingModel embeddingModel(EmbeddingProperties properties) {
        log.info("初始化 EmbeddingModel: model={}, dimensions={}, baseUrl={}",
                properties.model(), properties.dimensions(), properties.baseUrl());

        var openAiApi = OpenAiApi.builder()
                .baseUrl(properties.baseUrl())
                .apiKey(properties.apiKey())
                .build();

        return new OpenAiEmbeddingModel(
                openAiApi,
                MetadataMode.EMBED,
                OpenAiEmbeddingOptions.builder()
                        .model(properties.model())
                        .dimensions(properties.dimensions())
                        .build()
        );
    }

    @Bean
    public VectorStore vectorStore(JdbcTemplate jdbcTemplate, EmbeddingModel embeddingModel,
                                   EmbeddingProperties properties) {
        log.info("初始化 PgVectorStore: initializeSchema=false, dimensions={}",
                properties.dimensions());

        return PgVectorStore.builder(jdbcTemplate, embeddingModel)
                .dimensions(properties.dimensions())
                .initializeSchema(false)
                .build();
    }
}
