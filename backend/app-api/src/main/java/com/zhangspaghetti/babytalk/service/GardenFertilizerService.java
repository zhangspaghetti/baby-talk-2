package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.web.ContractException;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
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
        ensureStateRow(userId);
        return loadState(userId);
    }

    @Transactional
    public ClaimResponse claim(String userId, String eventKey, String requestId, Instant clientTime) {
        ensureStateRow(userId);
        var claimedAt = clientTime == null ? Instant.now() : clientTime;

        int inserted = jdbcTemplate.update(
                """
                insert into garden_fertilizer_claim_log(user_id, event_key, request_id, claimed_at)
                values (?, ?, ?, ?)
                on conflict do nothing
                """,
                userId,
                eventKey,
                requestId,
                Timestamp.from(claimedAt)
        );

        if (inserted > 0) {
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
        }

        var state = loadState(userId);
        return new ClaimResponse(
                state.availableCount(),
                state.appliedCount(),
                state.lastClaimedAt(),
                state.lastAppliedAt(),
                state.version(),
                inserted == 0
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
            var state = loadState(userId);
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

        var state = loadState(userId);
        return new ApplyResponse(
                state.availableCount(),
                state.appliedCount(),
                state.lastClaimedAt(),
                state.lastAppliedAt(),
                state.version(),
                false
        );
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

    private FertilizerStateResponse loadState(String userId) {
        return jdbcTemplate.queryForObject(
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
