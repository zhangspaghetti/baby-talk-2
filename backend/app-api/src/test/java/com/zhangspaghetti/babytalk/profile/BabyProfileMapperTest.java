package com.zhangspaghetti.babytalk.profile;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.profile.model.BabyProfilePatch;
import com.zhangspaghetti.babytalk.profile.model.BabyProfileRow;
import com.zhangspaghetti.babytalk.service.CaregiverInviteMapper;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest
class BabyProfileMapperTest extends AbstractIntegrationTest {

    private static final Instant NOW = Instant.parse("2026-07-03T02:00:00Z");
    private static final OffsetDateTime NOW_DB = OffsetDateTime.ofInstant(NOW, ZoneOffset.UTC);

    @Autowired
    private BabyProfileMapper mapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private CaregiverInviteMapper caregiverInviteMapper;

    @Test
    void insertsAndReadsByAccountId() {
        insertAccount("acct_profile_1");
        mapper.insert(draftRow("babyprof_1", "acct_profile_1", "小满"));

        var found = mapper.findByAccountId("acct_profile_1");

        assertThat(found).isNotNull();
        assertThat(found.profileId()).isEqualTo("babyprof_1");
        assertThat(found.babyName()).isEqualTo("小满");
        assertThat(found.version()).isEqualTo(1);
    }

    @Test
    void uniqueAccountIdAllowsOneProfilePerAccount() {
        insertAccount("acct_profile_unique");
        mapper.insert(draftRow("babyprof_unique_1", "acct_profile_unique", null));

        assertThatThrownBy(() -> mapper.insert(draftRow("babyprof_unique_2", "acct_profile_unique", null)))
                .isInstanceOf(DuplicateKeyException.class);
    }

    @Test
    void updateWithMatchingVersionChangesFieldsAndIncrementsVersion() {
        insertAccount("acct_profile_update");
        mapper.insert(draftRow("babyprof_update", "acct_profile_update", null));

        var affected = mapper.updateIfVersionMatches(
                "acct_profile_update",
                1,
                completedPatch("小满"),
                NOW_DB.plusSeconds(60)
        );
        var updated = mapper.findByAccountId("acct_profile_update");

        assertThat(affected).isEqualTo(1);
        assertThat(updated).isNotNull();
        assertThat(updated.babyName()).isEqualTo("小满");
        assertThat(updated.onboardingState()).isEqualTo("completed");
        assertThat(updated.version()).isEqualTo(2);
        assertThat(updated.starterSource()).isEqualTo("catalog");
    }

    @Test
    void updateWithNonMatchingVersionAffectsZeroRows() {
        insertAccount("acct_profile_stale");
        mapper.insert(draftRow("babyprof_stale", "acct_profile_stale", null));

        var affected = mapper.updateIfVersionMatches(
                "acct_profile_stale",
                2,
                completedPatch("小满"),
                NOW_DB.plusSeconds(60)
        );

        assertThat(affected).isZero();
        assertThat(mapper.findByAccountId("acct_profile_stale").version()).isEqualTo(1);
    }

    @Test
    void nullOptionalDraftFieldsPersist() {
        insertAccount("acct_profile_nulls");
        mapper.insert(draftRow("babyprof_nulls", "acct_profile_nulls", null));

        var found = mapper.findByAccountId("acct_profile_nulls");

        assertThat(found).isNotNull();
        assertThat(found.babyName()).isNull();
        assertThat(found.parentGoal()).isNull();
        assertThat(found.starterSceneId()).isNull();
        assertThat(found.onboardingCompletedAt()).isNull();
    }

    @Test
    void completedRowsWithRequiredFieldsPersist() {
        insertAccount("acct_profile_completed");
        mapper.insert(completedRow("babyprof_completed", "acct_profile_completed"));

        var found = mapper.findByAccountId("acct_profile_completed");

        assertThat(found).isNotNull();
        assertThat(found.onboardingState()).isEqualTo("completed");
        assertThat(found.parentGoal()).isEqualTo("calmer_care");
        assertThat(found.onboardingCompletedAt()).isEqualTo(NOW_DB);
        assertThat(found.starterPhraseId()).isEqualTo("bath_time_warm_water");
    }

    @Test
    void sharedProfileRequiresActiveHouseholdPrimaryAndRequester() {
        insertAccount("acct_shared_primary");
        insertAccount("acct_shared_caregiver");
        insertHouseholdGraph(
                "household_shared_active",
                "acct_shared_primary",
                "acct_shared_caregiver",
                "active",
                "active",
                "active"
        );
        mapper.insert(completedRow("babyprof_shared_primary", "acct_shared_primary"));

        var found = mapper.findSharedByHouseholdMemberAccountId("acct_shared_caregiver");

        assertThat(found).isNotNull();
        assertThat(found.accountId()).isEqualTo("acct_shared_primary");
        assertThat(found.profileId()).isEqualTo("babyprof_shared_primary");
    }

