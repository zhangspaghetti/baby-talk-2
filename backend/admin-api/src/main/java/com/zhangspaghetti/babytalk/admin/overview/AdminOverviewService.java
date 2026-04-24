package com.zhangspaghetti.babytalk.admin.overview;

import com.zhangspaghetti.babytalk.admin.auth.AdminApiContractException;
import com.zhangspaghetti.babytalk.admin.rbac.AdminPermissionCatalog;
import java.sql.SQLException;
import java.sql.SQLTimeoutException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@Service
public class AdminOverviewService {

    private static final Logger log = LoggerFactory.getLogger(AdminOverviewService.class);

    private static final Duration DISTRIBUTION_WINDOW = Duration.ofDays(30);
    private static final Duration DEFAULT_STALE_AFTER = Duration.ofMinutes(15);
    private static final Duration DISTRIBUTION_STALE_AFTER = Duration.ofMinutes(30);

    private final AdminOverviewReadRepository overviewReadRepository;
    private final AdminOverviewStreamService overviewStreamService;
    private final Clock clock;
    private final TransactionTemplate readOnlyTransaction;
    private final ConcurrentMap<DomainKey, CachedDomainView> cachedDomains = new ConcurrentHashMap<>();
    private final ConcurrentMap<String, Instant> lastSuccessfulSelectionSnapshots = new ConcurrentHashMap<>();

    public AdminOverviewService(
            AdminOverviewReadRepository overviewReadRepository,
            AdminOverviewStreamService overviewStreamService,
            Clock clock,
            PlatformTransactionManager transactionManager
    ) {
        this.overviewReadRepository = overviewReadRepository;
        this.overviewStreamService = overviewStreamService;
        this.clock = clock;
        this.readOnlyTransaction = new TransactionTemplate(transactionManager);
        this.readOnlyTransaction.setReadOnly(true);
    }

    public OverviewSummaryView getSummary(Authentication authentication) {
        var visibility = resolveVisibility(authentication);
        var generatedAt = Instant.now(clock);
        var selectionKey = visibility.selectionKey();
        var domains = new ArrayList<DomainView>(DomainKey.values().length);
        var timedOutDomains = EnumSet.noneOf(DomainKey.class);

        for (var domainKey : DomainKey.values()) {
            if (!visibility.visibleDomains().contains(domainKey)) {
                domains.add(hiddenDomain(domainKey));
                continue;
            }

            try {
                var domainView = loadVisibleDomain(domainKey, generatedAt);
                validateDomainView(domainView);
                cachedDomains.put(domainKey, new CachedDomainView(domainView, generatedAt));
                domains.add(domainView);
            } catch (DataAccessException exception) {
                if (!isTimeout(exception)) {
                    throw storageFailure(domainKey, exception);
                }
                timedOutDomains.add(domainKey);
                domains.add(null);
                log.warn("admin-overview domain timeout. domain={}", domainKey.key(), exception);
            } catch (IllegalStateException exception) {
                throw contractFailure(domainKey, Map.of("reason", exception.getMessage()));
            }
        }

        if (timedOutDomains.isEmpty()) {
            lastSuccessfulSelectionSnapshots.put(selectionKey, generatedAt);
            var transport = overviewStreamService.markLive(generatedAt, "summary_refresh");
            return buildSummary(generatedAt, generatedAt, transport, domains);
        }

        var lastSuccessfulSnapshotAt = lastSuccessfulSelectionSnapshots.get(selectionKey);
        if (lastSuccessfulSnapshotAt == null) {
            overviewStreamService.markPollingRequired(null, "repository_timeout_without_snapshot");
            throw snapshotUnavailable(timedOutDomains);
        }

        for (var domainKey : timedOutDomains) {
            var cached = cachedDomains.get(domainKey);
            if (cached == null) {
                overviewStreamService.markPollingRequired(lastSuccessfulSnapshotAt, "repository_timeout_missing_domain_cache");
                throw snapshotUnavailable(timedOutDomains);
            }
            domains.set(domainKey.ordinal(), degradedDomain(cached.view(), domainKey));
        }

        var transport = overviewStreamService.markPollingRequired(lastSuccessfulSnapshotAt, "repository_timeout");
        return buildSummary(generatedAt, lastSuccessfulSnapshotAt, transport, domains);
    }

