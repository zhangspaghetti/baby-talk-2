package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.web.ContractException;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GardenFertilizerService {

    private final JdbcTemplate jdbcTemplate;

    public GardenFertilizerService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
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
            jdbcTemplate.update(
                    """
                    insert into garden_fertilizer_claim_log(user_id, event_key, request_id, claimed_at)
                    values (?, ?, ?, ?)
                    """,
                    userId,
                    eventKey,
                    requestId,
                    Timestamp.from(claimedAt)
            );
            jdbcTemplate.update(
                    """
                    update garden_fertilizer_state
                    set last_claimed_at = ?,
                        updated_at = now(),
                        version = version + 1
                    where user_id = ?
                    """,
                    Timestamp.from(claimedAt),
                    userId
            );
        } catch (DataIntegrityViolationException exception) {
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

        int inserted = jdbcTemplate.update(
                """
                insert into garden_fertilizer_apply_log(user_id, request_id, delta, applied_at)
                values (?, ?, 1, ?)
                on conflict do nothing
                """,
                userId,
                requestId,
                Timestamp.from(appliedAt)
        );

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

        int updated = jdbcTemplate.update(
                """
                update garden_fertilizer_state s
                set applied_count = s.applied_count + 1,
                    last_applied_at = ?,
                    updated_at = now(),
                    version = s.version + 1
                where s.user_id = ?
                  and ((select count(*) from garden_fertilizer_claim_log c where c.user_id = s.user_id) - s.applied_count) > 0
                """,
                Timestamp.from(appliedAt),
                userId
        );

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
        Integer count = jdbcTemplate.queryForObject(
                """
                select count(*)
                from garden_fertilizer_claim_log
                where user_id = ? and request_id = ?
                """,
                Integer.class,
                userId,
                requestId
        );
        return count != null && count > 0;
    }

    private void ensureStateRow(String userId) {
        jdbcTemplate.update(
                """
                insert into garden_fertilizer_state(user_id)
                values (?)
                on conflict (user_id) do nothing
                """,
                userId
        );
    }

    private FertilizerStateResponse loadStateOrVirtual(String userId) {
        List<FertilizerStateResponse> states = jdbcTemplate.query(
                """
                select s.applied_count,
                       s.last_claimed_at,
                       s.last_applied_at,
                       s.version,
                       coalesce((select count(*) from garden_fertilizer_claim_log c where c.user_id = s.user_id), 0) as claim_count
                from garden_fertilizer_state s
                where s.user_id = ?
                """,
                this::mapState,
                userId
        );
        if (!states.isEmpty()) {
            return states.get(0);
        }

        Integer claimCount = jdbcTemplate.queryForObject(
                """
                select count(*)
                from garden_fertilizer_claim_log
                where user_id = ?
                """,
                Integer.class,
                userId
        );
        int available = claimCount == null ? 0 : claimCount;
        return new FertilizerStateResponse(available, 0, null, null, 0L);
    }

    private FertilizerStateResponse mapState(ResultSet rs, int rowNum) throws SQLException {
        int appliedCount = rs.getInt("applied_count");
        int claimCount = rs.getInt("claim_count");
        var lastClaimedAt = toInstant(rs.getTimestamp("last_claimed_at"));
        var lastAppliedAt = toInstant(rs.getTimestamp("last_applied_at"));
        long version = rs.getLong("version");
        return new FertilizerStateResponse(
                Math.max(claimCount - appliedCount, 0),
                appliedCount,
                lastClaimedAt,
                lastAppliedAt,
                version
        );
    }

    private Instant toInstant(Timestamp timestamp) {
        return timestamp == null ? null : timestamp.toInstant();
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
