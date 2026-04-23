package com.zhangspaghetti.babytalk.ingestion;

import com.zhangspaghetti.babytalk.config.MinioProperties;
import com.zhangspaghetti.babytalk.palace.MemPalaceMetadataEnricher;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.GetObjectArgs;
import java.io.InputStream;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.document.Document;
import org.springframework.ai.reader.tika.TikaDocumentReader;
import org.springframework.ai.transformer.splitter.TokenTextSplitter;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.core.io.InputStreamResource;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

/**
 * Ingestion 管道核心编排 — 完整 ETL：
 *
 * <ol>
 *   <li>uploadAndIngest：文件存入 MinIO → 创建 PENDING job → 异步触发 processFile</li>
 *   <li>processFile（@Async）：MinIO 下载 → TikaDocumentReader 解析 → TokenTextSplitter 分块
 *       → MemPalaceMetadataEnricher 标注 → PgVectorStore 写入</li>
 * </ol>
 *
 * <p>失败处理：0 字符解析结果标记为 FAILED；异常捕获后更新 job 状态为 FAILED + error_message。
 */
@Service
public class IngestionService {

    private static final Logger log = LoggerFactory.getLogger(IngestionService.class);

    private final MinioClient minioClient;
    private final MinioProperties minioProperties;
    private final IngestionRepository repository;
    private final VectorStore vectorStore;
    private final MemPalaceMetadataEnricher metadataEnricher;
    private final TokenTextSplitter tokenTextSplitter;

    public IngestionService(MinioClient minioClient,
                            MinioProperties minioProperties,
                            IngestionRepository repository,
                            VectorStore vectorStore) {
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
    }

    /**
     * 上传文件到 MinIO 并触发异步 ingestion。
     *
     * @param filename     原始文件名
     * @param inputStream  文件输入流
     * @param contentType  MIME 类型
     * @param bookTitle    书名（用于宫殿坐标映射）
     * @return 创建的 IngestionJob（PENDING 状态）
     */
    public IngestionJob uploadAndIngest(String filename, InputStream inputStream,
                                        String contentType, String bookTitle) {
        // 生成唯一 object key
        String objectKey = "ingestion/" + UUID.randomUUID() + "/" + filename;

        try {
            // 存入 MinIO
            minioClient.putObject(
                    PutObjectArgs.builder()
                            .bucket(minioProperties.bucketName())
                            .object(objectKey)
                            .stream(inputStream, -1, 10485760) // 10MB part size
                            .contentType(contentType != null ? contentType : "application/octet-stream")
                            .build()
            );
            log.info("文件已上传到 MinIO: bucket={}, key={}", minioProperties.bucketName(), objectKey);
        } catch (Exception e) {
            throw new RuntimeException("MinIO 上传失败: " + filename, e);
        }

        // 创建 PENDING job
        IngestionJob job = IngestionJob.pending(filename, objectKey);
        repository.insert(job);
        log.info("Ingestion job 已创建: id={}, filename={}", job.id(), filename);

        // 异步处理
        processFile(job.id(), objectKey, bookTitle);

        return job;
    }

    /**
     * 异步 ETL 处理：MinIO 下载 → Tika 解析 → 分块 → 元数据标注 → 向量写入。
     */
    @Async("ingestionExecutor")
    public void processFile(UUID jobId, String objectKey, String bookTitle) {
        log.info("开始处理 ingestion job: id={}, objectKey={}", jobId, objectKey);

        repository.updateStatusProcessing(jobId);

        try {
            // 1. 从 MinIO 下载
            InputStream objectStream = minioClient.getObject(
                    GetObjectArgs.builder()
                            .bucket(minioProperties.bucketName())
                            .object(objectKey)
                            .build()
            );

            // 2. TikaDocumentReader 解析
            InputStreamResource resource = new InputStreamResource(objectStream);
            TikaDocumentReader reader = new TikaDocumentReader(resource);
            List<Document> documents = reader.read();

            // 3. 检查解析结果 — 0 字符视为解析失败
            long totalChars = documents.stream()
                    .mapToLong(doc -> doc.getText() != null ? doc.getText().length() : 0)
                    .sum();
            if (totalChars == 0) {
                log.warn("文档解析结果为 0 字符: jobId={}, objectKey={}", jobId, objectKey);
                repository.updateFailed(jobId, "文档解析结果为 0 字符（可能是空文件或不支持的格式）");
                return;
            }

            log.info("Tika 解析完成: {} 个文档片段, 总字符数={}", documents.size(), totalChars);

            // 4. 注入 source_book metadata
            for (Document doc : documents) {
                doc.getMetadata().put("source_book", bookTitle != null ? bookTitle : "");
            }

            // 5. TokenTextSplitter 分块
            List<Document> chunks = tokenTextSplitter.apply(documents);
            log.info("分块完成: {} 个 chunks", chunks.size());

            // 6. MemPalaceMetadataEnricher 标注宫殿坐标
            chunks = metadataEnricher.apply(chunks);

            // 7. PgVectorStore 写入（embedding 在 add 内部自动调用）
            vectorStore.add(chunks);
            log.info("向量写入完成: {} 个 chunks 已入库", chunks.size());

            // 8. 标记完成
            repository.updateCompleted(jobId, chunks.size());
            log.info("Ingestion job 完成: id={}, chunks={}", jobId, chunks.size());

        } catch (Exception e) {
            log.error("Ingestion job 处理失败: id={}", jobId, e);
            repository.updateFailed(jobId, e.getMessage());
        }
    }
}