    private DomainView loadVisibleDomain(DomainKey domainKey, Instant generatedAt) {
        return switch (domainKey) {
            case KNOWLEDGE_INGESTION -> buildKnowledgeIngestionDomain(generatedAt);
            case KNOWLEDGE_KG -> buildKnowledgeKgDomain(generatedAt);
            case MENTOR_AUDIT -> buildMentorAuditDomain(generatedAt);
            case DISTRIBUTION -> buildDistributionDomain(generatedAt);
        };
    }

    private DomainView buildKnowledgeIngestionDomain(Instant generatedAt) {
        var summary = runReadOnly(overviewReadRepository::fetchKnowledgeIngestionSummary);
        var queueCount = summary.pendingCount() + summary.processingCount() + summary.failedCount();
        var attentionCount = summary.failedCount();
        var allClear = queueCount == 0;
        var freshness = freshnessView(
                queueCount == 0,
                summary.pendingCount() + summary.processingCount() > 0,
                generatedAt,
                summary.lastUpdatedAt(),
                DEFAULT_STALE_AFTER,
                null
        );
        return new DomainView(
                DomainKey.KNOWLEDGE_INGESTION.key(),
                DomainKey.KNOWLEDGE_INGESTION.title(),
                DomainKey.KNOWLEDGE_INGESTION.permissionCode(),
                true,
                freshness,
                new QueueView(queueCount, attentionCount, allClear),
                knowledgeIngestionAction(summary),
                List.of(
                        new CountView("pending", summary.pendingCount()),
                        new CountView("processing", summary.processingCount()),
                        new CountView("failed", summary.failedCount()),
                        new CountView("completed", summary.completedCount())
                )
        );
    }

    private DomainView buildKnowledgeKgDomain(Instant generatedAt) {
        var summary = runReadOnly(overviewReadRepository::fetchKnowledgeKgSummary);
        var queueCount = summary.openCount() + summary.unreadNotificationCount();
        var attentionCount = summary.escalatedCount() + summary.unreadNotificationCount();
        var allClear = queueCount == 0;
        var freshness = freshnessView(
                allClear,
                false,
                generatedAt,
                summary.lastUpdatedAt(),
                DEFAULT_STALE_AFTER,
                null
        );
        return new DomainView(
                DomainKey.KNOWLEDGE_KG.key(),
                DomainKey.KNOWLEDGE_KG.title(),
                DomainKey.KNOWLEDGE_KG.permissionCode(),
                true,
                freshness,
                new QueueView(queueCount, attentionCount, allClear),
                knowledgeKgAction(summary),
                List.of(
                        new CountView("open", summary.openCount()),
                        new CountView("escalated", summary.escalatedCount()),
                        new CountView("unread_notifications", summary.unreadNotificationCount()),
                        new CountView("resolved", summary.resolvedCount())
                )
        );
    }

    private DomainView buildMentorAuditDomain(Instant generatedAt) {
        var summary = runReadOnly(overviewReadRepository::fetchMentorAuditSummary);
        var queueCount = summary.flaggedIncidentCount();
        var attentionCount = summary.blockedFallbackCount() + summary.rateLimitedCount();
        var allClear = queueCount == 0;
        var freshness = freshnessView(
                allClear,
                false,
                generatedAt,
                summary.lastOccurredAt(),
                DEFAULT_STALE_AFTER,
                null
        );
        return new DomainView(
                DomainKey.MENTOR_AUDIT.key(),
                DomainKey.MENTOR_AUDIT.title(),
                DomainKey.MENTOR_AUDIT.permissionCode(),
                true,
                freshness,
                new QueueView(queueCount, attentionCount, allClear),
                mentorAuditAction(summary),
                List.of(
                        new CountView("flagged_incidents", summary.flaggedIncidentCount()),
                        new CountView("blocked_fallback", summary.blockedFallbackCount()),
                        new CountView("rate_limited", summary.rateLimitedCount()),
                        new CountView("retryable", summary.retryableCount())
                )
        );
    }

