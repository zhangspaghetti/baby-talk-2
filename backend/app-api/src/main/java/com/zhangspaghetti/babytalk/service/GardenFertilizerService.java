package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.garden.mapper.GardenFertilizerMapper;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.sql.SQLException;
import java.time.Instant;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GardenFertilizerService {

    private final GardenFertilizerMapper mapper;

    public GardenFertilizerService(GardenFertilizerMapper mapper) {
        this.mapper = mapper;
    }

    @Transactional(readOnly = true)
    public FertilizerStateResponse getState(String userId) {
        return loadStateOrVirtual(userId);
    }

    @Transactional
    public ClaimResponse claim(String userId, String eventKey, String requestId, Instant clientTime) {
        ensureStateRow(userId);
        var claimedAt = clientTime == null ? Instant.now() : clientTime;

        if (existsClaimByRequestId(userId, requestId)) {
            var state = loadStateOrVirtual(userId);
            return new ClaimResponse(
                    state.availableCount(),
                    state.appliedCount(),
                    state.lastClaimedAt(),
                    state.lastAppliedAt(),
                    state.version(),
                    true
            );
        }

        try {
            mapper.insertClaim(userId, eventKey, requestId, claimedAt);
            mapper.updateLastClaimed(userId, claimedAt);
        } catch (DataAccessException exception) {
            if (!isUniqueViolation(exception)) {
                throw exception;
            }
            throw new ContractException(
                    HttpStatus.CONFLICT,
                    "fertilizer_claim_conflict",
                    "该 eventKey 已被领取。",
                    java.util.Map.of("eventKey", eventKey)
            );
        }

        var state = loadStateOrVirtual(userId);
        return new ClaimResponse(
                state.availableCount(),
                state.appliedCount(),
                state.lastClaimedAt(),
                state.lastAppliedAt(),
                state.version(),
                false
        );
    }

    @Transactional
    public ApplyResponse apply(String userId, String requestId, Instant clientTime) {
        ensureStateRow(userId);
        var appliedAt = clientTime == null ? Instant.now() : clientTime;

        int inserted = mapper.insertApply(userId, requestId, appliedAt);

        if (inserted == 0) {
            var state = loadStateOrVirtual(userId);
            return new ApplyResponse(
                    state.availableCount(),
                    state.appliedCount(),
                    state.lastClaimedAt(),
                    state.lastAppliedAt(),
                    state.version(),
                    true
            );
        }

        int updated = mapper.applyOne(userId, appliedAt);

        if (updated == 0) {
            throw new ContractException(
                    HttpStatus.CONFLICT,
                    "fertilizer_insufficient",
                    "可用肥料不足，无法执行 apply。"
            );
        }

        var state = loadStateOrVirtual(userId);
        return new ApplyResponse(
                state.availableCount(),
                state.appliedCount(),
                state.lastClaimedAt(),
                state.lastAppliedAt(),
                state.version(),
                false
        );
    }

    private boolean existsClaimByRequestId(String userId, String requestId) {
        return mapper.countClaimsByRequestId(userId, requestId) > 0;
    }

    private void ensureStateRow(String userId) {
        mapper.ensureStateRow(userId);
    }

    private FertilizerStateResponse loadStateOrVirtual(String userId) {
        var state = mapper.findState(userId);
        if (state != null) {
            return new FertilizerStateResponse(
                    Math.max(state.claimCount() - state.appliedCount(), 0),
                    state.appliedCount(),
                    state.lastClaimedAt(),
                    state.lastAppliedAt(),
                    state.version()
            );
        }

        return new FertilizerStateResponse(mapper.countClaims(userId), 0, null, null, 0L);
    }

    private boolean isUniqueViolation(DataAccessException exception) {
        if (exception instanceof DataIntegrityViolationException) {
            return true;
        }
        Throwable cause = exception.getCause();
        while (cause != null) {
            if (cause instanceof SQLException sqlException) {
                if ("23505".equals(sqlException.getSQLState())) {
                    return true;
                }
            }
            cause = cause.getCause();
        }
        return false;
    }

    public record FertilizerStateResponse(
            int availableCount,
            int appliedCount,
            Instant lastClaimedAt,
            Instant lastAppliedAt,
            long version
    ) {
    }

    public record ClaimResponse(
            int availableCount,
            int appliedCount,
            Instant lastClaimedAt,
            Instant lastAppliedAt,
            long version,
            boolean idempotent
    ) {
    }

    public record ApplyResponse(
            int availableCount,
            int appliedCount,
            Instant lastClaimedAt,
            Instant lastAppliedAt,
            long version,
            boolean idempotent
    ) {
    }
}
