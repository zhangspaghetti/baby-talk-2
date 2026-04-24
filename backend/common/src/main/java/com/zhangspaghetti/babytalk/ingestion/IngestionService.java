package com.zhangspaghetti.babytalk.ingestion;

import com.zhangspaghetti.babytalk.config.MinioProperties;
import com.zhangspaghetti.babytalk.palace.MemPalaceMetadataEnricher;
import io.minio.GetObjectArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import java.io.InputStream;
import java.time.Duration;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;
import java.util.concurrent.Executor;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.document.Document;
import org.springframework.ai.reader.tika.TikaDocumentReader;
import org.springframework.ai.transformer.splitter.TokenTextSplitter;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.InputStreamResource;
import org.springframework.stereotype.Service;

/**
 * Ingestion 管道核心编排 — MinIO upload + async parse/split/embed/store。
 */
@Service
public class IngestionService {

    private static final Logger log = LoggerFactory.getLogger(IngestionService.class);
    private static final String PHASE_UPLOAD = "UPLOAD";
    private static final String PHASE_DISPATCH = "DISPATCH";
    private static final String PHASE_DOWNLOAD = "DOWNLOAD";
    private static final String PHASE_PARSE = "PARSE";
    private static final String PHASE_SPLIT = "SPLIT";
    private static final String PHASE_VECTOR_STORE = "VECTOR_STORE";
    private static final String PHASE_TIMEOUT = "TIMEOUT";

    private final MinioClient minioClient;
    private final MinioProperties minioProperties;
    private final IngestionRepository repository;
    private final VectorStore vectorStore;
    private final MemPalaceMetadataEnricher metadataEnricher;
    private final TokenTextSplitter tokenTextSplitter;
    private final Executor ingestionExecutor;
    private final Duration processingTimeout;

    public IngestionService(MinioClient minioClient,
                            MinioProperties minioProperties,
                            IngestionRepository repository,
                            VectorStore vectorStore,
                            @Qualifier("ingestionExecutor") Executor ingestionExecutor,
                            @Value("${app.ingestion.processing-timeout:PT90S}") Duration processingTimeout) {
        this.minioClient = minioClient;
        this.minioProperties = minioProperties;
        this.repository = repository;
        this.vectorStore = vectorStore;
        this.metadataEnricher = new MemPalaceMetadataEnricher();
        this.tokenTextSplitter = TokenTextSplitter.builder()
                .withChunkSize(800)
                .withMinChunkSizeChars(350)
                .withMinChunkLengthToEmbed(5)
                .withMaxNumChunks(10000)
                .build();
        this.ingestionExecutor = ingestionExecutor;
        this.processingTimeout = processingTimeout;
    }

    public IngestionJob uploadAndIngest(String filename, InputStream inputStream,
                                        String contentType, String bookTitle) {
        String safeFilename = sanitizeFilename(filename);
        String objectKey = "ingestion/" + UUID.randomUUID() + "/" + safeFilename;
        IngestionJob job = IngestionJob.pending(safeFilename, objectKey);
        repository.insert(job);
        log.info("Ingestion job 已创建: jobId={}, phase=PENDING, filename={}", job.id(), safeFilename);

        try {
            minioClient.putObject(
                    PutObjectArgs.builder()
                            .bucket(minioProperties.bucketName())
                            .object(objectKey)
                            .stream(inputStream, -1, 10485760)
                            .contentType(contentType != null ? contentType : "application/octet-stream")
                            .build()
            );
            log.info("Ingestion 上传完成: jobId={}, phase={}, bucket={}, objectKey={}",
                    job.id(), PHASE_UPLOAD, minioProperties.bucketName(), objectKey);
        } catch (Exception exception) {
            String errorMessage = terminalError(PHASE_UPLOAD, exception);
            repository.updateFailed(job.id(), errorMessage);
            log.warn("Ingestion 上传失败: jobId={}, phase={}, errorMessage={}",
                    job.id(), PHASE_UPLOAD, errorMessage, exception);
            throw new IngestionDispatchException(job.id(), errorMessage, exception);
        }

        dispatchProcessing(job.id(), objectKey, bookTitle);
        return job;
    }

