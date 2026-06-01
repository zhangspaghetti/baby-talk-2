package com.zhangspaghetti.babytalk.service;

import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

@Repository
public class PracticeCatalogRepository {

    private final JdbcTemplate jdbc;

    public PracticeCatalogRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // ─── Lookup methods ───────────────────────────────────────────────────

    public Optional<CachedActivity> findActivityBySceneTag(String sceneTagEn) {
        var rows = jdbc.query(
                """
                SELECT a.id, a.slug, s.slug AS space_slug, a.title_zh, a.coach_tip
                FROM practice_activities a
                JOIN practice_spaces s ON s.id = a.space_id
                WHERE a.scene_tag_en = ?
                LIMIT 1
                """,
                (rs, n) -> new CachedActivity(
                        rs.getLong("id"),
                        rs.getString("slug"),
                        rs.getString("space_slug"),
                        rs.getString("title_zh"),
                        rs.getString("coach_tip")
                ),
                sceneTagEn
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public List<CachedPhrase> findPhrasesByActivityId(long activityId) {
        return jdbc.query(
                """
                SELECT id, slug, step, english, chinese, pronunciation, difficulty
                FROM practice_phrases
                WHERE activity_id = ?
                ORDER BY step
                """,
                (rs, n) -> new CachedPhrase(
                        rs.getLong("id"),
                        rs.getString("slug"),
                        rs.getInt("step"),
                        rs.getString("english"),
                        rs.getString("chinese"),
                        rs.getString("pronunciation"),
                        rs.getString("difficulty")
                ),
                activityId
        );
    }

    public Optional<Long> findSpaceIdBySlug(String slug) {
        var ids = jdbc.queryForList(
                "SELECT id FROM practice_spaces WHERE slug = ?",
                Long.class,
                slug
        );
        return ids.isEmpty() ? Optional.empty() : Optional.of(ids.get(0));
    }

    public List<String> findAllSpaceSlugs() {
        return jdbc.queryForList(
                "SELECT slug FROM practice_spaces ORDER BY sort_order",
                String.class
        );
    }

    // ─── Write methods (all @Transactional) ───────────────────────────────

    @Transactional
    public long insertSpace(String slug, String titleZh) {
        var keys = jdbc.queryForList(
                """
                INSERT INTO practice_spaces (slug, title_zh)
                VALUES (?, ?)
                ON CONFLICT (slug) DO NOTHING
                RETURNING id
                """,
                Long.class,
                slug, titleZh
        );
        if (!keys.isEmpty()) {
            return keys.get(0);
        }
        return findSpaceIdBySlug(slug)
                .orElseThrow(() -> new IllegalStateException(
                        "practice_spaces insert+lookup failed for slug=" + slug));
    }

    @Transactional
    public long insertActivity(String slug, long spaceId, String titleZh,
                               String sceneTagEn, String coachTip) {
        var keys = jdbc.queryForList(
                """
                INSERT INTO practice_activities (slug, space_id, title_zh, scene_tag_en, coach_tip, source)
                VALUES (?, ?, ?, ?, ?, 'llm')
                ON CONFLICT (slug) DO NOTHING
                RETURNING id
                """,
                Long.class,
                slug, spaceId, titleZh, sceneTagEn, coachTip
        );
        if (!keys.isEmpty()) {
            return keys.get(0);
        }
        // Conflict on slug — fetch existing id
        var existing = jdbc.queryForList(
                "SELECT id FROM practice_activities WHERE slug = ?",
                Long.class, slug
        );
        if (!existing.isEmpty()) {
            return existing.get(0);
        }
        throw new IllegalStateException(
                "practice_activities insert+lookup failed for slug=" + slug);
    }

    @Transactional
    public long insertPhrase(String slug, long activityId, int step,
                             String english, String chinese,
                             String pronunciation, String difficulty) {
        var keys = jdbc.queryForList(
                """
                INSERT INTO practice_phrases (slug, activity_id, step, english, chinese, pronunciation, difficulty, source)
                VALUES (?, ?, ?, ?, ?, ?, ?, 'llm')
                ON CONFLICT (slug) DO NOTHING
                RETURNING id
                """,
                Long.class,
                slug, activityId, step, english, chinese, pronunciation, difficulty
        );
        if (!keys.isEmpty()) {
            return keys.get(0);
        }
        var existing = jdbc.queryForList(
                "SELECT id FROM practice_phrases WHERE slug = ?",
                Long.class, slug
        );
        if (!existing.isEmpty()) {
            return existing.get(0);
        }
        throw new IllegalStateException(
                "practice_phrases insert+lookup failed for slug=" + slug);
    }

    // ─── Records ──────────────────────────────────────────────────────────

    public record CachedActivity(
            long id,
            String slug,
            String spaceSlug,
            String titleZh,
            String coachTip
    ) {
    }

    public record CachedPhrase(
            long id,
            String slug,
            int step,
            String english,
            String chinese,
            String pronunciation,
            String difficulty
    ) {
    }
}