    private DomainView buildDistributionDomain(Instant generatedAt) {
        var summary = runReadOnly(() -> overviewReadRepository.fetchDistributionSummary(generatedAt.minus(DISTRIBUTION_WINDOW)));
        var failureCount = summary.releaseFailureEvents() + summary.shareFailureEvents();
        var allClear = failureCount == 0;
        var freshness = freshnessView(
                allClear,
                false,
                generatedAt,
                summary.lastSeenAt(),
                DISTRIBUTION_STALE_AFTER,
                null
        );
        return new DomainView(
                DomainKey.DISTRIBUTION.key(),
                DomainKey.DISTRIBUTION.title(),
                DomainKey.DISTRIBUTION.permissionCode(),
                true,
                freshness,
                new QueueView(failureCount, failureCount, allClear),
                distributionAction(failureCount),
                List.of(
                        new CountView("release_total_events", summary.releaseTotalEvents()),
                        new CountView("release_failure_events", summary.releaseFailureEvents()),
                        new CountView("share_total_events", summary.shareTotalEvents()),
                        new CountView("share_failure_events", summary.shareFailureEvents())
                )
        );
    }

    private FreshnessView freshnessView(
            boolean allClear,
            boolean updating,
            Instant generatedAt,
            Instant sourceUpdatedAt,
            Duration staleAfter,
            String degradedReason
    ) {
        var state = readFreshnessState(allClear, updating, generatedAt, sourceUpdatedAt, staleAfter, degradedReason);
        return new FreshnessView(state, sourceUpdatedAt, staleAfter.toSeconds(), degradedReason);
    }

    private String readFreshnessState(
            boolean allClear,
            boolean updating,
            Instant generatedAt,
            Instant sourceUpdatedAt,
            Duration staleAfter,
            String degradedReason
    ) {
        if (degradedReason != null) {
            return "degraded";
        }
        if (allClear) {
            return "all_clear";
        }
        if (updating) {
            return "updating";
        }
        if (sourceUpdatedAt == null) {
            throw new IllegalStateException("visible domain is missing source freshness timestamp");
        }
        return sourceUpdatedAt.isBefore(generatedAt.minus(staleAfter)) ? "stale" : "fresh";
    }

    private OverviewSummaryView buildSummary(
            Instant generatedAt,
            Instant lastSuccessfulSnapshotAt,
            AdminOverviewStreamService.TransportView transport,
            List<DomainView> domains
    ) {
        var visibleDomainCount = (int) domains.stream().filter(DomainView::visible).count();
        var degradedDomainCount = (int) domains.stream()
                .filter(DomainView::visible)
                .filter(domain -> "degraded".equals(domain.freshness().state()))
                .count();
        return new OverviewSummaryView(
                generatedAt,
                lastSuccessfulSnapshotAt,
                visibleDomainCount,
                degradedDomainCount,
                transport,
                List.copyOf(domains)
        );
    }

    private DomainView hiddenDomain(DomainKey domainKey) {
        return new DomainView(
                domainKey.key(),
                domainKey.title(),
                domainKey.permissionCode(),
                false,
                new FreshnessView("forbidden", null, 0, "missing_permission"),
                new QueueView(null, null, null),
                new NextActionView("permission_required", "Permission required", null),
                List.of()
        );
    }

    private DomainView degradedDomain(DomainView cachedView, DomainKey domainKey) {
        return new DomainView(
                cachedView.key(),
                cachedView.title(),
                cachedView.requiredPermission(),
                cachedView.visible(),
                new FreshnessView(
                        "degraded",
                        cachedView.freshness().sourceUpdatedAt(),
                        cachedView.freshness().staleAfterSeconds(),
                        "repository_timeout"
                ),
                cachedView.queue(),
                new NextActionView("reload_domain", "Reload " + domainKey.title(), routeForDomain(domainKey)),
                cachedView.counts()
        );
    }

