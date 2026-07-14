package com.zhangspaghetti.babytalk.practice.catalog;

import com.zhangspaghetti.babytalk.practice.catalog.model.CachedActivity;
import com.zhangspaghetti.babytalk.practice.catalog.model.CachedPhrase;
import com.zhangspaghetti.babytalk.practice.catalog.model.PracticeActivityRow;
import com.zhangspaghetti.babytalk.practice.catalog.model.PracticePhraseRow;
import com.zhangspaghetti.babytalk.practice.catalog.model.PracticeSpaceRow;
import com.zhangspaghetti.babytalk.practice.catalog.model.StarterPhraseSourcePolicy;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PracticeCatalogService {

    private static final int MIN_LIMIT = 1;
    private static final int MAX_LIMIT = 50;

    private final PracticeCatalogMapper mapper;

    public PracticeCatalogService(PracticeCatalogMapper mapper) {
        this.mapper = mapper;
    }

    public Optional<CachedActivity> findActivityBySceneTag(String sceneTagEn) {
        return Optional.ofNullable(mapper.findActivityBySceneTagRow(sceneTagEn));
    }

    public List<CachedPhrase> findPhrasesByActivityId(long activityId) {
        return mapper.findPhrasesByActivityId(activityId);
    }

    public Optional<Long> findSpaceIdBySlug(String slug) {
        return Optional.ofNullable(mapper.findSpaceIdBySlugRow(slug));
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
        return Optional.ofNullable(mapper.findStarterPhraseRow(
                activityId,
                sourcePolicy == StarterPhraseSourcePolicy.SEED_ONLY));
    }

    public Optional<PracticePhraseRow> findNextPhrase(String activityId, String currentPhraseId) {
        return Optional.ofNullable(mapper.findNextPhraseRow(activityId, currentPhraseId));
    }

    public boolean existsSpaceActivityPhrase(String spaceId, String activityId, String phraseId) {
        return mapper.countSpaceActivityPhrasePath(spaceId, activityId, phraseId) > 0;
    }

    @Transactional
    public long insertSpace(String slug, String titleZh) {
        var insertedId = mapper.insertSpaceReturningId(slug, titleZh);
        if (insertedId != null) {
            return insertedId;
        }
        return findSpaceIdBySlug(slug).orElseThrow(() -> new IllegalStateException(
                "practice_spaces insert+lookup failed for slug=" + slug));
    }

    @Transactional
    public long insertActivity(String slug, long spaceId, String titleZh, String sceneTagEn, String coachTip) {
        var insertedId = mapper.insertActivityReturningId(slug, spaceId, titleZh, sceneTagEn, coachTip);
        if (insertedId != null) {
            return insertedId;
        }
        var existingId = mapper.findActivityIdBySlug(slug);
        if (existingId != null) {
            return existingId;
        }
        throw new IllegalStateException("practice_activities insert+lookup failed for slug=" + slug);
    }

    @Transactional
    public long insertPhrase(
            String slug,
            long activityId,
            int step,
            String english,
            String chinese,
            String pronunciation,
            String difficulty
    ) {
        var insertedId = mapper.insertPhraseReturningId(
                slug, activityId, step, english, chinese, pronunciation, difficulty);
        if (insertedId != null) {
            return insertedId;
        }
        var existingId = mapper.findPhraseIdBySlug(slug);
        if (existingId != null) {
            return existingId;
        }
        throw new IllegalStateException("practice_phrases insert+lookup failed for slug=" + slug);
    }

    private int boundLimit(int limit) {
        return Math.max(MIN_LIMIT, Math.min(MAX_LIMIT, limit));
    }
}
