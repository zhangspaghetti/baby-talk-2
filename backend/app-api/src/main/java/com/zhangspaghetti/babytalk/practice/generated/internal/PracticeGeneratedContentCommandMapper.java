package com.zhangspaghetti.babytalk.practice.generated.internal;

import com.baomidou.mybatisplus.core.toolkit.Constants;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import java.time.OffsetDateTime;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
interface PracticeGeneratedContentCommandMapper {

    int insertDraftIgnoringLiveConflict(@Param(Constants.ENTITY) PracticeGeneratedContentEntity entity);

    int lockOwnerRateLimit(@Param("ownerLockKey") String ownerLockKey);

    PracticeGeneratedContentEntity findLiveDraftForUpdate(
            @Param("generatedContentId") String generatedContentId);

    int countRecentGenerationStarts(
            @Param("ownerKey") String ownerKey,
            @Param("ownerKeyVersion") String ownerKeyVersion,
            @Param("surface") String surface,
            @Param("mode") String mode,
            @Param("dailyFrom") OffsetDateTime dailyFrom);

    int markGenerating(
            @Param("generatedContentId") String generatedContentId,
            @Param("updatedAt") OffsetDateTime updatedAt);

    int activateGenerating(@Param(Constants.ENTITY) PracticeGeneratedContentEntity entity);

    int deleteDueInstallationActive(
            @Param("generatedContentId") String generatedContentId,
            @Param("ownerKeyVersion") String ownerKeyVersion,
            @Param("dueAt") OffsetDateTime dueAt);

    int rejectLive(
            @Param("generatedContentId") String generatedContentId,
            @Param("errorCode") String errorCode,
            @Param("retryable") boolean retryable,
            @Param("updatedAt") OffsetDateTime updatedAt,
            @Param("retentionExpiresAt") OffsetDateTime retentionExpiresAt);

    int expireLive(
            @Param("generatedContentId") String generatedContentId,
            @Param("errorCode") String errorCode,
            @Param("retryable") boolean retryable,
            @Param("updatedAt") OffsetDateTime updatedAt,
            @Param("retentionExpiresAt") OffsetDateTime retentionExpiresAt);

    int interruptStartedAttempts(
            @Param("interruptedAt") OffsetDateTime interruptedAt,
            @Param("limit") int limit);

    int interruptStartedOperations(
            @Param("interruptedAt") OffsetDateTime interruptedAt,
            @Param("limit") int limit);

    int interruptStartedProviderCalls(
            @Param("interruptedAt") OffsetDateTime interruptedAt,
            @Param("limit") int limit);

    int expireInterruptedGeneratedContent(
            @Param("interruptedAt") OffsetDateTime interruptedAt,
            @Param("installationRetentionExpiresAt") OffsetDateTime installationRetentionExpiresAt,
            @Param("limit") int limit);

    int deleteExpiredInstallationRows(
            @Param("retentionExpiresAtOrBefore") OffsetDateTime retentionExpiresAtOrBefore,
            @Param("limit") int limit);

    int deleteAccountOwned(@Param("accountId") String accountId);
}
