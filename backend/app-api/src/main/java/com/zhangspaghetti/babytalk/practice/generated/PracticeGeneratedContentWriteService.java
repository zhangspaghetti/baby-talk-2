package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import java.time.OffsetDateTime;
import java.util.Optional;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
class PracticeGeneratedContentWriteService {

    private final PracticeGeneratedContentMapper mapper;

    PracticeGeneratedContentWriteService(PracticeGeneratedContentMapper mapper) {
        this.mapper = mapper;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public PracticeGeneratedContentService.DraftReservation reserveDraft(
            PracticeGeneratedContentEntity entity,
            ReservationPolicy policy
    ) {
        mapper.lockOwnerRateLimit(entity.ownerKeyVersion() + ":" + entity.ownerKey());
        try {
            var existing = mapper.findLiveByFingerprint(
                    entity.ownerKey(), entity.ownerKeyVersion(), entity.surface(), entity.mode(),
                    entity.requestFingerprint(), entity.promptVersion(), entity.strategyVersion(), entity.policyVersion());
            if (isDueInstallationActive(existing, policy.now())) {
                mapper.expireDueInstallationActive(
                        existing.generatedContentId(), entity.ownerKeyVersion(), policy.now());
                existing = mapper.findLiveByFingerprint(
                        entity.ownerKey(), entity.ownerKeyVersion(), entity.surface(), entity.mode(),
                        entity.requestFingerprint(), entity.promptVersion(), entity.strategyVersion(), entity.policyVersion());
            }
            if (existing != null && !isStaleDraft(existing, policy.now())) {
                return new PracticeGeneratedContentService.DraftReservation(existing, false);
            }

            enforceRateLimit(entity, policy);
            if (existing != null) {
                mapper.expireDraft(
                        existing.generatedContentId(),
                        "draft_expired",
                        policy.now(),
                        policy.expiredRetentionExpiresAt());
            }

            var inserted = mapper.insertDraftIgnoringLiveConflict(entity);
            if (inserted != null) {
                return new PracticeGeneratedContentService.DraftReservation(inserted, true);
            }
            var conflicted = mapper.findLiveByFingerprint(
                    entity.ownerKey(), entity.ownerKeyVersion(), entity.surface(), entity.mode(),
                    entity.requestFingerprint(), entity.promptVersion(), entity.strategyVersion(), entity.policyVersion());
            if (conflicted != null) {
                return new PracticeGeneratedContentService.DraftReservation(conflicted, false);
            }
        } catch (DuplicateKeyException exception) {
            throw new PracticeGeneratedContentService.GeneratedContentIdConflictException(entity.generatedContentId(), exception);
        }
        throw new IllegalStateException("practice generated content reservation conflict could not be loaded");
    }

    private void enforceRateLimit(PracticeGeneratedContentEntity entity, ReservationPolicy policy) {
        var burstAttempts = mapper.countRecentGenerationAttempts(
                entity.ownerKey(), entity.ownerKeyVersion(), entity.surface(), entity.mode(), policy.burstFrom());
        if (burstAttempts >= policy.burstLimit()) {
            throw new RateLimitExceededException("burst", policy.burstLimit());
        }
        var dailyAttempts = mapper.countRecentGenerationAttempts(
                entity.ownerKey(), entity.ownerKeyVersion(), entity.surface(), entity.mode(), policy.dailyFrom());
        if (dailyAttempts >= policy.dailyLimit()) {
            throw new RateLimitExceededException("daily", policy.dailyLimit());
        }
    }

    private boolean isStaleDraft(PracticeGeneratedContentEntity entity, OffsetDateTime now) {
        return "draft".equals(entity.status())
                && entity.generationExpiresAt() != null
                && !entity.generationExpiresAt().isAfter(now);
    }

    private boolean isDueInstallationActive(PracticeGeneratedContentEntity entity, OffsetDateTime now) {
        return entity != null
                && "installation".equals(entity.ownerScope())
                && "active".equals(entity.status())
                && entity.retentionExpiresAt() != null
                && !entity.retentionExpiresAt().isAfter(now);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Optional<PracticeGeneratedContentEntity> activateDraft(PracticeGeneratedContentEntity entity) {
        return mapper.activateDraft(entity) == 1
                ? Optional.ofNullable(mapper.findActiveOrPromotedByGeneratedContentId(
                        entity.generatedContentId(), entity.ownerKeyVersion(), entity.updatedAt()))
                : Optional.empty();
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void rejectDraft(
            String generatedContentId,
            String errorCode,
            OffsetDateTime updatedAt,
            OffsetDateTime retentionExpiresAt
    ) {
        mapper.rejectDraft(generatedContentId, errorCode, updatedAt, retentionExpiresAt);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void expireDraft(
            String generatedContentId,
            String errorCode,
            OffsetDateTime updatedAt,
            OffsetDateTime retentionExpiresAt
    ) {
        mapper.expireDraft(generatedContentId, errorCode, updatedAt, retentionExpiresAt);
    }

    record ReservationPolicy(
            OffsetDateTime now,
            OffsetDateTime burstFrom,
            int burstLimit,
            OffsetDateTime dailyFrom,
            int dailyLimit,
            OffsetDateTime expiredRetentionExpiresAt
    ) {
    }

    static final class RateLimitExceededException extends RuntimeException {
        private final String windowName;
        private final int limit;

        RateLimitExceededException(String windowName, int limit) {
            super(windowName);
            this.windowName = windowName;
            this.limit = limit;
        }

        String windowName() {
            return windowName;
        }

        int limit() {
            return limit;
        }
    }
}
