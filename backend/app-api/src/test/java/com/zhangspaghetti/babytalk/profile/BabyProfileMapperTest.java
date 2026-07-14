package com.zhangspaghetti.babytalk.profile;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.profile.model.BabyProfilePatch;
import com.zhangspaghetti.babytalk.profile.model.BabyProfileRow;
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

    private void insertAccount(String accountId) {
        jdbcTemplate.update(
                """
                insert into accounts (
                    account_id,
                    phone_number,
                    status,
                    latest_consent_status,
                    created_at,
                    deleted_at
                ) values (?, ?, 'active', 'accepted', ?, null)
                """,
                accountId,
                accountId + "_phone",
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
