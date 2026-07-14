package com.zhangspaghetti.babytalk.practice.generated;

import com.baomidou.mybatisplus.core.toolkit.Constants;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import java.time.OffsetDateTime;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface PracticeGeneratedContentMapper {

    int insertRow(@Param(Constants.ENTITY) PracticeGeneratedContentEntity entity);

    PracticeGeneratedContentEntity insertDraftIgnoringLiveConflict(
            @Param(Constants.ENTITY) PracticeGeneratedContentEntity entity);

    int lockOwnerRateLimit(@Param("ownerLockKey") String ownerLockKey);

    PracticeGeneratedContentEntity findLiveByFingerprint(
            @Param("ownerKey") String ownerKey,
            @Param("ownerKeyVersion") String ownerKeyVersion,
            @Param("surface") String surface,
            @Param("mode") String mode,
            @Param("requestFingerprint") String requestFingerprint,
            @Param("promptVersion") String promptVersion,
            @Param("strategyVersion") String strategyVersion,
            @Param("policyVersion") String policyVersion
    );

    int activateDraft(@Param(Constants.ENTITY) PracticeGeneratedContentEntity entity);

    int rejectDraft(
            @Param("generatedContentId") String generatedContentId,
            @Param("generationErrorCode") String generationErrorCode,
            @Param("updatedAt") OffsetDateTime updatedAt,
            @Param("retentionExpiresAt") OffsetDateTime retentionExpiresAt
    );

    int expireDraft(
            @Param("generatedContentId") String generatedContentId,
            @Param("generationErrorCode") String generationErrorCode,
            @Param("updatedAt") OffsetDateTime updatedAt,
            @Param("retentionExpiresAt") OffsetDateTime retentionExpiresAt
    );

    int expireDueInstallationActive(
            @Param("generatedContentId") String generatedContentId,
            @Param("ownerKeyVersion") String ownerKeyVersion,
            @Param("updatedAt") OffsetDateTime updatedAt
    );

    PracticeGeneratedContentEntity findActiveOrPromotedByGeneratedContentId(
            @Param("generatedContentId") String generatedContentId,
            @Param("ownerKeyVersion") String ownerKeyVersion,
            @Param("reusableAt") OffsetDateTime reusableAt);

    PracticeGeneratedContentEntity findActiveOrPromotedByFingerprint(
            @Param("ownerKey") String ownerKey,
            @Param("ownerKeyVersion") String ownerKeyVersion,
            @Param("surface") String surface,
            @Param("mode") String mode,
            @Param("requestFingerprint") String requestFingerprint,
            @Param("promptVersion") String promptVersion,
            @Param("strategyVersion") String strategyVersion,
            @Param("policyVersion") String policyVersion,
            @Param("reusableAt") OffsetDateTime reusableAt
    );

    int countRecentGenerationAttempts(
            @Param("ownerKey") String ownerKey,
            @Param("ownerKeyVersion") String ownerKeyVersion,
            @Param("surface") String surface,
            @Param("mode") String mode,
            @Param("createdAtFrom") OffsetDateTime createdAtFrom
    );

    List<PracticeGeneratedContentEntity> findInstallationCleanupCandidates(
            @Param("ownerKeyVersion") String ownerKeyVersion,
            @Param("installationRefHash") String installationRefHash,
            @Param("retentionExpiresAtOrBefore") OffsetDateTime retentionExpiresAtOrBefore,
            @Param("limit") int limit
    );

    int deleteExpiredInstallationRows(
            @Param("retentionExpiresAtOrBefore") OffsetDateTime retentionExpiresAtOrBefore,
            @Param("limit") int limit
    );

    int expireStaleDrafts(
            @Param("generationExpiresAtOrBefore") OffsetDateTime generationExpiresAtOrBefore,
            @Param("installationRetentionExpiresAt") OffsetDateTime installationRetentionExpiresAt,
            @Param("updatedAt") OffsetDateTime updatedAt,
            @Param("limit") int limit
    );

    int deleteAccountOwned(@Param("accountId") String accountId);
}
