package com.zhangspaghetti.babytalk.ingestion;

import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * Ingestion REST API — 文献上传 / 状态查询 / 失败重试。
 *
 * <ul>
 *   <li>POST /api/v1/ingestion/upload — 上传文件 + bookTitle，返回 202 + jobId</li>
 *   <li>GET  /api/v1/ingestion/jobs/{id} — 查询单个 job 状态</li>
 *   <li>POST /api/v1/ingestion/jobs/{id}/retry — 重新触发失败的 job</li>
 * </ul>
 */
@RestController
@RequestMapping("/api/v1/ingestion")
public class IngestionController {

    private static final Logger log = LoggerFactory.getLogger(IngestionController.class);

    private final IngestionService ingestionService;
    private final IngestionRepository ingestionRepository;

    public IngestionController(IngestionService ingestionService,
                               IngestionRepository ingestionRepository) {
        this.ingestionService = ingestionService;
        this.ingestionRepository = ingestionRepository;
    }

    /**
     * 上传文件并触发异步 ingestion 管道。
     *
     * @param file      上传的文件（multipart/form-data）
     * @param bookTitle 书名，用于宫殿坐标映射
     * @return 202 Accepted + {jobId}
     */
    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<Map<String, String>> upload(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "bookTitle", required = false, defaultValue = "") String bookTitle) {

        if (file.isEmpty()) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "上传文件不能为空"));
        }

        try {
            IngestionJob job = ingestionService.uploadAndIngest(
                    file.getOriginalFilename(),
                    file.getInputStream(),
                    file.getContentType(),
                    bookTitle
            );

            log.info("文件上传成功，ingestion job 已创建: jobId={}, filename={}",
                    job.id(), file.getOriginalFilename());

            return ResponseEntity.status(HttpStatus.ACCEPTED)
                    .body(Map.of("jobId", job.id().toString()));

        } catch (Exception e) {
            log.error("文件上传失败: filename={}", file.getOriginalFilename(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("error", "文件上传处理失败: " + e.getMessage()));
        }
    }

    /**
     * 查询单个 ingestion job 的状态。
     *
     * @param id job UUID
     * @return job 状态详情 JSON
     */
    @GetMapping("/jobs/{id}")
    public ResponseEntity<Map<String, Object>> getJobStatus(@PathVariable UUID id) {
        return ingestionRepository.findById(id)
                .map(job -> ResponseEntity.ok(jobToMap(job)))
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    /**
     * 重试失败的 ingestion job。只能重试 FAILED 状态的 job。
     *
     * @param id job UUID
     * @return 202 Accepted 或 409 Conflict（非 FAILED 状态）
     */
    @PostMapping("/jobs/{id}/retry")
    public ResponseEntity<Map<String, String>> retryJob(@PathVariable UUID id) {
        return ingestionRepository.findById(id)
                .map(job -> {
                    if (!IngestionJob.STATUS_FAILED.equals(job.status())) {
                        return ResponseEntity.status(HttpStatus.CONFLICT)
                                .body(Map.of("error",
                                        "只能重试 FAILED 状态的 job，当前状态: " + job.status()));
                    }

                    // 重置为 PENDING 并重新触发异步处理
                    ingestionRepository.updateStatusPending(id);
                    ingestionService.processFile(id, job.minioObjectKey(), "");

                    log.info("Ingestion job 重试已触发: jobId={}", id);
                    return ResponseEntity.status(HttpStatus.ACCEPTED)
                            .body(Map.of("jobId", id.toString(), "message", "重试已触发"));
                })
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    private Map<String, Object> jobToMap(IngestionJob job) {
        return Map.of(
                "id", job.id().toString(),
                "originalFilename", job.originalFilename(),
                "status", job.status(),
                "totalChunks", job.totalChunks(),
                "errorMessage", job.errorMessage() != null ? job.errorMessage() : "",
                "createdAt", job.createdAt().toString(),
                "updatedAt", job.updatedAt().toString()
        );
    }
}
