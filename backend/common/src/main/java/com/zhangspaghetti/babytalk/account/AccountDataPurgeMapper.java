package com.zhangspaghetti.babytalk.account;

import java.time.OffsetDateTime;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

/**
 * Database boundary for irreversible account-owned data removal.
 *
 * <p>Keep this mapper in {@code common}: consumer and admin deletion paths must
 * execute the same purge contract.</p>
 */
@Mapper
public interface AccountDataPurgeMapper {

    AccountState lockAccount(@Param("accountId") String accountId);

    int deleteSmsChallenges(@Param("accountId") String accountId);

    int deleteInteractionEvents(@Param("accountId") String accountId);

    int deleteMentorTurns(@Param("accountId") String accountId);

    int deleteMentorAuditLogs(@Param("accountId") String accountId);

    int deleteGardenApplyLogs(@Param("accountId") String accountId);

    int deleteGardenClaimLogs(@Param("accountId") String accountId);

    int deleteGardenState(@Param("accountId") String accountId);

    int clearDerivedBundleReferences(@Param("accountId") String accountId);

    int deleteGeneratedContent(@Param("accountId") String accountId);

    int deleteBabyProfile(@Param("accountId") String accountId);

    int revokeRefreshTokens(@Param("accountId") String accountId, @Param("revokedAt") OffsetDateTime revokedAt);

    int updateSessions(@Param("accountId") String accountId, @Param("updatedAt") OffsetDateTime updatedAt);

    int deleteSharedContextOwnedByAccount(@Param("accountId") String accountId);

    int redactInviteEventReferences(@Param("accountId") String accountId);

    int deleteInvitesByInviter(@Param("accountId") String accountId);

    int clearAcceptedByReferences(@Param("accountId") String accountId);

    int clearInvitedByReferences(@Param("accountId") String accountId);

    int transferHouseholdOwners(@Param("accountId") String accountId);

    int deleteMembership(@Param("accountId") String accountId);

    int deleteEmptyOwnedHouseholdEvents(@Param("accountId") String accountId);

    int deleteEmptyOwnedHouseholdContext(@Param("accountId") String accountId);

    int deleteEmptyOwnedHouseholdInvites(@Param("accountId") String accountId);

    int deleteEmptyOwnedHouseholdMembers(@Param("accountId") String accountId);

    int deleteEmptyOwnedHouseholds(@Param("accountId") String accountId);

    int tombstoneAccount(@Param("accountId") String accountId, @Param("deletedAt") OffsetDateTime deletedAt);

    record AccountState(String accountId, String phoneLookupRef, String status) {
    }
}