    @Test
    void sharedProfileDoesNotReturnWhenMembershipOrPrimaryOrHouseholdIsInactive() {
        insertAccount("acct_shared_primary_revoked");
        insertAccount("acct_shared_caregiver_revoked");
        insertHouseholdGraph(
                "household_shared_revocation",
                "acct_shared_primary_revoked",
                "acct_shared_caregiver_revoked",
                "active",
                "active",
                "active"
        );
        mapper.insert(completedRow("babyprof_shared_revocation", "acct_shared_primary_revoked"));

        jdbcTemplate.update(
                "update household_members set status = 'revoked' where account_id = ?",
                "acct_shared_caregiver_revoked"
        );
        assertThat(mapper.findSharedByHouseholdMemberAccountId("acct_shared_caregiver_revoked")).isNull();

        jdbcTemplate.update(
                "update household_members set status = 'active' where account_id = ?",
                "acct_shared_caregiver_revoked"
        );
        jdbcTemplate.update(
                "update household_members set status = 'revoked' where account_id = ?",
                "acct_shared_primary_revoked"
        );
        assertThat(mapper.findSharedByHouseholdMemberAccountId("acct_shared_caregiver_revoked")).isNull();

        jdbcTemplate.update(
                "update household_members set status = 'active' where account_id = ?",
                "acct_shared_primary_revoked"
        );
        jdbcTemplate.update(
                "update households set status = 'revoked' where household_id = ?",
                "household_shared_revocation"
        );
        assertThat(mapper.findSharedByHouseholdMemberAccountId("acct_shared_caregiver_revoked")).isNull();
    }

    @Test
    void generationAccessStateDistinguishesNeverMemberInactiveMembershipAndInactiveHousehold() {
        insertAccount("acct_access_never");
        insertAccount("acct_access_primary");
        insertAccount("acct_access_membership");
        insertHouseholdGraph(
                "household_access_membership",
                "acct_access_primary",
                "acct_access_membership",
                "active",
                "active",
                "active"
        );

        var neverMember = caregiverInviteMapper.findGenerationAccessStateByAccount("acct_access_never");
        assertThat(neverMember.accessState()).isEqualTo("never_member");

        jdbcTemplate.update(
                "update household_members set status = 'revoked' where account_id = ?",
                "acct_access_membership"
        );
        var inactiveMembership = caregiverInviteMapper.findGenerationAccessStateByAccount("acct_access_membership");
        assertThat(inactiveMembership.accessState()).isEqualTo("inactive_membership");

        jdbcTemplate.update(
                "update household_members set status = 'active' where account_id = ?",
                "acct_access_membership"
        );
        jdbcTemplate.update(
                "update households set status = 'revoked' where household_id = ?",
                "household_access_membership"
        );
        var inactiveHousehold = caregiverInviteMapper.findGenerationAccessStateByAccount("acct_access_membership");
        assertThat(inactiveHousehold.accessState()).isEqualTo("inactive_household");
    }

    private void insertAccount(String accountId) {
        jdbcTemplate.update(
                """
                insert into accounts (
                    account_id,
                    phone_lookup_ref,
                    phone_mask,
                    status,
                    latest_consent_status,
                    created_at,
                    deleted_at
                ) values (?, ?, '138****8000', 'active', 'accepted', ?, null)
                """,
                accountId,
                "test-phone-ref:" + accountId,
                Timestamp.from(NOW_DB.toInstant()));
    }

    private BabyProfileRow draftRow(String profileId, String accountId, String babyName) {
        return new BabyProfileRow(
                profileId,
                accountId,
                babyName,
                "m7_11",
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                "draft",
                null,
                1,
                NOW_DB,
                NOW_DB
        );
    }

    private void insertHouseholdGraph(
            String householdId,
            String ownerAccountId,
            String requesterAccountId,
            String householdStatus,
            String ownerMemberStatus,
            String requesterMemberStatus
    ) {
        jdbcTemplate.update(
                """
                insert into households (
                    household_id,
                    owner_account_id,
                    status,
                    created_at,
                    revoked_at
                ) values (?, ?, ?, ?, null)
                """,
                householdId,
                ownerAccountId,
                householdStatus,
                Timestamp.from(NOW_DB.toInstant())
        );
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
                ) values (?, ?, 'primary_caregiver', ?, null, ?, null)
                """,
                householdId,
                ownerAccountId,
                ownerMemberStatus,
                Timestamp.from(NOW_DB.toInstant())
        );
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
                ) values (?, ?, 'caregiver', ?, ?, ?, null)
                """,
                householdId,
                requesterAccountId,
                requesterMemberStatus,
                ownerAccountId,
                Timestamp.from(NOW_DB.toInstant())
        );
    }

    private BabyProfileRow completedRow(String profileId, String accountId) {
        return new BabyProfileRow(
                profileId,
                accountId,
                "小满",
                "m7_11",
                "calmer_care",
                "daily_care",
                "bath_time",
                "bath_time",
                "bath_time_warm_water",
                "bath_time_warm_water",
                "catalog",
                "completed",
                NOW_DB,
                1,
                NOW_DB,
                NOW_DB
        );
    }

    private BabyProfilePatch completedPatch(String babyName) {
        return new BabyProfilePatch(
                babyName,
                "m7_11",
                "calmer_care",
                "daily_care",
                "bath_time",
                "bath_time",
                "bath_time_warm_water",
                "bath_time_warm_water",
                "catalog",
                "completed",
                NOW_DB
        );
    }
}
