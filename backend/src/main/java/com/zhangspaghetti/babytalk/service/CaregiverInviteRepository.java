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
                    updated_at = ?,
                    latest_actor_role = ?,
                    latest_actor_source = ?,
                    latest_actor_result = ?,
                    next_step_space_id = ?,
                    next_step_activity_id = ?,
                    next_step_reason = ?
                where household_id = ?
                """,
                row.babyProfileSummary(),
                row.continuitySummary(),
                row.gardenSummary(),
                row.spaceId(),
                row.activityId(),
                Timestamp.from(row.latestInteractionAt()),
                Timestamp.from(row.updatedAt()),
                row.latestActorRole(),
                row.latestActorSource(),
                row.latestActorResult(),
                row.nextStepSpaceId(),
                row.nextStepActivityId(),
                row.nextStepReason(),
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
                        updated_at,
                        latest_actor_role,
                        latest_actor_source,
                        latest_actor_result,
                        next_step_space_id,
                        next_step_activity_id,
                        next_step_reason
                    ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    row.householdId(),
                    row.babyProfileSummary(),
                    row.continuitySummary(),
                    row.gardenSummary(),
                    row.spaceId(),
                    row.activityId(),
                    Timestamp.from(row.latestInteractionAt()),
                    Timestamp.from(row.updatedAt()),
                    row.latestActorRole(),
                    row.latestActorSource(),
                    row.latestActorResult(),
                    row.nextStepSpaceId(),
                    row.nextStepActivityId(),
                    row.nextStepReason()
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
                       sc.updated_at,
                       sc.latest_actor_role,
                       sc.latest_actor_source,
                       sc.latest_actor_result,
                       sc.next_step_space_id,
                       sc.next_step_activity_id,
                       sc.next_step_reason
                from household_members hm
                join household_shared_context sc on sc.household_id = hm.household_id
                where hm.account_id = ? and hm.status = 'active'
                """,
                this::mapSharedContextViewRow,
                accountId
        );
    }

    Optional<HouseholdProjectionRow> findHouseholdProjection(String householdId) {
        return findOne(
                """
                with household_events as (
                    select ie.event_key,
                           ie.space_id,
                           ie.activity_id,
                           ie.reaction_type,
                           ie.client_timestamp,
                           hm.role as actor_role
                    from interaction_events ie
                    join household_members hm on hm.account_id = ie.account_id
                    where hm.household_id = ? and hm.status = 'active'
                ),
                latest as (
                    select space_id,
                           activity_id,
                           reaction_type,
                           client_timestamp,
                           actor_role
                    from household_events
                    order by client_timestamp desc, event_key desc
                    limit 1
                ),
                totals as (
                    select count(*) as total_events
                    from household_events
                ),
                members as (
                    select count(*) as member_count
                    from household_members
                    where household_id = ? and status = 'active'
                ),
                top_activity as (
                    select space_id,
                           activity_id,
                           count(*) as event_count,
                           max(client_timestamp) as latest_interaction_at
                    from household_events
                    group by space_id, activity_id
                    order by count(*) desc, max(client_timestamp) desc, space_id asc, activity_id asc
                    limit 1
                )
                select latest.space_id as latest_space_id,
                       latest.activity_id as latest_activity_id,
                       latest.reaction_type as latest_reaction_type,
                       latest.client_timestamp as latest_interaction_at,
                       latest.actor_role as latest_actor_role,
                       totals.total_events,
                       members.member_count,
                       coalesce(top_activity.space_id, latest.space_id) as next_step_space_id,
                       coalesce(top_activity.activity_id, latest.activity_id) as next_step_activity_id,
                       coalesce(top_activity.event_count, totals.total_events) as next_step_event_count
                from latest
                cross join totals
                cross join members
                left join top_activity on true
                """,
                this::mapHouseholdProjectionRow,
                householdId,
                householdId
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
                rs.getTimestamp("updated_at").toInstant(),
                rs.getString("latest_actor_role"),
                rs.getString("latest_actor_source"),
                rs.getString("latest_actor_result"),
                rs.getString("next_step_space_id"),
                rs.getString("next_step_activity_id"),
                rs.getString("next_step_reason")
        );
    }

    private HouseholdProjectionRow mapHouseholdProjectionRow(ResultSet rs, int rowNum) throws SQLException {
        return new HouseholdProjectionRow(
                rs.getString("latest_space_id"),
                rs.getString("latest_activity_id"),
                rs.getString("latest_reaction_type"),
                rs.getTimestamp("latest_interaction_at").toInstant(),
                rs.getString("latest_actor_role"),
                rs.getInt("total_events"),
                rs.getInt("member_count"),
                rs.getString("next_step_space_id"),
                rs.getString("next_step_activity_id"),
                rs.getInt("next_step_event_count")
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
            Instant updatedAt,
            String latestActorRole,
            String latestActorSource,
            String latestActorResult,
            String nextStepSpaceId,
            String nextStepActivityId,
            String nextStepReason
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
            Instant updatedAt,
            String latestActorRole,
            String latestActorSource,
            String latestActorResult,
            String nextStepSpaceId,
            String nextStepActivityId,
            String nextStepReason
    ) {
    }

    record HouseholdProjectionRow(
            String latestSpaceId,
            String latestActivityId,
            String latestActorResult,
            Instant latestInteractionAt,
            String latestActorRole,
            int totalEvents,
            int activeMemberCount,
            String nextStepSpaceId,
            String nextStepActivityId,
            int nextStepEventCount
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
