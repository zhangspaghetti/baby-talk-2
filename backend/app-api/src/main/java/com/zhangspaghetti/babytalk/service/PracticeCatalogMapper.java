package com.zhangspaghetti.babytalk.service;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface PracticeCatalogMapper {

    PracticeCatalogRepository.CachedActivity findActivityBySceneTag(@Param("sceneTagEn") String sceneTagEn);

    List<PracticeCatalogRepository.CachedPhrase> findPhrasesByActivityId(@Param("activityId") long activityId);

    Long findSpaceIdBySlug(@Param("slug") String slug);

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

    List<PracticeCatalogRepository.PracticeSpaceRow> findSpaces(@Param("limit") int limit);

    List<PracticeCatalogRepository.PracticeActivityRow> findActivitiesBySpace(
            @Param("spaceId") String spaceId,
            @Param("limit") int limit
    );

    PracticeCatalogRepository.PracticePhraseRow findStarterPhrase(@Param("activityId") String activityId);

    PracticeCatalogRepository.PracticePhraseRow findNextPhrase(
            @Param("activityId") String activityId,
            @Param("currentPhraseId") String currentPhraseId
    );

    int countSpaceActivityPhrasePath(
            @Param("spaceId") String spaceId,
            @Param("activityId") String activityId,
            @Param("phraseId") String phraseId
    );
}
