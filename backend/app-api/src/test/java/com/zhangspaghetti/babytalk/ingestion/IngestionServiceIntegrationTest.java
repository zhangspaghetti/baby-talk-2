package com.zhangspaghetti.babytalk.ingestion;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import io.minio.GetObjectResponse;
import io.minio.MinioClient;
import io.minio.ObjectWriteResponse;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import okhttp3.Headers;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/**
 * IngestionService 集成测试 — 验证 shared runtime + deterministic dev embedding mode。
 */
@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.0.0",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.provider-mode=dev",
        "app.embedding.mode=dev-hash"
})
class IngestionServiceIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private IngestionService ingestionService;

    @Autowired
    private IngestionRepository ingestionRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @MockitoBean
    private MinioClient minioClient;

    @BeforeEach
    void setUp() {
        jdbcTemplate.execute("DELETE FROM vector_store");
        jdbcTemplate.execute("DELETE FROM ingestion_jobs");
    }

    @Test
    void uploadAndIngestCompletesAndWritesChunksInDevHashMode() throws Exception {
        byte[] trackedPdf = trackedPdfBytes();
        stubPutObjectSuccess();
        when(minioClient.getObject(any())).thenReturn(getObjectResponse(trackedPdf));

        IngestionJob job = ingestionService.uploadAndIngest(
                "knowledge-upload.pdf",
                new ByteArrayInputStream(trackedPdf),
                "application/pdf",
                "Baby Talk");

        IngestionJob completedJob = awaitJobStatus(job.id(), IngestionJob.STATUS_COMPLETED);
        Integer vectorRows = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM vector_store", Integer.class);

        assertThat(completedJob.totalChunks()).isGreaterThan(0);
        assertThat(completedJob.errorMessage()).isNull();
        assertThat(vectorRows).isNotNull();
        assertThat(vectorRows).isGreaterThan(0);
    }

    @Test
    void uploadAndIngestMarksFailedWhenParsedDocumentHasZeroChars() throws Exception {
        stubPutObjectSuccess();
        when(minioClient.getObject(any())).thenReturn(getObjectResponse(new byte[0]));

        IngestionJob job = ingestionService.uploadAndIngest(
                "empty.txt",
                new ByteArrayInputStream(new byte[0]),
                "text/plain",
                "");

        IngestionJob failedJob = awaitJobStatus(job.id(), IngestionJob.STATUS_FAILED);
        assertThat(failedJob.errorMessage()).contains("PARSE").contains("0 字符");
    }

    @Test
    void retryFailedJobAllowsSecondAttemptToReachCompleted() throws Exception {
        byte[] trackedPdf = trackedPdfBytes();
        stubPutObjectSuccess();
        when(minioClient.getObject(any()))
                .thenReturn(getObjectResponse(new byte[0]))
                .thenReturn(getObjectResponse(trackedPdf));

        IngestionJob job = ingestionService.uploadAndIngest(
                "retryable.pdf",
                new ByteArrayInputStream(trackedPdf),
                "application/pdf",
                "Retry Book");

        IngestionJob failedJob = awaitJobStatus(job.id(), IngestionJob.STATUS_FAILED);
        assertThat(failedJob.errorMessage()).contains("PARSE");

        ingestionService.retryFailedJob(job.id(), "Retry Book");

        IngestionJob completedJob = awaitJobStatus(job.id(), IngestionJob.STATUS_COMPLETED);
        assertThat(completedJob.totalChunks()).isGreaterThan(0);
        assertThat(completedJob.errorMessage()).isNull();
    }

    @Test
    void uploadFailureMarksJobFailedAndRetainsDiagnostic() throws Exception {
        when(minioClient.putObject(any())).thenThrow(new RuntimeException("minio down"));

        assertThatThrownBy(() -> ingestionService.uploadAndIngest(
                "broken.txt",
                new ByteArrayInputStream("内容".getBytes(StandardCharsets.UTF_8)),
                "text/plain",
                "Broken Book"))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("MinIO 上传失败");

        IngestionJob failedJob = ingestionRepository.findAll().get(0);
        assertThat(failedJob.status()).isEqualTo(IngestionJob.STATUS_FAILED);
        assertThat(failedJob.errorMessage()).contains("UPLOAD").contains("minio down");
    }

    private void stubPutObjectSuccess() throws Exception {
        when(minioClient.putObject(any())).thenReturn(
                new ObjectWriteResponse(null, "babytalk", null, "ingestion/test", null, null));
    }

    private GetObjectResponse getObjectResponse(byte[] payload) {
        return new GetObjectResponse(
                Headers.of(),
                "test-bucket",
                null,
                "ingestion/test",
                new ByteArrayInputStream(payload)
        );
    }

    private IngestionJob awaitJobStatus(java.util.UUID jobId, String expectedStatus) throws InterruptedException {
        long deadline = System.currentTimeMillis() + 10_000L;
        while (System.currentTimeMillis() < deadline) {
            IngestionJob job = ingestionRepository.findById(jobId).orElseThrow();
            if (expectedStatus.equals(job.status())) {
                return job;
            }
            Thread.sleep(100L);
        }
        IngestionJob lastSeen = ingestionRepository.findById(jobId).orElseThrow();
        throw new AssertionError("Timed out waiting for job %s to reach %s; last status=%s"
                .formatted(jobId, expectedStatus, lastSeen.status()));
    }

    private byte[] trackedPdfBytes() throws Exception {
        try (var inputStream = new ClassPathResource("knowledge-upload.pdf").getInputStream()) {
            return inputStream.readAllBytes();
        }
    }
}
