package com.zhangspaghetti.babytalk.service;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

@Repository
public class MentorRepository {

    private final MentorMapper mapper;
    private final TransactionTemplate requiresNewTx;
    private final ConcurrentHashMap<String, Object> rateLimitLocks = new ConcurrentHashMap<>();

    public MentorRepository(MentorMapper mapper, PlatformTransactionManager txManager) {
        this.mapper = mapper;
        this.requiresNewTx = new TransactionTemplate(txManager);
        this.requiresNewTx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    int countRequestsSince(String installationId, Instant since) {
        return mapper.countRequestsSince(installationId, since);
    }

    /**
        * 原子操作：在 per-installation 锁保护下，用独立事务 INSERT requested audit 并 COUNT 窗口内行数。
     * Java 级别 synchronized(per-installationId) 串行化并发请求的 INSERT+COUNT 序列；
     * REQUIRES_NEW 保证每次 INSERT 立即提交，后续请求的 COUNT 能看到前序已提交的行。
     */
    int insertAuditAndCountWindow(AuditRow row, Instant windowStart) {
        Object lock = rateLimitLocks.computeIfAbsent(row.installationId(), k -> new Object());
        synchronized (lock) {
            return requiresNewTx.execute(status -> {
                insertAudit(row);
                return countRequestsSince(row.installationId(), windowStart);
            });
        }
    }

    void insertTurn(TurnRow row) {
        mapper.insertTurn(row);
    }

    void insertAudit(AuditRow row) {
        mapper.insertAudit(row);
    }

    Optional<TurnRow> findTurnByCorrelationId(String correlationId) {
        return Optional.ofNullable(mapper.findTurnByCorrelationId(correlationId));
    }

    List<AuditRow> listAuditRowsByCorrelationId(String correlationId) {
        return mapper.listAuditRowsByCorrelationId(correlationId);
    }

    int countTurns() {
        return mapper.countTurns();
    }

    int countAuditRows() {
        return mapper.countAuditRows();
    }

    public record TurnRow(
            String turnId,
            String correlationId,
            String installationId,
            String sessionIdHint,
            String accountIdHint,
            String surface,
            String mode,
            String result,
            String phase,
            String requestSummary,
            String responseSummary,
            String responseText,
            String providerMode,
            boolean blockedFallback,
            boolean retryable,
            Instant createdAt
    ) {
    }

    public record AuditRow(
            String correlationId,
            String installationId,
            String sessionIdHint,
            String accountIdHint,
            String eventType,
            String phase,
            String result,
            String requestSummary,
            String responseSummary,
            String reason,
            String failureCode,
            boolean retryable,
            boolean rateLimited,
            Instant createdAt
    ) {
    }
}
