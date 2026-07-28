package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity;
import java.time.OffsetDateTime;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface PracticeGeneratedContentQueryMapper {

    PracticeGeneratedContentEntity findByGeneratedContentId(
            @Param("generatedContentId") String generatedContentId);

    List<PracticeGeneratedContentUtteranceEntity> findApprovedUtterances(
            @Param("generatedContentId") String generatedContentId);

    PracticeGeneratedContentEntity findByClientRequestId(
            @Param("ownerScope") String ownerScope,
            @Param("ownerKey") String ownerKey,
            @Param("ownerKeyVersion") String ownerKeyVersion,
            @Param("clientRequestId") String clientRequestId);

    PracticeGeneratedContentEntity findLiveByFingerprint(
            @Param("ownerKey") String ownerKey,
            @Param("ownerKeyVersion") String ownerKeyVersion,
            @Param("surface") String surface,
            @Param("mode") String mode,
            @Param("requestFingerprint") String requestFingerprint,
            @Param("generationProfileVersion") String generationProfileVersion,
            @Param("contentRefreshEpoch") int contentRefreshEpoch);

    PracticeGeneratedContentEntity findActiveByGeneratedContentId(
            @Param("generatedContentId") String generatedContentId,
            @Param("ownerKeyVersion") String ownerKeyVersion,
            @Param("reusableAt") OffsetDateTime reusableAt);

    PracticeGeneratedContentEntity findActiveByFingerprint(
            @Param("ownerKey") String ownerKey,
            @Param("ownerKeyVersion") String ownerKeyVersion,
            @Param("surface") String surface,
            @Param("mode") String mode,
            @Param("requestFingerprint") String requestFingerprint,
            @Param("generationProfileVersion") String generationProfileVersion,
            @Param("contentRefreshEpoch") int contentRefreshEpoch,
            @Param("reusableAt") OffsetDateTime reusableAt);

    int countRecentDraftReservations(
            @Param("ownerKey") String ownerKey,
            @Param("ownerKeyVersion") String ownerKeyVersion,
            @Param("surface") String surface,
            @Param("mode") String mode,
            @Param("createdAtFrom") OffsetDateTime createdAtFrom);

    List<PracticeGeneratedContentEntity> findInstallationCleanupCandidates(
            @Param("ownerKeyVersion") String ownerKeyVersion,
            @Param("installationRefHash") String installationRefHash,
            @Param("retentionExpiresAtOrBefore") OffsetDateTime retentionExpiresAtOrBefore,
            @Param("limit") int limit);
}
