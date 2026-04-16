package com.zhangspaghetti.babytalk.service;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
class CaregiverInviteRepository {

    private final JdbcTemplate jdbcTemplate;

    CaregiverInviteRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    Optional<HouseholdMemberRow> findActiveMembershipByAccount(String accountId) {
        return findOne(
                """
                select membership_id,
                       household_id,
                       account_id,
                       role,
                       status,
                       invited_by_account_id,
                       joined_at,
                       last_accepted_at
                from household_members
                where account_id = ? and status = 'active'
                """,
                this::mapHouseholdMemberRow,
                accountId
        );
    }

    Optional<HouseholdMemberRow> findMembershipByHouseholdAndAccount(String householdId, String accountId) {
        return findOne(
                """
                select membership_id,
                       household_id,
                       account_id,
                       role,
                       status,
                       invited_by_account_id,
                       joined_at,
                       last_accepted_at
                from household_members
                where household_id = ? and account_id = ?
                """,
                this::mapHouseholdMemberRow,
                householdId,
                accountId
        );
    }

    HouseholdRow insertHousehold(HouseholdRow household) {
        jdbcTemplate.update(
                """
                insert into households (
                    household_id,
                    owner_account_id,
                    status,
                    created_at,
                    revoked_at
                ) values (?, ?, ?, ?, ?)
                """,
                household.householdId(),
                household.ownerAccountId(),
                household.status(),
                Timestamp.from(household.createdAt()),
                toTimestamp(household.revokedAt())
        );
        return household;
    }

    HouseholdMemberRow insertMember(HouseholdMemberRow member) {
        jdbcTemplate.update(
                """
                insert into household_members (
                    household_id,
                    account_id,
                    role,
                    status,
                    invited_by_account_id,
                    joined_at,
                    last_accepted_at
                ) values (?, ?, ?, ?, ?, ?, ?)
                """,
                member.householdId(),
                member.accountId(),
                member.role(),
                member.status(),
                member.invitedByAccountId(),
                Timestamp.from(member.joinedAt()),
                toTimestamp(member.lastAcceptedAt())
        );
        return findActiveMembershipByAccount(member.accountId()).orElse(member);
    }

    void insertInvite(InviteRow invite) {
        jdbcTemplate.update(
                """
                insert into caregiver_invites (
                    token,
                    household_id,
                    inviter_account_id,
                    target_role,
                    source,
                    status,
                    created_at,
                    expires_at,
                    accepted_at,
                    revoked_at,
                    accepted_by_account_id,
                    failure_reason
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                invite.token(),
                invite.householdId(),
                invite.inviterAccountId(),
                invite.targetRole(),
                invite.source(),
                invite.status(),
                Timestamp.from(invite.createdAt()),
                Timestamp.from(invite.expiresAt()),
                toTimestamp(invite.acceptedAt()),
                toTimestamp(invite.revokedAt()),
                invite.acceptedByAccountId(),
                invite.failureReason()
        );
    }

    Optional<InviteRow> findInviteByToken(String token) {
        return findOne(
                """
                select invite_id,
                       token,
                       household_id,
                       inviter_account_id,
                       target_role,
                       source,
                       status,
                       created_at,
                       expires_at,
                       accepted_at,
                       revoked_at,
                       accepted_by_account_id,
                       failure_reason
                from caregiver_invites
                where token = ?
                """,
                this::mapInviteRow,
                token
        );
    }

    void markInviteAccepted(String token, String acceptedByAccountId, Instant acceptedAt) {
        jdbcTemplate.update(
                """
                update caregiver_invites
                set status = 'accepted',
                    accepted_at = ?,
                    accepted_by_account_id = ?,
                    failure_reason = null
                where token = ? and status = 'pending'
                """,
                Timestamp.from(acceptedAt),
                acceptedByAccountId,
                token
        );
    }

    void markInviteExpired(String token, String failureReason) {
        jdbcTemplate.update(
                """
                update caregiver_invites
                set status = 'expired',
                    failure_reason = ?
                where token = ? and status = 'pending'
                """,
                failureReason,
                token
        );
    }

    void markInviteRevoked(String token, Instant revokedAt, String failureReason) {
        jdbcTemplate.update(
                """
                update caregiver_invites
                set status = 'revoked',
                    revoked_at = ?,
                    failure_reason = ?
                where token = ? and status = 'pending'
                """,
                Timestamp.from(revokedAt),
                failureReason,
                token
        );
    }

    void upsertSharedContext(SharedContextRow row) {
        var updated = jdbcTemplate.update(
                """
                update household_shared_context
                set baby_profile_summary = ?,
                    continuity_summary = ?,
                    garden_summary = ?,
                    space_id = ?,
                    activity_id = ?,
                    latest_interaction_at = ?,
                    updated_at = ?
                where household_id = ?
                """,
                row.babyProfileSummary(),
                row.continuitySummary(),
                row.gardenSummary(),
                row.spaceId(),
                row.activityId(),
                Timestamp.from(row.latestInteractionAt()),
                Timestamp.from(row.updatedAt()),
                row.householdId()
        );
        if (updated == 0) {
            jdbcTemplate.update(
                    """
                    insert into household_shared_context (
                        household_id,
                        baby_profile_summary,
                        continuity_summary,
                        garden_summary,
                        space_id,
                        activity_id,
                        latest_interaction_at,
                        updated_at
                    ) values (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    row.householdId(),
                    row.babyProfileSummary(),
                    row.continuitySummary(),
                    row.gardenSummary(),
                    row.spaceId(),
                    row.activityId(),
                    Timestamp.from(row.latestInteractionAt()),
                    Timestamp.from(row.updatedAt())
            );
        }
    }