    private void validateDomainView(DomainView domainView) {
        if (!domainView.visible()) {
            return;
        }
        if (domainView.queue() == null || domainView.nextAction() == null || domainView.freshness() == null) {
            throw new IllegalStateException("visible domain envelope is incomplete");
        }
        if (domainView.queue().queueCount() != null && domainView.queue().queueCount() < 0) {
            throw new IllegalStateException("queue count cannot be negative");
        }
        if (domainView.queue().attentionCount() != null && domainView.queue().attentionCount() < 0) {
            throw new IllegalStateException("attention count cannot be negative");
        }
        if (!"all_clear".equals(domainView.freshness().state())
                && !"degraded".equals(domainView.freshness().state())
                && domainView.freshness().sourceUpdatedAt() == null) {
            throw new IllegalStateException("freshness timestamp is required when work is visible");
        }
    }

    private Visibility resolveVisibility(Authentication authentication) {
        var authorities = authentication == null
                ? Set.<String>of()
                : authentication.getAuthorities().stream()
                        .map(GrantedAuthority::getAuthority)
                        .collect(Collectors.toUnmodifiableSet());
        var visibleDomains = EnumSet.noneOf(DomainKey.class);
        for (var domainKey : DomainKey.values()) {
            if (authorities.contains(domainKey.permissionCode())) {
                visibleDomains.add(domainKey);
            }
        }
        if (visibleDomains.isEmpty()) {
            throw new AdminApiContractException(
                    HttpStatus.FORBIDDEN,
                    "forbidden",
                    "权限不足。",
                    Map.of());
        }
        return new Visibility(visibleDomains);
    }

    private <T> T runReadOnly(ReadOperation<T> operation) {
        var value = readOnlyTransaction.execute(status -> operation.run());
        return Objects.requireNonNull(value, "read operation returned null");
    }

    private NextActionView knowledgeIngestionAction(AdminOverviewReadRepository.KnowledgeIngestionSummaryRow summary) {
        if (summary.failedCount() > 0) {
            return new NextActionView(
                    "retry_failed_jobs",
                    "Retry failed ingestion jobs",
                    "/knowledge-ops?view=ingestion&status=failed"
            );
        }
        if (summary.pendingCount() + summary.processingCount() > 0) {
            return new NextActionView(
                    "watch_active_jobs",
                    "Watch active ingestion jobs",
                    "/knowledge-ops?view=ingestion&status=all"
            );
        }
        return new NextActionView("all_clear", "All clear", "/knowledge-ops?view=ingestion&status=all");
    }

    private NextActionView knowledgeKgAction(AdminOverviewReadRepository.KnowledgeKgSummaryRow summary) {
        if (summary.escalatedCount() > 0 || summary.unreadNotificationCount() > 0) {
            return new NextActionView(
                    "review_escalated_contradictions",
                    "Review escalated contradictions",
                    "/knowledge-ops?view=kg-review&status=escalated"
            );
        }
        if (summary.openCount() > 0) {
            return new NextActionView(
                    "review_open_contradictions",
                    "Review open contradictions",
                    "/knowledge-ops?view=kg-review&status=all"
            );
        }
        return new NextActionView("all_clear", "All clear", "/knowledge-ops?view=kg-review&status=all");
    }

    private NextActionView mentorAuditAction(AdminOverviewReadRepository.MentorAuditSummaryRow summary) {
        if (summary.blockedFallbackCount() > 0) {
            return new NextActionView(
                    "review_blocked_fallback",
                    "Review blocked fallback incidents",
                    "/mentor/audits?flag=blocked_fallback"
            );
        }
        if (summary.rateLimitedCount() > 0) {
            return new NextActionView(
                    "review_rate_limited",
                    "Review rate-limited incidents",
                    "/mentor/audits?flag=rate_limited"
            );
        }
        if (summary.flaggedIncidentCount() > 0) {
            return new NextActionView(
                    "review_recent_incidents",
                    "Review recent mentor incidents",
                    "/mentor/audits"
            );
        }
        return new NextActionView("all_clear", "All clear", "/mentor/audits");
    }

    private NextActionView distributionAction(long failureCount) {
        if (failureCount > 0) {
            return new NextActionView(
                    "inspect_distribution_failures",
                    "Inspect recent distribution failures",
                    "/distribution/stats?range=30d"
            );
        }
        return new NextActionView("all_clear", "All clear", "/distribution/stats?range=30d");
    }

