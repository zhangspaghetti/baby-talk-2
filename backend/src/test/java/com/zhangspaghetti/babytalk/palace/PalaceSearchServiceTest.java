package com.zhangspaghetti.babytalk.palace;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import io.minio.MinioClient;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.ai.document.Document;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/**
 * PalaceSearchService 集成测试 — 验证按宫殿坐标过滤的向量检索。
 *
 * <p>直接用 JdbcTemplate INSERT vector_store 带不同 wing 的记录，
 * 然后调用 PalaceSearchService.search(wing=X) 验证只返回匹配 wing 的结果。
 *
 * <p>EmbeddingModel 使用 @MockitoBean 返回固定 1536 维向量，
 * MinioClient 也 mock 以避免连接真实 MinIO。
 */
@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.0.0",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.provider-mode=dev"
})
class PalaceSearchServiceTest extends AbstractIntegrationTest {

    @Autowired
    private PalaceSearchService palaceSearchService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @MockitoBean
    private EmbeddingModel embeddingModel;

    @MockitoBean
    private MinioClient minioClient;

    /** 固定 1536 维查询向量 — 所有元素相同以确保与存储向量的高余弦相似度 */
    private static final float[] FIXED_QUERY_VECTOR;

    static {
        FIXED_QUERY_VECTOR = new float[1536];
        float val = 1.0f / (float) Math.sqrt(1536);
        for (int i = 0; i < 1536; i++) {
            FIXED_QUERY_VECTOR[i] = val;
        }
    }

    @BeforeEach
    void setUp() {
        // 清空 vector_store
        jdbcTemplate.execute("DELETE FROM vector_store");

        // Mock EmbeddingModel：embed(String) 返回固定 1536 维向量
        when(embeddingModel.embed(anyString())).thenReturn(FIXED_QUERY_VECTOR);
    }

    @Test
    void searchWithWingFilterReturnsOnlyMatchingWing() {
        // 插入 3 条记录：2 条 wing=language_development，1 条 wing=cognitive
        insertVectorRecord("语言发展内容一", "language_development", "early_communication");
        insertVectorRecord("语言发展内容二", "language_development", "vocabulary_building");
        insertVectorRecord("认知发展内容", "cognitive", "brain_science");

        List<Document> results = palaceSearchService.search(
                "语言发展", "language_development", null, 10);

        assertThat(results).hasSize(2);
        assertThat(results).allSatisfy(doc -> {
            assertThat(doc.getMetadata().get("wing")).isEqualTo("language_development");
        });
    }

    @Test
    void searchWithWingAndRoomFilterReturnsNarrowedResults() {
        insertVectorRecord("早期沟通内容", "language_development", "early_communication");
        insertVectorRecord("词汇构建内容", "language_development", "vocabulary_building");
        insertVectorRecord("认知内容", "cognitive", "brain_science");

        List<Document> results = palaceSearchService.search(
                "沟通", "language_development", "early_communication", 10);

        assertThat(results).hasSize(1);
        assertThat(results.get(0).getMetadata().get("wing")).isEqualTo("language_development");
        assertThat(results.get(0).getMetadata().get("room")).isEqualTo("early_communication");
    }

    @Test
    void searchWithoutFilterReturnsAllResults() {
        insertVectorRecord("内容A", "language_development", "early_communication");
        insertVectorRecord("内容B", "cognitive", "brain_science");
        insertVectorRecord("内容C", "emotional", "attachment_bonding");

        List<Document> results = palaceSearchService.search("内容", null, null, 10);

        assertThat(results).hasSize(3);
    }

    @Test
    void searchRespectsTopK() {
        for (int i = 0; i < 5; i++) {
            insertVectorRecord("内容" + i, "language_development", "early_communication");
        }

        List<Document> results = palaceSearchService.search(
                "语言", "language_development", null, 3);

        assertThat(results).hasSizeLessThanOrEqualTo(3);
    }

    @Test
    void buildFilterExpressionWithWingOnly() {
        String expr = palaceSearchService.buildFilterExpression("LANGUAGE_DEVELOPMENT", null);
        assertThat(expr).isEqualTo("wing == 'language_development'");
    }

    @Test
    void buildFilterExpressionWithWingAndRoom() {
        String expr = palaceSearchService.buildFilterExpression("LANGUAGE_DEVELOPMENT", "EARLY_COMMUNICATION");
        assertThat(expr).isEqualTo("wing == 'language_development' && room == 'early_communication'");
    }

    @Test
    void buildFilterExpressionWithNoFilters() {
        String expr = palaceSearchService.buildFilterExpression(null, null);
        assertThat(expr).isNull();

        expr = palaceSearchService.buildFilterExpression("", "");
        assertThat(expr).isNull();
    }

    /**
     * 直接向 vector_store 插入测试记录。
     * 使用与查询向量相同的固定向量，确保余弦相似度 ≈ 1.0。
     */
    private void insertVectorRecord(String content, String wing, String room) {
        UUID id = UUID.randomUUID();
        String metadata = String.format(
                "{\"wing\":\"%s\",\"room\":\"%s\",\"source_book\":\"test\"}", wing, room);
        String vectorLiteral = buildVectorLiteral(FIXED_QUERY_VECTOR);

        jdbcTemplate.update(
                "INSERT INTO vector_store (id, content, metadata, embedding) VALUES (?::uuid, ?, ?::jsonb, ?::vector)",
                id.toString(), content, metadata, vectorLiteral);
    }

    /** 构建 pgvector 字面量字符串：[0.025,0.025,...] */
    private static String buildVectorLiteral(float[] vector) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < vector.length; i++) {
            if (i > 0) sb.append(",");
            sb.append(vector[i]);
        }
        sb.append("]");
        return sb.toString();
    }
}
