package com.zhangspaghetti.babytalk.admin.practice;

import java.time.OffsetDateTime;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface AdminPresetSceneMapper {

    List<AdminPresetSceneRepository.SceneSummaryRow> findScenes();

    AdminPresetSceneRepository.SceneDetailRow findScene(@Param("presetSceneId") String presetSceneId);

    AdminPresetSceneRepository.DraftRow findDraftForUpdate(
            @Param("presetSceneId") String presetSceneId
    );

    AdminPresetSceneRepository.DraftRow findDraft(
            @Param("presetSceneId") String presetSceneId
    );

    AdminPresetSceneRepository.DraftRow createDraft(
            @Param("presetSceneId") String presetSceneId,
            @Param("write") AdminPresetSceneRepository.DraftWrite write,
            @Param("adminId") String adminId,
            @Param("now") OffsetDateTime now
    );

    AdminPresetSceneRepository.DraftRow updateDraft(
            @Param("presetSceneId") String presetSceneId,
            @Param("expectedLockVersion") int expectedLockVersion,
            @Param("write") AdminPresetSceneRepository.DraftWrite write,
            @Param("adminId") String adminId,
            @Param("now") OffsetDateTime now
    );

    Long lockActivityForUpdate(@Param("presetSceneId") String presetSceneId);

    Integer findNextPublishedVersion(@Param("activityId") long activityId);

    Long findPublishedVersionId(
            @Param("presetSceneId") String presetSceneId,
            @Param("sourceVersion") int sourceVersion
    );

    AdminPresetSceneRepository.PublishedRow publishDraft(
            @Param("presetSceneId") String presetSceneId,
            @Param("expectedLockVersion") int expectedLockVersion,
            @Param("nextVersion") int nextVersion,
            @Param("adminId") String adminId,
            @Param("now") OffsetDateTime now
    );

    int updateCurrentPublishedVersion(
            @Param("activityId") long activityId,
            @Param("versionId") long versionId
    );

    AdminPresetSceneRepository.DraftRow copyPublishedToDraft(
            @Param("presetSceneId") String presetSceneId,
            @Param("sourceVersion") int sourceVersion,
            @Param("adminId") String adminId,
            @Param("now") OffsetDateTime now
    );

    AdminPresetSceneRepository.PublishedRow rollbackPublished(
            @Param("presetSceneId") String presetSceneId,
            @Param("sourceVersion") int sourceVersion,
            @Param("nextVersion") int nextVersion,
            @Param("adminId") String adminId,
            @Param("now") OffsetDateTime now
    );

    List<AdminPresetSceneRepository.PublishedRow> findVersions(
            @Param("presetSceneId") String presetSceneId
    );

    int insertAudit(
            @Param("activityId") long activityId,
            @Param("action") String action,
            @Param("sourceVersionId") Long sourceVersionId,
            @Param("targetVersionId") Long targetVersionId,
            @Param("adminId") String adminId,
            @Param("changeSummary") String changeSummary,
            @Param("now") OffsetDateTime now
    );
}
