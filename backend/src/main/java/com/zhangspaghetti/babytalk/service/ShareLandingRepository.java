package com.zhangspaghetti.babytalk.service;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.Optional;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class ShareLandingRepository {

    private final JdbcTemplate jdbcTemplate;

    public ShareLandingRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void insertShareCard(ShareCardRow row) {
        jdbcTemplate.update(
                """
                insert into share_landing_cards (
                    token,
                    source,
                    headline,
                    story_text,
                    phrase_text,
                    phrase_translation,
                    recommendation_title,
                    recommendation_reason,
                    space_id,
                    activity_id,
                    platform_hint,
                    created_at,
                    expires_at
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                row.token(),
                row.source(),
                row.headline(),
                row.storyText(),
                row.phraseText(),
                row.phraseTranslation(),
                row.recommendationTitle(),
                row.recommendationReason(),
                row.spaceId(),
                row.activityId(),
                row.platformHint(),
                Timestamp.from(row.createdAt()),
                Timestamp.from(row.expiresAt())
        );
    }

    public Optional<ShareCardRow> findByToken(String token) {
        try {
            return Optional.ofNullable(jdbcTemplate.queryForObject(
                    """
                    select token,
                           source,
                           headline,
                           story_text,
                           phrase_text,
                           phrase_translation,
                           recommendation_title,
                           recommendation_reason,
                           space_id,
                           activity_id,
                           platform_hint,
                           created_at,
                           expires_at
                    from share_landing_cards
                    where token = ?
                    """,
                    this::mapShareCard,
                    token
            ));
        } catch (EmptyResultDataAccessException exception) {
            return Optional.empty();
        }
    }

    public void insertEvent(EventRow row) {
        jdbcTemplate.update(
                """
                insert into share_landing_events (
                    token,
                    source,
                    entrypoint,
                    platform,
                    result,
                    failure_reason,
                    created_at
                ) values (?, ?, ?, ?, ?, ?, ?)
                """,
                row.token(),
                row.source(),
                row.entrypoint(),
                row.platform(),
                row.result(),
                row.failureReason(),
                Timestamp.from(row.createdAt())
        );
    }

    private ShareCardRow mapShareCard(ResultSet rs, int rowNum) throws SQLException {
        return new ShareCardRow(
                rs.getString("token"),
                rs.getString("source"),
                rs.getString("headline"),
                rs.getString("story_text"),
                rs.getString("phrase_text"),
                rs.getString("phrase_translation"),
                rs.getString("recommendation_title"),
                rs.getString("recommendation_reason"),
                rs.getString("space_id"),
                rs.getString("activity_id"),
                rs.getString("platform_hint"),
                rs.getTimestamp("created_at").toInstant(),
                rs.getTimestamp("expires_at").toInstant()
        );
    }

    public record ShareCardRow(
            String token,
            String source,
            String headline,
            String storyText,
            String phraseText,
            String phraseTranslation,
            String recommendationTitle,
            String recommendationReason,
            String spaceId,
            String activityId,
            String platformHint,
            Instant createdAt,
            Instant expiresAt
    ) {
    }

    public record EventRow(
            String token,
            String source,
            String entrypoint,
            String platform,
            String result,
            String failureReason,
            Instant createdAt
    ) {
    }
}
