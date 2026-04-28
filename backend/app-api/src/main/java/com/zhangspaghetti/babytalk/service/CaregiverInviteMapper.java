package com.zhangspaghetti.babytalk.service;

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

    void insertInvite(@Param("row") CaregiverInviteRepository.InviteRow row);

    CaregiverInviteRepository.InviteRow findInviteByToken(@Param("token") String token);

    int markInviteAccepted(
            @Param("token") String token,
            @Param("acceptedByAccountId") String acceptedByAccountId,
            @Param("acceptedAt") java.time.Instant acceptedAt
    );

    int markInviteExpired(@Param("token") String token, @Param("failureReason") String failureReason);

    int markInviteRevoked(
            @Param("token") String token,
            @Param("revokedAt") java.time.Instant revokedAt,
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