    Optional<SharedContextViewRow> findSharedContextByAccount(String accountId) {
        return findOne(
                """
                select hm.household_id,
                       hm.role,
                       hm.last_accepted_at,
                       sc.baby_profile_summary,
                       sc.continuity_summary,
                       sc.garden_summary,
                       sc.space_id,
                       sc.activity_id,
                       sc.latest_interaction_at,
                       sc.updated_at
                from household_members hm
                join household_shared_context sc on sc.household_id = hm.household_id
                where hm.account_id = ? and hm.status = 'active'
                """,
                this::mapSharedContextViewRow,
                accountId
        );
    }

    Optional<LatestInteractionRow> findLatestHouseholdInteraction(String householdId) {
        return findOne(
                """
                select ie.space_id,
                       ie.activity_id,
                       ie.reaction_type,
                       ie.client_timestamp,
                       ie.account_id
                from interaction_events ie
                join household_members hm on hm.account_id = ie.account_id
                where hm.household_id = ? and hm.status = 'active'
                order by ie.client_timestamp desc, ie.event_key desc
                limit 1
                """,
                this::mapLatestInteractionRow,
                householdId
        );
    }

    int countHouseholdInteractions(String householdId) {
        return jdbcTemplate.queryForObject(
                """
                select count(*)
                from interaction_events ie
                join household_members hm on hm.account_id = ie.account_id
                where hm.household_id = ? and hm.status = 'active'
                """,
                Integer.class,
                householdId
        );
    }

    int countActiveMembers(String householdId) {
        return jdbcTemplate.queryForObject(
                "select count(*) from household_members where household_id = ? and status = 'active'",
                Integer.class,
                householdId
        );
    }

    Optional<ActivitySummaryRow> findTopActivity(String householdId) {
        return findOne(
                """
                select ie.space_id,
                       ie.activity_id,
                       count(*) as event_count,
                       max(ie.client_timestamp) as latest_interaction_at
                from interaction_events ie
                join household_members hm on hm.account_id = ie.account_id
                where hm.household_id = ? and hm.status = 'active'
                group by ie.space_id, ie.activity_id
                order by count(*) desc, max(ie.client_timestamp) desc
                limit 1
                """,
                this::mapActivitySummaryRow,
                householdId
        );
    }

