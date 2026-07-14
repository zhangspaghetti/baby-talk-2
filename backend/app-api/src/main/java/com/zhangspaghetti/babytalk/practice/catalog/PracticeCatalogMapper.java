package com.zhangspaghetti.babytalk.practice.catalog;

import com.zhangspaghetti.babytalk.practice.catalog.model.CachedActivity;
import com.zhangspaghetti.babytalk.practice.catalog.model.CachedPhrase;
import com.zhangspaghetti.babytalk.practice.catalog.model.PracticeActivityRow;
import com.zhangspaghetti.babytalk.practice.catalog.model.PracticePhraseRow;
import com.zhangspaghetti.babytalk.practice.catalog.model.PracticeSpaceRow;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface PracticeCatalogMapper {

    CachedActivity findActivityBySceneTagRow(@Param("sceneTagEn") String sceneTagEn);

    List<CachedPhrase> findPhrasesByActivityId(@Param("activityId") long activityId);

    Long findSpaceIdBySlugRow(@Param("slug") String slug);

    List<String> findAllSpaceSlugs();

    Long insertSpaceReturningId(@Param("slug") String slug, @Param("titleZh") String titleZh);

    Long findActivityIdBySlug(@Param("slug") String slug);

    Long insertActivityReturningId(
            @Param("slug") String slug,
            @Param("spaceId") long spaceId,
            @Param("titleZh") String titleZh,
            @Param("sceneTagEn") String sceneTagEn,
            @Param("coachTip") String coachTip
    );

    Long findPhraseIdBySlug(@Param("slug") String slug);

    Long insertPhraseReturningId(
            @Param("slug") String slug,
            @Param("activityId") long activityId,
            @Param("step") int step,
            @Param("english") String english,
            @Param("chinese") String chinese,
            @Param("pronunciation") String pronunciation,
            @Param("difficulty") String difficulty
    );

    List<PracticeSpaceRow> findSpaces(@Param("limit") int limit);

    List<PracticeActivityRow> findActivitiesBySpace(
            @Param("spaceId") String spaceId,
            @Param("limit") int limit
    );

    PracticePhraseRow findStarterPhraseRow(
            @Param("activityId") String activityId,
            @Param("seedOnly") boolean seedOnly
    );

    PracticePhraseRow findNextPhraseRow(
            @Param("activityId") String activityId,
            @Param("currentPhraseId") String currentPhraseId
    );

    int countSpaceActivityPhrasePath(
            @Param("spaceId") String spaceId,
            @Param("activityId") String activityId,
            @Param("phraseId") String phraseId
    );
}
