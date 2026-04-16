package com.zhangspaghetti.babytalk.service;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class DistributionRepository {

    private final JdbcTemplate jdbcTemplate;

    public DistributionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void insertEvent(EventRow row) {
        jdbcTemplate.update(
                """
                insert into release_distribution_events (
                    entrypoint,
                    release_channel,
                    source,
                    platform,
                    result,
                    failure_reason,
                    created_at
                ) values (?, ?, ?, ?, ?, ?, ?)
                """,
                row.entrypoint(),
                row.releaseChannel(),
                row.source(),
                row.platform(),
                row.result(),
                row.failureReason(),
                Timestamp.from(row.createdAt())
        );
    }

    public List<EventRow> listRecentEvents() {
        return jdbcTemplate.query(
                """
                select entrypoint, release_channel, source, platform, result, failure_reason, created_at
                from release_distribution_events
                order by event_id asc
                """,
                (rs, rowNum) -> mapEvent(rs)
        );
    }

    private EventRow mapEvent(ResultSet rs) throws SQLException {
        return new EventRow(
                rs.getString("entrypoint"),
                rs.getString("release_channel"),
                rs.getString("source"),
                rs.getString("platform"),
                rs.getString("result"),
                rs.getString("failure_reason"),
                rs.getTimestamp("created_at").toInstant()
        );
    }

    public record EventRow(
            String entrypoint,
            String releaseChannel,
            String source,
            String platform,
            String result,
            String failureReason,
            Instant createdAt
    ) {
    }
}
