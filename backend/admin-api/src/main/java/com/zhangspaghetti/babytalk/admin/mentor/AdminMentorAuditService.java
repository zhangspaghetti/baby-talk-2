package com.zhangspaghetti.babytalk.admin.mentor;

import com.zhangspaghetti.babytalk.admin.auth.AdminApiContractException;
import com.zhangspaghetti.babytalk.security.SensitiveAuthDataProtector;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminMentorAuditService {

    private static final List<String> ALLOWED_FLAGS = List.of(
            "blocked_fallback",
            "rate_limited",
            "provider_timeout",
            "provider_malformed_response",
            "provider_unavailable",
            "invalid_session",
            "consent_revoked",
            "account_deleted",
            "session_installation_mismatch",
            "other_incident"
    );

    private static final Set<String> ALLOWED_FLAG_SET = Set.copyOf(ALLOWED_FLAGS);

    private final AdminMentorAuditReadRepository repository;
    private final AdminMentorAuditProperties properties;
    private final SensitiveAuthDataProtector sensitiveAuthDataProtector;
    private final Clock clock;

    public AdminMentorAuditService(
            AdminMentorAuditReadRepository repository,
            AdminMentorAuditProperties properties,
            SensitiveAuthDataProtector sensitiveAuthDataProtector,
            Clock clock
    ) {
        this.repository = repository;
        this.properties = properties;
        this.sensitiveAuthDataProtector = sensitiveAuthDataProtector;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<QueueIncidentView> listAudits(String installationId, String flag, Integer limit) {
        var normalizedInstallationId = normalizeOptionalInstallationId(installationId);
        var normalizedFlag = normalizeFlag(flag);
        var effectiveLimit = normalizeLimit(limit);
        var installationFilter = installationFilter(normalizedInstallationId);
        return repository.listFlaggedIncidents(
                        installationFilter.reference(),
                        installationFilter.legacyRaw(),
                        normalizedFlag,
                        effectiveLimit).stream()
                .map(row -> new QueueIncidentView(
                        row.correlationId(),
                        sensitiveAuthDataProtector.safeInstallationReference(row.installationId()),
                        row.flagCode(),
                        row.latestPhase(),
                        row.failureCode(),
                        row.retryable(),
                        row.historicalRateLimited(),
                        row.occurredAt()))
                .toList();
    }

    @Transactional(readOnly = true)
    public AuditDetailView getAudit(String correlationId) {
        var normalizedCorrelationId = normalizeCorrelationId(correlationId);
        var snapshot = repository.findIncidentSnapshot(normalizedCorrelationId)
                .orElseThrow(() -> new AdminApiContractException(
                        HttpStatus.NOT_FOUND,
                        "mentor_audit_not_found",
                        "未找到对应的 mentor incident。",
                        Map.of("correlationId", normalizedCorrelationId)));
        var timeline = repository.listTimeline(normalizedCorrelationId);
        var deliveredTurn = repository.findDeliveredTurn(normalizedCorrelationId);
        var requestSummary = deliveredTurn.map(AdminMentorAuditReadRepository.DeliveredTurnRow::requestSummary)
                .filter(AdminMentorAuditService::hasText)
                .orElseGet(() -> timeline.stream()
                        .map(AdminMentorAuditReadRepository.TimelineRow::requestSummary)
                        .filter(AdminMentorAuditService::hasText)
                        .findFirst()
                        .orElse(null));
        var now = Instant.now(clock);
        var installationFilter = installationFilter(
                normalizeOptionalInstallationId(snapshot.installationId()));
        var currentCount = repository.countCurrentWindowRequests(
                installationFilter.reference(),
                installationFilter.legacyRaw(),
                now.minus(properties.rateLimitWindow())
        );
        var remaining = Math.max(0, properties.rateLimitMaxRequests() - currentCount);
        return new AuditDetailView(
                "incident_evidence",
                snapshot.correlationId(),
                sensitiveAuthDataProtector.safeInstallationReference(snapshot.installationId()),
                snapshot.flagCode(),
                snapshot.latestPhase(),
                snapshot.failureCode(),
                snapshot.retryable(),
                snapshot.historicalRateLimited(),
                snapshot.occurredAt(),
                new RequestEvidence(requestSummary),
                deliveredTurn.isPresent() ? "delivered" : "missing_turn",
                deliveredTurn.map(turn -> new DeliveredResponseEvidence(
                        turn.result(),
                        turn.phase(),
                        turn.responseSummary(),
                        turn.responseText(),
                        turn.blockedFallback(),
                        turn.providerMode(),
                        turn.retryable(),
                        turn.createdAt())).orElse(null),
                timeline.stream()
                        .map(row -> new TimelineEventView(
                                row.auditId(),
                                row.eventType(),
                                row.phase(),
                                row.result(),
                                row.requestSummary(),
                                row.responseSummary(),
                                row.reason(),
                                row.failureCode(),
                                row.retryable(),
                                row.rateLimited(),
                                row.createdAt()))
                        .toList(),
                new LiveRateLimitView(
                        currentCount >= properties.rateLimitMaxRequests(),
                        currentCount,
                        properties.rateLimitMaxRequests(),
                        remaining,
                        properties.rateLimitWindow().toSeconds()));
    }

    private String normalizeOptionalInstallationId(String installationId) {
        if (!hasText(installationId)) {
            return null;
        }
        return installationId.trim();
    }

    private InstallationFilter installationFilter(String normalizedInstallationId) {
        if (normalizedInstallationId == null) {
            return new InstallationFilter(null, null);
        }
        if (sensitiveAuthDataProtector.isInstallationReference(normalizedInstallationId)) {
            return new InstallationFilter(normalizedInstallationId, null);
        }
        return new InstallationFilter(
                sensitiveAuthDataProtector.installationLookupRef(normalizedInstallationId),
                normalizedInstallationId);
    }

    private String normalizeFlag(String flag) {
        if (!hasText(flag)) {
            return null;
        }
        var normalized = flag.trim();
        if (!ALLOWED_FLAG_SET.contains(normalized)) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "unknown_mentor_audit_flag",
                    "未知的 mentor audit flag。",
                    Map.of("allowedFlags", ALLOWED_FLAGS));
        }
        return normalized;
    }

    private int normalizeLimit(Integer limit) {
        var effectiveLimit = limit == null ? properties.defaultLimit() : limit;
        if (effectiveLimit > properties.maxLimit()) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_mentor_audit_limit",
                    "mentor audit 查询条数超过上限。",
                    Map.of("maxLimit", properties.maxLimit()));
        }
        return effectiveLimit;
    }

    private String normalizeCorrelationId(String correlationId) {
        if (!hasText(correlationId)) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_mentor_correlation_id",
                    "correlationId 不能为空。",
                    Map.of());
        }
        return correlationId.trim();
    }

    private static boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private record InstallationFilter(String reference, String legacyRaw) {
    }

    public record QueueIncidentView(
            String correlationId,
            String installationId,
            String flagCode,
            String latestPhase,
            String failureCode,
            boolean retryable,
            boolean historicalRateLimited,
            Instant occurredAt
    ) {
    }

    public record AuditDetailView(
            String scope,
            String correlationId,
            String installationId,
            String flagCode,
            String latestPhase,
            String failureCode,
            boolean retryable,
            boolean historicalRateLimited,
            Instant occurredAt,
            RequestEvidence requestEvidence,
            String deliveryState,
            DeliveredResponseEvidence deliveredResponse,
            List<TimelineEventView> timeline,
            LiveRateLimitView liveRateLimit
    ) {
    }

    public record RequestEvidence(String summary) {
    }

    public record DeliveredResponseEvidence(
            String result,
            String phase,
            String responseSummary,
            String responseText,
            boolean blockedFallback,
            String providerMode,
            boolean retryable,
            Instant createdAt
    ) {
    }

    public record TimelineEventView(
            long auditId,
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

    public record LiveRateLimitView(
            boolean limited,
            int currentCount,
            int limit,
            int remaining,
            long windowSeconds
    ) {
    }
}
