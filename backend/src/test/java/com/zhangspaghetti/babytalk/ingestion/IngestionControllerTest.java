package com.zhangspaghetti.babytalk.ingestion;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import io.minio.MinioClient;
import io.minio.ObjectWriteResponse;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/**
 * IngestionController 集成测试 — MockMvc 测试 REST API 层。
 *
 * <p>EmbeddingModel 和 MinioClient 使用 @MockitoBean 替代，
 * 避免依赖真实的 OpenAI API 和 MinIO 服务。
 */
@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.0.0",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.provider-mode=dev"
})
@AutoConfigureMockMvc
class IngestionControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @MockitoBean
    private EmbeddingModel embeddingModel;

    @MockitoBean
    private MinioClient minioClient;

    @BeforeEach
    void cleanIngestionJobs() {
        jdbcTemplate.execute("DELETE FROM ingestion_jobs");
    }

    @Test
    void uploadReturns202WithJobId() throws Exception {
        // Mock MinIO putObject 成功
        when(minioClient.putObject(any())).thenReturn(
                new ObjectWriteResponse(null, "babytalk", null, "ingestion/test", null, null));

        MockMultipartFile file = new MockMultipartFile(
                "file", "test.txt", MediaType.TEXT_PLAIN_VALUE,
                "测试内容：宝宝语言发展".getBytes());

        mockMvc.perform(multipart("/api/v1/ingestion/upload")
                        .file(file)
                        .param("bookTitle", "Baby Talk"))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.jobId").isNotEmpty());
    }

    @Test
    void uploadEmptyFileReturnsBadRequest() throws Exception {
        MockMultipartFile emptyFile = new MockMultipartFile(
                "file", "empty.txt", MediaType.TEXT_PLAIN_VALUE,
                new byte[0]);

        mockMvc.perform(multipart("/api/v1/ingestion/upload")
                        .file(emptyFile)
                        .param("bookTitle", "Test Book"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("上传文件不能为空"));
    }

    @Test
    void getJobStatusReturns200ForExistingJob() throws Exception {
        // 直接插入一条 job 记录
        UUID jobId = UUID.randomUUID();
        Instant now = Instant.now();
        jdbcTemplate.update("""
                INSERT INTO ingestion_jobs (id, original_filename, minio_object_key, status,
                                            total_chunks, error_message, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                jobId, "test.pdf", "ingestion/abc/test.pdf",
                IngestionJob.STATUS_COMPLETED, 42, null,
                Timestamp.from(now), Timestamp.from(now));

        mockMvc.perform(get("/api/v1/ingestion/jobs/{id}", jobId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(jobId.toString()))
                .andExpect(jsonPath("$.originalFilename").value("test.pdf"))
                .andExpect(jsonPath("$.status").value("COMPLETED"))
                .andExpect(jsonPath("$.totalChunks").value(42));
    }

    @Test
    void getJobStatusReturns404ForNonExistentJob() throws Exception {
        mockMvc.perform(get("/api/v1/ingestion/jobs/{id}", UUID.randomUUID()))
                .andExpect(status().isNotFound());
    }

    @Test
    void retryJobReturns202ForFailedJob() throws Exception {
        UUID jobId = UUID.randomUUID();
        Instant now = Instant.now();
        jdbcTemplate.update("""
                INSERT INTO ingestion_jobs (id, original_filename, minio_object_key, status,
                                            total_chunks, error_message, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                jobId, "failed.pdf", "ingestion/def/failed.pdf",
                IngestionJob.STATUS_FAILED, 0, "Connection timeout",
                Timestamp.from(now), Timestamp.from(now));

        mockMvc.perform(post("/api/v1/ingestion/jobs/{id}/retry", jobId))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.jobId").value(jobId.toString()))
                .andExpect(jsonPath("$.message").value("重试已触发"));
    }

    @Test
    void retryJobReturns409ForNonFailedJob() throws Exception {
        UUID jobId = UUID.randomUUID();
        Instant now = Instant.now();
        jdbcTemplate.update("""
                INSERT INTO ingestion_jobs (id, original_filename, minio_object_key, status,
                                            total_chunks, error_message, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                jobId, "processing.pdf", "ingestion/ghi/processing.pdf",
                IngestionJob.STATUS_PROCESSING, 0, null,
                Timestamp.from(now), Timestamp.from(now));

        mockMvc.perform(post("/api/v1/ingestion/jobs/{id}/retry", jobId))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error").isNotEmpty());
    }

    @Test
    void retryJobReturns404ForNonExistentJob() throws Exception {
        mockMvc.perform(post("/api/v1/ingestion/jobs/{id}/retry", UUID.randomUUID()))
                .andExpect(status().isNotFound());
    }
}