    public IngestionJob retryFailedJob(UUID jobId, String bookTitle) {
        IngestionJob job = repository.findById(jobId)
                .orElseThrow(() -> new IllegalArgumentException("ingestion job 不存在: " + jobId));
        if (!IngestionJob.STATUS_FAILED.equals(job.status())) {
            throw new IllegalStateException("只能重试 FAILED 状态的 job，当前状态: " + job.status());
        }

        repository.updateStatusPending(jobId);
        log.info("Ingestion job 已重置为待处理: jobId={}, previousErrorMessage={}",
                jobId, job.errorMessage());
        dispatchProcessing(jobId, job.minioObjectKey(), bookTitle);
        return repository.findById(jobId).orElse(job);
    }

    private void dispatchProcessing(UUID jobId, String objectKey, String bookTitle) {
        try {
            CompletableFuture.supplyAsync(() -> processFile(jobId, objectKey, bookTitle), ingestionExecutor)
                    .orTimeout(processingTimeout.toMillis(), TimeUnit.MILLISECONDS)
                    .whenComplete((outcome, throwable) -> completeProcessing(jobId, throwable, outcome));
            log.info("Ingestion 任务已入队: jobId={}, phase={}, timeoutMs={}",
                    jobId, PHASE_DISPATCH, processingTimeout.toMillis());
        } catch (RejectedExecutionException exception) {
            String errorMessage = terminalError(PHASE_DISPATCH, exception);
            repository.updateFailed(jobId, errorMessage);
            log.error("Ingestion 任务入队失败: jobId={}, phase={}, errorMessage={}",
                    jobId, PHASE_DISPATCH, errorMessage, exception);
        }
    }

    private void completeProcessing(UUID jobId, Throwable throwable, ProcessingOutcome outcome) {
        if (throwable == null) {
            repository.updateCompleted(jobId, outcome.totalChunks());
            log.info("Ingestion job 完成: jobId={}, phase=COMPLETED, totalChunks={}",
                    jobId, outcome.totalChunks());
            return;
        }

        Throwable failure = unwrap(throwable);
        String errorMessage = terminalError(resolvePhase(failure), failure);
        repository.updateFailed(jobId, errorMessage);
        log.error("Ingestion job 失败: jobId={}, phase={}, errorMessage={}",
                jobId, resolvePhase(failure), errorMessage, failure);
    }

    private ProcessingOutcome processFile(UUID jobId, String objectKey, String bookTitle) {
        repository.updateStatusProcessing(jobId);
        log.info("Ingestion 开始处理: jobId={}, phase=PROCESSING, objectKey={}", jobId, objectKey);

        try (InputStream objectStream = downloadObject(jobId, objectKey)) {
            List<Document> documents = readDocuments(jobId, objectStream, objectKey);
            long totalChars = documents.stream()
                    .mapToLong(document -> document.getText() != null ? document.getText().length() : 0)
                    .sum();
            if (totalChars == 0) {
                throw new IngestionProcessingException(
                        PHASE_PARSE,
                        "文档解析结果为 0 字符（可能是空文件或不支持的格式）"
                );
            }

            for (Document document : documents) {
                document.getMetadata().put("source_book", bookTitle != null ? bookTitle : "");
            }

            List<Document> chunks = tokenTextSplitter.apply(documents);
            if (chunks.isEmpty()) {
                throw new IngestionProcessingException(PHASE_SPLIT, "文档分块结果为空");
            }
            log.info("Ingestion 分块完成: jobId={}, phase={}, totalChunks={}", jobId, PHASE_SPLIT, chunks.size());

            List<Document> enrichedChunks = metadataEnricher.apply(chunks);
            try {
                vectorStore.add(enrichedChunks);
            } catch (Exception exception) {
                throw new IngestionProcessingException(PHASE_VECTOR_STORE, exception.getMessage(), exception);
            }
            log.info("Ingestion 向量写入完成: jobId={}, phase={}, totalChunks={}",
                    jobId, PHASE_VECTOR_STORE, enrichedChunks.size());

            return new ProcessingOutcome(enrichedChunks.size());
        } catch (IngestionProcessingException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new IngestionProcessingException(PHASE_DOWNLOAD, exception.getMessage(), exception);
        }
    }