    private String routeForDomain(DomainKey domainKey) {
        return switch (domainKey) {
            case KNOWLEDGE_INGESTION -> "/knowledge-ops?view=ingestion&status=all";
            case KNOWLEDGE_KG -> "/knowledge-ops?view=kg-review&status=all";
            case MENTOR_AUDIT -> "/mentor/audits";
            case DISTRIBUTION -> "/distribution/stats?range=30d";
        };
    }

    private boolean isTimeout(Throwable throwable) {
        var current = throwable;
        while (current != null) {
            if (current instanceof SQLTimeoutException) {
                return true;
            }
            if (current instanceof SQLException sqlException && "57014".equals(sqlException.getSQLState())) {
                return true;
            }
            var message = current.getMessage();
            if (message != null && message.toLowerCase().contains("statement timeout")) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }

    private AdminApiContractException storageFailure(DomainKey domainKey, DataAccessException exception) {
        log.warn("admin-overview storage failure. domain={}", domainKey.key(), exception);
        return new AdminApiContractException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "overview_storage_unavailable",
                "Overview truth source 暂不可用。",
                Map.of(
                        "domain", domainKey.key(),
                        "retryable", true
                )
        );
    }

    private AdminApiContractException contractFailure(DomainKey domainKey, Map<String, Object> details) {
        return new AdminApiContractException(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "overview_contract_failure",
                "Overview 合同构造失败。",
                Map.of(
                        "domain", domainKey.key(),
                        "details", details
                )
        );
    }

    private AdminApiContractException snapshotUnavailable(Set<DomainKey> timedOutDomains) {
        return new AdminApiContractException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "overview_snapshot_unavailable",
                "Overview 暂无可回退的最后成功快照。",
                Map.of(
                        "timedOutDomains", timedOutDomains.stream().map(DomainKey::key).toList(),
                        "retryable", true
                )
        );
    }

    @FunctionalInterface
    private interface ReadOperation<T> {
        T run();
    }

    private record Visibility(EnumSet<DomainKey> visibleDomains) {

        private String selectionKey() {
            return visibleDomains.stream().map(DomainKey::key).collect(Collectors.joining(","));
        }
    }

    private record CachedDomainView(DomainView view, Instant cachedAt) {
    }

    private enum DomainKey {
        KNOWLEDGE_INGESTION("knowledge_ingestion", "Knowledge ingestion", AdminPermissionCatalog.RAG_READ),
        KNOWLEDGE_KG("knowledge_kg", "Knowledge contradictions", AdminPermissionCatalog.KG_READ),
        MENTOR_AUDIT("mentor_audit", "Mentor audit", AdminPermissionCatalog.MENTOR_AUDIT),
        DISTRIBUTION("distribution", "Distribution stats", AdminPermissionCatalog.DISTRIBUTION_READ);

        private final String key;
        private final String title;
        private final String permissionCode;

        DomainKey(String key, String title, String permissionCode) {
            this.key = key;
            this.title = title;
            this.permissionCode = permissionCode;
        }

        public String key() {
            return key;
        }

        public String title() {
            return title;
        }

        public String permissionCode() {
            return permissionCode;
        }
    }

    public record OverviewSummaryView(
            Instant generatedAt,
            Instant lastSuccessfulSnapshotAt,
            int visibleDomainCount,
            int degradedDomainCount,
            AdminOverviewStreamService.TransportView transport,
            List<DomainView> domains
    ) {
    }

    public record DomainView(
            String key,
            String title,
            String requiredPermission,
            boolean visible,
            FreshnessView freshness,
            QueueView queue,
            NextActionView nextAction,
            List<CountView> counts
    ) {
    }

    public record FreshnessView(
            String state,
            Instant sourceUpdatedAt,
            long staleAfterSeconds,
            String degradedReason
    ) {
    }

    public record QueueView(
            Long queueCount,
            Long attentionCount,
            Boolean allClear
    ) {
    }

    public record NextActionView(
            String code,
            String label,
            String href
    ) {
    }

    public record CountView(String key, long value) {
    }
}
