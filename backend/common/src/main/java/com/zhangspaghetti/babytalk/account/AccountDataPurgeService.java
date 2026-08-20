package com.zhangspaghetti.babytalk.account;

import java.time.OffsetDateTime;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Single transactional account deletion boundary shared by app and admin APIs.
 * Consent effect audit rows intentionally stay outside this purge and are
 * written by the caller with the request-specific audit context.
 */
@Service
public class AccountDataPurgeService {

    private final AccountDataPurgeMapper mapper;

    public AccountDataPurgeService(AccountDataPurgeMapper mapper) {
        this.mapper = mapper;
    }

    @Transactional
    public PurgeResult purge(String accountId, OffsetDateTime deletedAt) {
        var state = mapper.lockAccount(accountId);
        if (state == null || "deleted".equals(state.status())) {
            return PurgeResult.duplicate(accountId);
        }

        var deletedSmsChallenges = mapper.deleteSmsChallenges(accountId);
        var deletedInteractionEvents = mapper.deleteInteractionEvents(accountId);
        var deletedMentorTurns = mapper.deleteMentorTurns(accountId);
        var deletedMentorAuditLogs = mapper.deleteMentorAuditLogs(accountId);
        var deletedGardenApplyLogs = mapper.deleteGardenApplyLogs(accountId);
        var deletedGardenClaimLogs = mapper.deleteGardenClaimLogs(accountId);
        var deletedGardenStates = mapper.deleteGardenState(accountId);
        mapper.clearDerivedBundleReferences(accountId);
        var deletedGeneratedContent = mapper.deleteGeneratedContent(accountId);
        var deletedBabyProfiles = mapper.deleteBabyProfile(accountId);

        var revokedRefreshTokens = mapper.revokeRefreshTokens(accountId, deletedAt);
        var deletedSessions = mapper.updateSessions(accountId, deletedAt);

        // A deleted owner loses the shared projection; a deleted caregiver must
        // not remove context still owned by another active household member.
        mapper.deleteSharedContextOwnedByAccount(accountId);
        mapper.redactInviteEventReferences(accountId);
        var deletedInvites = mapper.deleteInvitesByInviter(accountId);
        mapper.clearAcceptedByReferences(accountId);
        mapper.clearInvitedByReferences(accountId);
        mapper.transferHouseholdOwners(accountId);
        var deletedMemberships = mapper.deleteMembership(accountId);
        var deletedEmptyHouseholdEvents = mapper.deleteEmptyOwnedHouseholdEvents(accountId);
        var deletedEmptyHouseholdContext = mapper.deleteEmptyOwnedHouseholdContext(accountId);
        var deletedEmptyHouseholdInvites = mapper.deleteEmptyOwnedHouseholdInvites(accountId);
        var deletedEmptyHouseholdMembers = mapper.deleteEmptyOwnedHouseholdMembers(accountId);
        var deletedHouseholds = mapper.deleteEmptyOwnedHouseholds(accountId);

        mapper.tombstoneAccount(accountId, deletedAt);
        return new PurgeResult(
                accountId,
                true,
                deletedInteractionEvents,
                deletedSmsChallenges,
                deletedMentorTurns,
                deletedMentorAuditLogs,
                deletedGardenApplyLogs,
                deletedGardenClaimLogs,
                deletedGardenStates,
                deletedGeneratedContent,
                deletedBabyProfiles,
                revokedRefreshTokens,
                deletedSessions,
                deletedMemberships,
                deletedEmptyHouseholdEvents,
                deletedEmptyHouseholdContext,
                deletedEmptyHouseholdInvites + deletedInvites,
                deletedEmptyHouseholdMembers,
                deletedHouseholds
        );
    }

    public record PurgeResult(
            String accountId,
            boolean applied,
            int deletedInteractionEventCount,
            int deletedSmsChallengeCount,
            int deletedMentorTurnCount,
            int deletedMentorAuditLogCount,
            int deletedGardenApplyLogCount,
            int deletedGardenClaimLogCount,
            int deletedGardenStateCount,
            int deletedGeneratedContentCount,
            int deletedBabyProfileCount,
            int revokedRefreshTokenCount,
            int deletedSessionCount,
            int deletedMembershipCount,
            int deletedEmptyHouseholdEventCount,
            int deletedEmptyHouseholdContextCount,
            int deletedEmptyHouseholdInviteCount,
            int deletedEmptyHouseholdMemberCount,
            int deletedHouseholdCount
    ) {

        static PurgeResult duplicate(String accountId) {
            return new PurgeResult(
                    accountId,
                    false,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0
            );
        }
    }
}