    private InputStream downloadObject(UUID jobId, String objectKey) {
        try {
            InputStream objectStream = minioClient.getObject(
                    GetObjectArgs.builder()
                            .bucket(minioProperties.bucketName())
                            .object(objectKey)
                            .build());
            log.info("Ingestion 对象下载完成: jobId={}, phase={}, objectKey={}", jobId, PHASE_DOWNLOAD, objectKey);
            return objectStream;
        } catch (Exception exception) {
            throw new IngestionProcessingException(PHASE_DOWNLOAD, exception.getMessage(), exception);
        }
    }

    private List<Document> readDocuments(UUID jobId, InputStream objectStream, String objectKey) {
        try {
            TikaDocumentReader reader = new TikaDocumentReader(new InputStreamResource(objectStream));
            List<Document> documents = reader.read();
            log.info("Ingestion 文档解析完成: jobId={}, phase={}, fragments={}, objectKey={}",
                    jobId, PHASE_PARSE, documents.size(), objectKey);
            return documents;
        } catch (Exception exception) {
            if (containsZeroByteSignal(exception)) {
                throw new IngestionProcessingException(
                        PHASE_PARSE,
                        "文档解析结果为 0 字符（可能是空文件或不支持的格式）",
                        exception
                );
            }
            throw new IngestionProcessingException(PHASE_PARSE, exception.getMessage(), exception);
        }
    }

    private boolean containsZeroByteSignal(Throwable throwable) {
        Throwable current = throwable;
        while (current != null) {
            String message = current.getMessage();
            if (current.getClass().getSimpleName().contains("ZeroByte")
                    || (message != null && message.contains("InputStream must have > 0 bytes"))) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }

    private String sanitizeFilename(String filename) {
        if (filename == null || filename.isBlank()) {
            return "upload.bin";
        }
        return filename.trim();
    }

    private Throwable unwrap(Throwable throwable) {
        Throwable current = throwable;
        while (current instanceof CompletionException && current.getCause() != null) {
            current = current.getCause();
        }
        return current;
    }

    private String resolvePhase(Throwable throwable) {
        if (throwable instanceof IngestionProcessingException ingestionProcessingException) {
            return ingestionProcessingException.phase();
        }
        if (throwable instanceof java.util.concurrent.TimeoutException) {
            return PHASE_TIMEOUT;
        }
        return PHASE_VECTOR_STORE;
    }

    private String terminalError(String phase, Throwable throwable) {
        String message = throwable == null ? "未知错误" : throwable.getMessage();
        String normalizedMessage = (message == null || message.isBlank()) ? throwable.getClass().getSimpleName() : message;
        return phase + ": " + normalizedMessage;
    }

    public static final class IngestionDispatchException extends RuntimeException {

        private final UUID jobId;
        private final String errorMessage;

        public IngestionDispatchException(UUID jobId, String errorMessage, Throwable cause) {
            super("MinIO 上传失败，jobId=" + jobId, cause);
            this.jobId = jobId;
            this.errorMessage = errorMessage;
        }

        public UUID jobId() {
            return jobId;
        }

        public String errorMessage() {
            return errorMessage;
        }
    }

    private record ProcessingOutcome(int totalChunks) {
    }

    private static final class IngestionProcessingException extends RuntimeException {

        private final String phase;

        private IngestionProcessingException(String phase, String message) {
            super(message);
            this.phase = phase;
        }

        private IngestionProcessingException(String phase, String message, Throwable cause) {
            super(message, cause);
            this.phase = phase;
        }

        private String phase() {
            return phase;
        }
    }
}
