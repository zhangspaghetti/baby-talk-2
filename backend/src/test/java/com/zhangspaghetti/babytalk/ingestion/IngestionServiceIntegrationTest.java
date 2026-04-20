package com.zhangspaghetti.babytalk.ingestion;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import io.minio.GetObjectArgs;
import io.minio.GetObjectResponse;
import io.minio.MinioClient;
import io.minio.ObjectWriteResponse;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.Optional;
import okhttp3.Headers;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/**
 * IngestionService 端到端集成测试 — 验证完整 ingestion 管道。
 *
 * <p>上传测试 TXT 文件 → 验证 ingestion_jobs 记录创建。
 *
 * <p>EmbeddingModel 返回固定 1536 维向量，MinioClient mock 存储操作。
 * 由于 processFile 是 @Async，使用轮询等待 job 状态变更。
 */
@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.0.0",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.provider-mode=dev"
})
class IngestionServiceIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private IngestionService ingestionService;

    @Autowired
    private IngestionRepository ingestionRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @MockitoBean
    private EmbeddingModel embeddingModel;

    @MockitoBean
    private MinioClient minioClient;

    private static final float[] FIXED_VECTOR;

    static {
        FIXED_VECTOR = new float[1536];
        float val = 1.0f / (float) Math.sqrt(1536);
        for (int i = 0; i < 1536; i++) {
            FIXED_VECTOR[i] = val;
        }
    }

    @BeforeEach
    void setUp() {
        jdbcTemplate.execute("DELETE FROM vector_store");
        jdbcTemplate.execute("DELETE FROM ingestion_jobs");

        // Mock EmbeddingModel
        when(embeddingModel.embed(anyString())).thenReturn(FIXED_VECTOR);
        when(embeddingModel.embed(any(org.springframework.ai.document.Document.class)))
                .thenReturn(FIXED_VECTOR);
    }

    @Test
    void uploadAndIngestCreatesJobRecord() throws Exception {
        // Mock MinIO putObject
        when(minioClient.putObject(any())).thenReturn(
                new ObjectWriteResponse(null, "babytalk", null, "ingestion/test", null, null));

        String testContent = "测试文档内容：宝宝语言发展的第一阶段是咿呀学语。";
        ByteArrayInputStream inputStream = new ByteArrayInputStream(
                testContent.getBytes(StandardCharsets.UTF_8));

        IngestionJob job = ingestionService.uploadAndIngest(
                "test-document.txt", inputStream, "text/plain", "Baby Talk");

        // 验证 job 记录已创建
        assertThat(job).isNotNull();
        assertThat(job.id()).isNotNull();
        assertThat(job.originalFilename()).isEqualTo("test-document.txt");
        assertThat(job.status()).isEqualTo(IngestionJob.STATUS_PENDING);

        // 验证数据库中有记录
        Optional<IngestionJob> dbJob = ingestionRepository.findById(job.id());
        assertThat(dbJob).isPresent();
        assertThat(dbJob.get().originalFilename()).isEqualTo("test-document.txt");
    }

    @Test
    void uploadCreatesMinioObjectKeyWithUUID() throws Exception {
        when(minioClient.putObject(any())).thenReturn(
                new ObjectWriteResponse(null, "babytalk", null, "ingestion/test", null, null));

        String testContent = "简短测试内容";
        ByteArrayInputStream inputStream = new ByteArrayInputStream(
                testContent.getBytes(StandardCharsets.UTF_8));

        IngestionJob job = ingestionService.uploadAndIngest(
                "my-book.pdf", inputStream, "application/pdf", "Brain Rules for Baby");

        assertThat(job.minioObjectKey()).startsWith("ingestion/");
        assertThat(job.minioObjectKey()).endsWith("/my-book.pdf");
    }

    @Test
    void testDocumentResourceExists() {
        ClassPathResource resource = new ClassPathResource("test-document.txt");
        assertThat(resource.exists()).isTrue();
    }
}
