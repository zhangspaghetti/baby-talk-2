package com.zhangspaghetti.babytalk.service;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Repository;

@Repository
public class CaregiverInviteRepository {

    private final CaregiverInviteMapper mapper;

    public CaregiverInviteRepository(CaregiverInviteMapper mapper) {
        this.mapper = mapper;
    }

    Optional<HouseholdMemberRow> findActiveMembershipByAccount(String accountId) {
        return Optional.ofNullable(mapper.findActiveMembershipByAccount(accountId));
    }

    /**
     * Creates the account's primary household only when it has no membership.
     * The database uniqueness constraint remains the final cross-request guard.
     */
    public HouseholdMemberRow ensurePrimaryHousehold(String accountId, OffsetDateTime now) {
        var existing = findActiveMembershipByAccount(accountId);
        if (existing.isPresent()) {
            return existing.get();
        }
        var householdId = "household_" + UUID.randomUUID();
        insertHousehold(new HouseholdRow(householdId, accountId, "active", now, null));
        var inserted = mapper.insertMemberIfAbsent(new HouseholdMemberRow(
                0,
                householdId,
                accountId,
                "primary_caregiver",
                "active",
                null,
                now,
                null
        ));
        if (inserted == 0) {
            mapper.deleteHouseholdIfUnassigned(householdId);
        }
        return findActiveMembershipByAccount(accountId).orElseThrow(() ->
                new IllegalStateException("primary household membership was not persisted"));
    }

    Optional<HouseholdMemberRow> findMembershipByHouseholdAndAccount(String householdId, String accountId) {
        return Optional.ofNullable(mapper.findMembershipByHouseholdAndAccount(householdId, accountId));
    }

    HouseholdRow insertHousehold(HouseholdRow household) {
        mapper.insertHousehold(household);
        return household;
    }

    HouseholdMemberRow insertMember(HouseholdMemberRow member) {
        mapper.insertMember(member);
        return findActiveMembershipByAccount(member.accountId()).orElse(member);
    }

    void insertInvite(InviteRow invite) {
        mapper.insertInvite(invite);
    }

    Optional<InviteRow> findInviteByTokenLookupRef(String tokenLookupRef) {
        return Optional.ofNullable(mapper.findInviteByTokenLookupRef(tokenLookupRef));
    }

    void markInviteAccepted(String tokenLookupRef, String acceptedByAccountId, OffsetDateTime acceptedAt) {
        mapper.markInviteAccepted(tokenLookupRef, acceptedByAccountId, acceptedAt);
    }

    void markInviteExpired(String tokenLookupRef, String failureReason) {
        mapper.markInviteExpired(tokenLookupRef, failureReason);
    }

    void markInviteRevoked(String tokenLookupRef, OffsetDateTime revokedAt, String failureReason) {
        mapper.markInviteRevoked(tokenLookupRef, revokedAt, failureReason);
    }

    void upsertSharedContext(SharedContextRow row) {
        var updated = mapper.updateSharedContext(row);
        if (updated == 0) {
            mapper.insertSharedContext(row);
        }
    }

    Optional<SharedContextViewRow> findSharedContextByAccount(String accountId) {
        return Optional.ofNullable(mapper.findSharedContextByAccount(accountId));
    }

    Optional<HouseholdProjectionRow> findHouseholdProjection(String householdId) {
        return Optional.ofNullable(mapper.findHouseholdProjection(householdId));
    }

    Optional<LatestInteractionRow> findLatestHouseholdInteraction(String householdId) {
        return Optional.ofNullable(mapper.findLatestHouseholdInteraction(householdId));
    }

    int countHouseholdInteractions(String householdId) {
        return mapper.countHouseholdInteractions(householdId);
    }

    int countActiveMembers(String householdId) {
        return mapper.countActiveMembers(householdId);
    }

    Optional<ActivitySummaryRow> findTopActivity(String householdId) {
        return Optional.ofNullable(mapper.findTopActivity(householdId));
    }

    void insertEvent(EventRow row) {
        mapper.insertEvent(row);
    }

    public record HouseholdRow(
            String householdId,
            String ownerAccountId,
            String status,
            OffsetDateTime createdAt,
            OffsetDateTime revokedAt
    ) {
    }

    public record HouseholdMemberRow(
            long membershipId,
            String householdId,
            String accountId,
            String role,
            String status,
            String invitedByAccountId,
            OffsetDateTime joinedAt,
            OffsetDateTime lastAcceptedAt
    ) {
    }

    public record InviteRow(
            long inviteId,
            String tokenLookupRef,
            String householdId,
            String inviterAccountId,
            String targetRole,
            String source,
            String status,
            OffsetDateTime createdAt,
            OffsetDateTime expiresAt,
            OffsetDateTime acceptedAt,
            OffsetDateTime revokedAt,
            String acceptedByAccountId,
            String failureReason
    ) {
    }

    public record SharedContextRow(
            String householdId,
            String babyProfileSummary,
            String continuitySummary,
            String gardenSummary,
            String spaceId,
            String activityId,
            OffsetDateTime latestInteractionAt,
            OffsetDateTime updatedAt,
            String latestActorRole,
            String latestActorSource,
            String latestActorResult,
            String nextStepSpaceId,
            String nextStepActivityId,
            String nextStepReason
    ) {
    }

    public record SharedContextViewRow(
            String householdId,
            String role,
            OffsetDateTime lastAcceptedAt,
            String babyProfileSummary,
            String continuitySummary,
            String gardenSummary,
            String spaceId,
            String activityId,
            OffsetDateTime latestInteractionAt,
            OffsetDateTime updatedAt,
            String latestActorRole,
            String latestActorSource,
            String latestActorResult,
            String nextStepSpaceId,
            String nextStepActivityId,
            String nextStepReason
    ) {
    }

    public record HouseholdProjectionRow(
            String latestSpaceId,
            String latestActivityId,
            String latestActorResult,
            OffsetDateTime latestInteractionAt,
            String latestActorRole,
            int totalEvents,
            int activeMemberCount,
            String nextStepSpaceId,
            String nextStepActivityId,
            int nextStepEventCount
    ) {
    }

    public record LatestInteractionRow(
            String spaceId,
            String activityId,
            String reactionType,
            OffsetDateTime clientTimestamp,
            String sourceAccountId
    ) {
    }

    public record ActivitySummaryRow(
            String spaceId,
            String activityId,
            int eventCount,
            OffsetDateTime latestInteractionAt
    ) {
    }

    public record EventRow(
            String tokenLookupRef,
            String householdId,
            String actorAccountId,
            String entrypoint,
            String source,
            String requestedRole,
            String platform,
            String result,
            String failureReason,
            OffsetDateTime createdAt
    ) {
    }
}
