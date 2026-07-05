package com.zhangspaghetti.babytalk.service;

import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

@Repository
public class PracticeCatalogRepository {

    private static final int MIN_LIMIT = 1;
    private static final int MAX_LIMIT = 50;

    private final PracticeCatalogMapper mapper;

    public PracticeCatalogRepository(PracticeCatalogMapper mapper) {
        this.mapper = mapper;
    }

    // ─── Lookup methods ───────────────────────────────────────────────────

    public Optional<CachedActivity> findActivityBySceneTag(String sceneTagEn) {
        return Optional.ofNullable(mapper.findActivityBySceneTag(sceneTagEn));
    }

    public List<CachedPhrase> findPhrasesByActivityId(long activityId) {
        return mapper.findPhrasesByActivityId(activityId);
    }

    public Optional<Long> findSpaceIdBySlug(String slug) {
        return Optional.ofNullable(mapper.findSpaceIdBySlug(slug));
    }

    public List<String> findAllSpaceSlugs() {
        return mapper.findAllSpaceSlugs();
    }

    public List<PracticeSpaceRow> findSpaces(String locale, int limit) {
        return mapper.findSpaces(boundLimit(limit));
    }

    public List<PracticeActivityRow> findActivitiesBySpace(String spaceId, String locale, int limit) {
        return mapper.findActivitiesBySpace(spaceId, boundLimit(limit));
    }

    public Optional<PracticePhraseRow> findStarterPhrase(String activityId, String locale) {
        return findStarterPhrase(activityId, locale, StarterPhraseSourcePolicy.ANY_SOURCE);
    }

    public Optional<PracticePhraseRow> findStarterPhrase(
            String activityId,
            String locale,
            StarterPhraseSourcePolicy sourcePolicy
    ) {
        var seedOnly = sourcePolicy == StarterPhraseSourcePolicy.SEED_ONLY;
        return Optional.ofNullable(mapper.findStarterPhrase(activityId, seedOnly));
    }

    public Optional<PracticePhraseRow> findNextPhrase(String activityId, String currentPhraseId) {
        return Optional.ofNullable(mapper.findNextPhrase(activityId, currentPhraseId));
    }

    public boolean existsSpaceActivityPhrase(String spaceId, String activityId, String phraseId) {
        return mapper.countSpaceActivityPhrasePath(spaceId, activityId, phraseId) > 0;
    }

    // ─── Write methods (all @Transactional) ───────────────────────────────

    @Transactional
    public long insertSpace(String slug, String titleZh) {
        var insertedId = mapper.insertSpaceReturningId(slug, titleZh);
        if (insertedId != null) {
            return insertedId;
        }
        return findSpaceIdBySlug(slug)
                .orElseThrow(() -> new IllegalStateException(
                        "practice_spaces insert+lookup failed for slug=" + slug));
    }

    @Transactional
    public long insertActivity(String slug, long spaceId, String titleZh,
                               String sceneTagEn, String coachTip) {
        var insertedId = mapper.insertActivityReturningId(slug, spaceId, titleZh, sceneTagEn, coachTip);
        if (insertedId != null) {
            return insertedId;
        }
        var existingId = mapper.findActivityIdBySlug(slug);
        if (existingId != null) {
            return existingId;
        }
        throw new IllegalStateException(
                "practice_activities insert+lookup failed for slug=" + slug);
    }

    @Transactional
    public long insertPhrase(String slug, long activityId, int step,
                             String english, String chinese,
                             String pronunciation, String difficulty) {
        var insertedId = mapper.insertPhraseReturningId(
                slug, activityId, step, english, chinese, pronunciation, difficulty);
        if (insertedId != null) {
            return insertedId;
        }
        var existingId = mapper.findPhraseIdBySlug(slug);
        if (existingId != null) {
            return existingId;
        }
        throw new IllegalStateException(
                "practice_phrases insert+lookup failed for slug=" + slug);
    }

    private int boundLimit(int limit) {
        return Math.max(MIN_LIMIT, Math.min(MAX_LIMIT, limit));
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

    public record PracticeSpaceRow(
            long id,
            String spaceId,
            String titleZh,
            String descriptionZh,
            int sortOrder
    ) {
    }

    public record PracticeActivityRow(
            long id,
            String activityId,
            String spaceId,
            String titleZh,
            String sceneTagEn,
            String coachTip,
            int sortOrder,
            String source
    ) {
    }

    public record PracticePhraseRow(
            long id,
            String phraseId,
            String activityId,
            int step,
            String english,
            String chinese,
            String pronunciation,
            String difficulty,
            String audioAsset,
            String source
    ) {
    }

    public enum StarterPhraseSourcePolicy {
        ANY_SOURCE,
        SEED_ONLY
    }
}