    void insertEvent(EventRow row) {
        jdbcTemplate.update(
                """
                insert into caregiver_invite_events (
                    token,
                    household_id,
                    actor_account_id,
                    entrypoint,
                    source,
                    requested_role,
                    platform,
                    result,
                    failure_reason,
                    created_at
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                row.token(),
                row.householdId(),
                row.actorAccountId(),
                row.entrypoint(),
                row.source(),
                row.requestedRole(),
                row.platform(),
                row.result(),
                row.failureReason(),
                Timestamp.from(row.createdAt())
        );
    }

    private <T> Optional<T> findOne(String sql, RowMapper<T> mapper, Object... args) {
        try {
            return Optional.ofNullable(jdbcTemplate.queryForObject(sql, mapper, args));
        } catch (EmptyResultDataAccessException exception) {
            return Optional.empty();
        }
    }

    private HouseholdMemberRow mapHouseholdMemberRow(ResultSet rs, int rowNum) throws SQLException {
        return new HouseholdMemberRow(
                rs.getLong("membership_id"),
                rs.getString("household_id"),
                rs.getString("account_id"),
                rs.getString("role"),
                rs.getString("status"),
                rs.getString("invited_by_account_id"),
                rs.getTimestamp("joined_at").toInstant(),
                toInstant(rs.getTimestamp("last_accepted_at"))
        );
    }

    private InviteRow mapInviteRow(ResultSet rs, int rowNum) throws SQLException {
        return new InviteRow(
                rs.getLong("invite_id"),
                rs.getString("token"),
                rs.getString("household_id"),
                rs.getString("inviter_account_id"),
                rs.getString("target_role"),
                rs.getString("source"),
                rs.getString("status"),
                rs.getTimestamp("created_at").toInstant(),
                rs.getTimestamp("expires_at").toInstant(),
                toInstant(rs.getTimestamp("accepted_at")),
                toInstant(rs.getTimestamp("revoked_at")),
                rs.getString("accepted_by_account_id"),
                rs.getString("failure_reason")
        );
    }

    private SharedContextViewRow mapSharedContextViewRow(ResultSet rs, int rowNum) throws SQLException {
        return new SharedContextViewRow(
                rs.getString("household_id"),
                rs.getString("role"),
                toInstant(rs.getTimestamp("last_accepted_at")),
                rs.getString("baby_profile_summary"),
                rs.getString("continuity_summary"),
                rs.getString("garden_summary"),
                rs.getString("space_id"),
                rs.getString("activity_id"),
                rs.getTimestamp("latest_interaction_at").toInstant(),
                rs.getTimestamp("updated_at").toInstant()
        );
    }

    private LatestInteractionRow mapLatestInteractionRow(ResultSet rs, int rowNum) throws SQLException {
        return new LatestInteractionRow(
                rs.getString("space_id"),
                rs.getString("activity_id"),
                rs.getString("reaction_type"),
                rs.getTimestamp("client_timestamp").toInstant(),
                rs.getString("account_id")
        );
    }

    private ActivitySummaryRow mapActivitySummaryRow(ResultSet rs, int rowNum) throws SQLException {
        return new ActivitySummaryRow(
                rs.getString("space_id"),
                rs.getString("activity_id"),
                rs.getInt("event_count"),
                rs.getTimestamp("latest_interaction_at").toInstant()
        );
    }

    private Timestamp toTimestamp(Instant instant) {
        return instant == null ? null : Timestamp.from(instant);
    }

    private Instant toInstant(Timestamp timestamp) {
        return timestamp == null ? null : timestamp.toInstant();
    }

    record HouseholdRow(
            String householdId,
            String ownerAccountId,
            String status,
            Instant createdAt,
            Instant revokedAt
    ) {
    }

    record HouseholdMemberRow(
            long membershipId,
            String householdId,
            String accountId,
            String role,
            String status,
            String invitedByAccountId,
            Instant joinedAt,
            Instant lastAcceptedAt
    ) {
    }

    record InviteRow(
            long inviteId,
            String token,
            String householdId,
            String inviterAccountId,
            String targetRole,
            String source,
            String status,
            Instant createdAt,
            Instant expiresAt,
            Instant acceptedAt,
            Instant revokedAt,
            String acceptedByAccountId,
            String failureReason
    ) {
    }

    record SharedContextRow(
            String householdId,
            String babyProfileSummary,
            String continuitySummary,
            String gardenSummary,
            String spaceId,
            String activityId,
            Instant latestInteractionAt,
            Instant updatedAt
    ) {
    }

    record SharedContextViewRow(
            String householdId,
            String role,
            Instant lastAcceptedAt,
            String babyProfileSummary,
            String continuitySummary,
            String gardenSummary,
            String spaceId,
            String activityId,
            Instant latestInteractionAt,
            Instant updatedAt
    ) {
    }

    record LatestInteractionRow(
            String spaceId,
            String activityId,
            String reactionType,
            Instant clientTimestamp,
            String sourceAccountId
    ) {
    }

    record ActivitySummaryRow(
            String spaceId,
            String activityId,
            int eventCount,
            Instant latestInteractionAt
    ) {
    }

    record EventRow(
            String token,
            String householdId,
            String actorAccountId,
            String entrypoint,
            String source,
            String requestedRole,
            String platform,
            String result,
            String failureReason,
            Instant createdAt
    ) {
    }
}
