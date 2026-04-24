package com.zhangspaghetti.babytalk.admin.knowledge;

import com.zhangspaghetti.babytalk.admin.auth.AdminApiContractException;
import com.zhangspaghetti.babytalk.ingestion.IngestionService;
import java.io.InputStream;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminKnowledgeOpsService {

    private static final Logger log = LoggerFactory.getLogger(AdminKnowledgeOpsService.class);

    private static final Set<String> ALLOWED_INGESTION_STATUSES = Set.of(
            "PENDING",
            "PROCESSING",
            "COMPLETED",
            "FAILED"
    );
    private static final Set<String> ALLOWED_CONTRADICTION_STATUSES = Set.of(
            "detected",
            "reviewing",
            "escalated",
            "resolved",
            "dismissed"
    );
    private static final int DEFAULT_LIST_LIMIT = 20;
    private static final int MAX_LIST_LIMIT = 100;
    private static final int DEFAULT_NOTIFICATION_LIMIT = 20;
    private static final int MAX_NOTIFICATION_LIMIT = 50;

    private final AdminKnowledgeIngestionRepository ingestionRepository;
    private final AdminKnowledgeKgRepository kgRepository;
    private final IngestionService ingestionService;
    private final Clock clock;

    public AdminKnowledgeOpsService(
            AdminKnowledgeIngestionRepository ingestionRepository,
            AdminKnowledgeKgRepository kgRepository,
            IngestionService ingestionService,
            Clock clock
    ) {
        this.ingestionRepository = ingestionRepository;
        this.kgRepository = kgRepository;
        this.ingestionService = ingestionService;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<IngestionJobView> listIngestionJobs(String status, Integer limit) {
        var normalizedStatus = normalizeIngestionStatus(status);
        var normalizedLimit = normalizeLimit(limit, DEFAULT_LIST_LIMIT, MAX_LIST_LIMIT, "invalid_knowledge_ingestion_limit");
        try {
            return ingestionRepository.listJobs(normalizedStatus, normalizedLimit).stream()
                    .map(this::toIngestionJobView)
                    .toList();
        } catch (DataAccessException exception) {
            throw storageFailure("list_ingestion_jobs", exception);
        } catch (IllegalStateException exception) {
            throw contractFailure("list_ingestion_jobs", Map.of("reason", exception.getMessage()));
        }
    }

    @Transactional(readOnly = true)
    public IngestionJobView getIngestionJob(String rawJobId) {
        var jobId = parseUuid(rawJobId, "invalid_knowledge_ingestion_job_id", "jobId");
        try {
            var row = ingestionRepository.findJob(jobId)
                    .orElseThrow(() -> new AdminApiContractException(
                            HttpStatus.NOT_FOUND,
                            "knowledge_ingestion_job_not_found",
                            "未找到对应的 ingestion job。",
                            Map.of("jobId", jobId.toString())));
            return toIngestionJobView(row);
        } catch (DataAccessException exception) {
            throw storageFailure("get_ingestion_job", exception);
        } catch (IllegalStateException exception) {
            throw contractFailure("get_ingestion_job", Map.of(
                    "jobId", jobId.toString(),
                    "reason", exception.getMessage()
            ));
        }
    }

    public IngestionJobMutationView uploadIngestion(
            String originalFilename,
            InputStream inputStream,
            String contentType,
            String bookTitle
    ) {
        try {
            var job = ingestionService.uploadAndIngest(originalFilename, inputStream, contentType, normalizeBookTitle(bookTitle));
            return toIngestionJobMutationView(requireIngestionJob(job.id()));
        } catch (IngestionService.IngestionDispatchException exception) {
            throw ingestionDispatchFailure(exception);
        } catch (DataAccessException exception) {
            throw storageFailure("upload_ingestion", exception);
        } catch (IllegalStateException exception) {
            throw contractFailure("upload_ingestion", Map.of("reason", exception.getMessage()));
        }
    }

    public IngestionJobMutationView retryIngestionJob(String rawJobId) {
        var jobId = parseUuid(rawJobId, "invalid_knowledge_ingestion_job_id", "jobId");
        try {
            ingestionService.retryFailedJob(jobId, "");
        } catch (IllegalArgumentException exception) {
            throw new AdminApiContractException(
                    HttpStatus.NOT_FOUND,
                    "knowledge_ingestion_job_not_found",
                    "未找到对应的 ingestion job。",
                    Map.of("jobId", jobId.toString()));
        } catch (IllegalStateException exception) {
            throw retryStateConflict(jobId, exception);
        } catch (DataAccessException exception) {
            throw storageFailure("retry_ingestion_job", exception);
        }

        try {
            return toIngestionJobMutationView(requireIngestionJob(jobId));
        } catch (DataAccessException exception) {
            throw storageFailure("retry_ingestion_job", exception);
        } catch (IllegalStateException exception) {
            throw contractFailure("retry_ingestion_job", Map.of(
                    "jobId", jobId.toString(),
                    "reason", exception.getMessage()
            ));
        }
    }

    @Transactional(readOnly = true)
    public List<ContradictionQueueItemView> listContradictions(String status, Integer limit) {
        var normalizedStatus = normalizeContradictionStatus(status);
        var normalizedLimit = normalizeLimit(limit, DEFAULT_LIST_LIMIT, MAX_LIST_LIMIT, "invalid_knowledge_contradiction_limit");
        try {
            return kgRepository.listContradictions(normalizedStatus, normalizedLimit).stream()
                    .map(this::toContradictionQueueItemView)
                    .toList();
        } catch (DataAccessException exception) {
            throw storageFailure("list_contradictions", exception);
        } catch (IllegalStateException exception) {
            throw contractFailure("list_contradictions", Map.of("reason", exception.getMessage()));
        }
    }

    @Transactional(readOnly = true)
    public ContradictionDetailView getContradiction(String rawContradictionId) {
        var contradictionId = parseUuid(rawContradictionId, "invalid_knowledge_contradiction_id", "contradictionId");
        try {
            return requireContradictionDetail(contradictionId);
        } catch (DataAccessException exception) {
            throw storageFailure("get_contradiction", exception);
        } catch (IllegalStateException exception) {
            throw contractFailure("get_contradiction", Map.of(
                    "contradictionId", contradictionId.toString(),
                    "reason", exception.getMessage()
            ));
        }
    }

    @Transactional(readOnly = true)
    public List<NotificationView> listNotifications(String rawContradictionId, Integer limit) {
        var contradictionId = parseUuid(rawContradictionId, "invalid_knowledge_contradiction_id", "contradictionId");
        var normalizedLimit = normalizeLimit(
                limit,
                DEFAULT_NOTIFICATION_LIMIT,
                MAX_NOTIFICATION_LIMIT,
                "invalid_knowledge_notification_limit"
        );
        try {
            requireContradictionDetail(contradictionId);
            return kgRepository.listNotifications(contradictionId, normalizedLimit).stream()
                    .map(this::toNotificationView)
                    .toList();
        } catch (DataAccessException exception) {
            throw storageFailure("list_notifications", exception);
        } catch (IllegalStateException exception) {
            throw contractFailure("list_notifications", Map.of(
                    "contradictionId", contradictionId.toString(),
                    "reason", exception.getMessage()
            ));
        }
    }

    @Transactional
    public ContradictionDetailView resolveContradiction(String rawContradictionId, String adminNotes) {
        var contradictionId = parseUuid(rawContradictionId, "invalid_knowledge_contradiction_id", "contradictionId");
        var normalizedNotes = normalizeAdminNotes(adminNotes);
        try {
            var contradiction = kgRepository.findContradictionForUpdate(contradictionId)
                    .orElseThrow(() -> contradictionNotFound(contradictionId));
            var status = requireAllowed(
                    contradiction.status(),
                    ALLOWED_CONTRADICTION_STATUSES,
                    "kg_contradictions.status"
            );
            if ("resolved".equals(status)) {
                return toContradictionDetailView(contradiction);
            }

            var resolvedAt = Instant.now(clock);
            kgRepository.resolveContradiction(contradictionId, normalizedNotes, resolvedAt);
            return requireContradictionDetail(contradictionId);
        } catch (DataAccessException exception) {
            throw storageFailure("resolve_contradiction", exception);
        } catch (IllegalStateException exception) {
            throw contractFailure("resolve_contradiction", Map.of(
                    "contradictionId", contradictionId.toString(),
                    "reason", exception.getMessage()
            ));
        }
    }

    @Transactional
    public NotificationView markNotificationRead(String rawNotificationId) {
        var notificationId = parseUuid(rawNotificationId, "invalid_knowledge_notification_id", "notificationId");
        try {
            var notification = kgRepository.findNotificationForUpdate(notificationId)
                    .orElseThrow(() -> notificationNotFound(notificationId));
            if (notification.isRead()) {
                return toNotificationView(notification);
            }
            kgRepository.markNotificationRead(notificationId);
            return kgRepository.findNotification(notificationId)
                    .map(this::toNotificationView)
                    .orElseThrow(() -> notificationNotFound(notificationId));
        } catch (DataAccessException exception) {
            throw storageFailure("mark_notification_read", exception);
        } catch (IllegalStateException exception) {
            throw contractFailure("mark_notification_read", Map.of(
                    "notificationId", notificationId.toString(),
                    "reason", exception.getMessage()
            ));
        }
    }

    private AdminKnowledgeIngestionRepository.IngestionJobRow requireIngestionJob(UUID jobId) {
        return ingestionRepository.findJob(jobId)
                .orElseThrow(() -> new AdminApiContractException(
                        HttpStatus.NOT_FOUND,
                        "knowledge_ingestion_job_not_found",
                        "未找到对应的 ingestion job。",
                        Map.of("jobId", jobId.toString())));
    }

    private ContradictionDetailView requireContradictionDetail(UUID contradictionId) {
        return kgRepository.findContradiction(contradictionId)
                .map(this::toContradictionDetailView)
                .orElseThrow(() -> contradictionNotFound(contradictionId));
    }

    private IngestionJobView toIngestionJobView(AdminKnowledgeIngestionRepository.IngestionJobRow row) {
        var status = requireAllowed(row.status(), ALLOWED_INGESTION_STATUSES, "ingestion_jobs.status");
        return new IngestionJobView(
                row.id(),
                row.originalFilename(),
                status,
                row.totalChunks(),
                row.errorMessage(),
                row.createdAt(),
                row.updatedAt(),
                "FAILED".equals(status)
        );
    }

    private IngestionJobMutationView toIngestionJobMutationView(AdminKnowledgeIngestionRepository.IngestionJobRow row) {
        var status = requireAllowed(row.status(), ALLOWED_INGESTION_STATUSES, "ingestion_jobs.status");
        return new IngestionJobMutationView(
                row.id(),
                row.originalFilename(),
                status,
                row.updatedAt(),
                row.errorMessage(),
                "FAILED".equals(status)
        );
    }

    private ContradictionQueueItemView toContradictionQueueItemView(AdminKnowledgeKgRepository.ContradictionRow row) {
        return new ContradictionQueueItemView(
                row.id(),
                row.entityTopic(),
                row.sourceABook(),
                row.sourceBBook(),
                row.description(),
                requireAllowed(row.status(), ALLOWED_CONTRADICTION_STATUSES, "kg_contradictions.status"),
                row.adminNotes(),
                row.detectedAt(),
                row.reviewedAt(),
                row.resolvedAt(),
                row.notificationCount(),
                row.unreadNotificationCount()
        );
    }

    private ContradictionDetailView toContradictionDetailView(AdminKnowledgeKgRepository.ContradictionRow row) {
        return new ContradictionDetailView(
                row.id(),
                row.entityTopic(),
                row.sourceABook(),
                row.sourceBBook(),
                row.description(),
                requireAllowed(row.status(), ALLOWED_CONTRADICTION_STATUSES, "kg_contradictions.status"),
                row.agentReviewResult(),
                row.adminNotes(),
                row.detectedAt(),
                row.reviewedAt(),
                row.resolvedAt(),
                row.notificationCount(),
                row.unreadNotificationCount()
        );
    }

    private NotificationView toNotificationView(AdminKnowledgeKgRepository.NotificationRow row) {
        return new NotificationView(
                row.id(),
                row.contradictionId(),
                row.notificationType(),
                row.message(),
                row.isRead(),
                row.createdAt()
        );
    }

    private String normalizeIngestionStatus(String status) {
        if (status == null || status.isBlank()) {
            return null;
        }
        var normalized = status.trim().toUpperCase(Locale.ROOT);
        if (!ALLOWED_INGESTION_STATUSES.contains(normalized)) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_knowledge_ingestion_status",
                    "ingestion status filter 不支持该枚举值。",
                    Map.of("allowedStatuses", ALLOWED_INGESTION_STATUSES));
        }
        return normalized;
    }

    private String normalizeContradictionStatus(String status) {
        if (status == null || status.isBlank()) {
            return null;
        }
        var normalized = status.trim().toLowerCase(Locale.ROOT);
        if (!ALLOWED_CONTRADICTION_STATUSES.contains(normalized)) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_knowledge_contradiction_status",
                    "contradiction status filter 不支持该枚举值。",
                    Map.of("allowedStatuses", ALLOWED_CONTRADICTION_STATUSES));
        }
        return normalized;
    }

    private int normalizeLimit(Integer limit, int defaultLimit, int maxLimit, String errorCode) {
        var effectiveLimit = limit == null ? defaultLimit : limit;
        if (effectiveLimit > maxLimit) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    errorCode,
                    "knowledge 查询条数超过上限。",
                    Map.of("maxLimit", maxLimit));
        }
        return effectiveLimit;
    }

    private String normalizeAdminNotes(String adminNotes) {
        if (adminNotes == null || adminNotes.isBlank()) {
            return null;
        }
        return adminNotes.trim();
    }

    private String normalizeBookTitle(String bookTitle) {
        if (bookTitle == null || bookTitle.isBlank()) {
            return "";
        }
        return bookTitle.trim();
    }

    private AdminApiContractException ingestionDispatchFailure(IngestionService.IngestionDispatchException exception) {
        Map<String, Object> details;
        try {
            var failedJob = ingestionRepository.findJob(exception.jobId()).orElse(null);
            details = failedJob == null
                    ? Map.of(
                            "jobId", exception.jobId().toString(),
                            "status", "FAILED",
                            "updatedAt", "",
                            "errorMessage", exception.errorMessage() == null ? "" : exception.errorMessage(),
                            "canRetry", true
                    )
                    : buildIngestionMutationDetails(failedJob);
        } catch (DataAccessException ignored) {
            details = Map.of(
                    "jobId", exception.jobId().toString(),
                    "status", "FAILED",
                    "updatedAt", "",
                    "errorMessage", exception.errorMessage() == null ? "" : exception.errorMessage(),
                    "canRetry", true
            );
        }
        return new AdminApiContractException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "knowledge_ingestion_dispatch_failed",
                "Knowledge ingestion 任务创建失败。",
                details
        );
    }

    private AdminApiContractException retryStateConflict(UUID jobId, IllegalStateException exception) {
        var job = requireIngestionJob(jobId);
        return new AdminApiContractException(
                HttpStatus.CONFLICT,
                "knowledge_ingestion_retry_invalid_state",
                exception.getMessage(),
                buildIngestionMutationDetails(job)
        );
    }

    private Map<String, Object> buildIngestionMutationDetails(AdminKnowledgeIngestionRepository.IngestionJobRow row) {
        var mutationView = toIngestionJobMutationView(row);
        return Map.of(
                "jobId", mutationView.jobId().toString(),
                "status", mutationView.status(),
                "updatedAt", mutationView.updatedAt() == null ? "" : mutationView.updatedAt().toString(),
                "errorMessage", mutationView.errorMessage() == null ? "" : mutationView.errorMessage(),
                "canRetry", mutationView.canRetry()
        );
    }

    private String requireAllowed(String value, Set<String> allowed, String fieldName) {
        if (!allowed.contains(value)) {
            throw new IllegalStateException(fieldName + " unexpected: " + value);
        }
        return value;
    }

    private UUID parseUuid(String rawValue, String errorCode, String fieldName) {
        if (rawValue == null || rawValue.isBlank()) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    errorCode,
                    fieldName + " 不能为空。",
                    Map.of());
        }
        try {
            return UUID.fromString(rawValue.trim());
        } catch (IllegalArgumentException exception) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    errorCode,
                    fieldName + " 必须是合法 UUID。",
                    Map.of(fieldName, rawValue));
        }
    }

    private AdminApiContractException contradictionNotFound(UUID contradictionId) {
        return new AdminApiContractException(
                HttpStatus.NOT_FOUND,
                "knowledge_contradiction_not_found",
                "未找到对应的 KG contradiction。",
                Map.of("contradictionId", contradictionId.toString()));
    }

    private AdminApiContractException notificationNotFound(UUID notificationId) {
        return new AdminApiContractException(
                HttpStatus.NOT_FOUND,
                "knowledge_notification_not_found",
                "未找到对应的管理员通知。",
                Map.of("notificationId", notificationId.toString()));
    }

    private AdminApiContractException storageFailure(String phase, DataAccessException exception) {
        log.warn("admin-knowledge storage failure. phase={}", phase, exception);
        return new AdminApiContractException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "knowledge_ops_storage_unavailable",
                "Knowledge Ops 共享存储暂不可用。",
                Map.of(
                        "phase", phase,
                        "retryable", true
                ));
    }

    private AdminApiContractException contractFailure(String phase, Map<String, Object> details) {
        return new AdminApiContractException(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "knowledge_ops_contract_failure",
                "Knowledge Ops 合同构造失败。",
                Map.of(
                        "phase", phase,
                        "details", details
                ));
    }

    public record IngestionJobView(
            UUID id,
            String originalFilename,
            String status,
            int totalChunks,
            String errorMessage,
            Instant createdAt,
            Instant updatedAt,
            boolean retryable
    ) {
    }

    public record IngestionJobMutationView(
            UUID jobId,
            String originalFilename,
            String status,
            Instant updatedAt,
            String errorMessage,
            boolean canRetry
    ) {
    }

    public record ContradictionQueueItemView(
            UUID id,
            String entityTopic,
            String sourceABook,
            String sourceBBook,
            String description,
            String status,
            String adminNotes,
            Instant detectedAt,
            Instant reviewedAt,
            Instant resolvedAt,
            long notificationCount,
            long unreadNotificationCount
    ) {
    }

    public record ContradictionDetailView(
            UUID id,
            String entityTopic,
            String sourceABook,
            String sourceBBook,
            String description,
            String status,
            String agentReviewResult,
            String adminNotes,
            Instant detectedAt,
            Instant reviewedAt,
            Instant resolvedAt,
            long notificationCount,
            long unreadNotificationCount
    ) {
    }

    public record NotificationView(
            UUID id,
            UUID contradictionId,
            String notificationType,
            String message,
            boolean isRead,
            Instant createdAt
    ) {
    }
}
