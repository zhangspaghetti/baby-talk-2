package com.zhangspaghetti.babytalk.service;

import java.time.OffsetDateTime;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface CaregiverInviteMapper {

    CaregiverInviteRepository.HouseholdMemberRow findActiveMembershipByAccount(@Param("accountId") String accountId);

    CaregiverInviteRepository.HouseholdMemberRow findMembershipByHouseholdAndAccount(
            @Param("householdId") String householdId,
            @Param("accountId") String accountId
    );

    void insertHousehold(@Param("row") CaregiverInviteRepository.HouseholdRow row);

    void insertMember(@Param("row") CaregiverInviteRepository.HouseholdMemberRow row);

    int insertMemberIfAbsent(@Param("row") CaregiverInviteRepository.HouseholdMemberRow row);

    int deleteHouseholdIfUnassigned(@Param("householdId") String householdId);

    void insertInvite(@Param("row") CaregiverInviteRepository.InviteRow row);

    CaregiverInviteRepository.InviteRow findInviteByTokenLookupRef(@Param("tokenLookupRef") String tokenLookupRef);

    int markInviteAccepted(
            @Param("tokenLookupRef") String tokenLookupRef,
            @Param("acceptedByAccountId") String acceptedByAccountId,
            @Param("acceptedAt") OffsetDateTime acceptedAt
    );

    int markInviteExpired(@Param("tokenLookupRef") String tokenLookupRef, @Param("failureReason") String failureReason);

    int markInviteRevoked(
            @Param("tokenLookupRef") String tokenLookupRef,
            @Param("revokedAt") OffsetDateTime revokedAt,
            @Param("failureReason") String failureReason
    );

    int updateSharedContext(@Param("row") CaregiverInviteRepository.SharedContextRow row);

    void insertSharedContext(@Param("row") CaregiverInviteRepository.SharedContextRow row);

    CaregiverInviteRepository.SharedContextViewRow findSharedContextByAccount(@Param("accountId") String accountId);

    CaregiverInviteRepository.HouseholdProjectionRow findHouseholdProjection(@Param("householdId") String householdId);

    CaregiverInviteRepository.LatestInteractionRow findLatestHouseholdInteraction(@Param("householdId") String householdId);

    int countHouseholdInteractions(@Param("householdId") String householdId);

    int countActiveMembers(@Param("householdId") String householdId);

    CaregiverInviteRepository.ActivitySummaryRow findTopActivity(@Param("householdId") String householdId);

    void insertEvent(@Param("row") CaregiverInviteRepository.EventRow row);
}
