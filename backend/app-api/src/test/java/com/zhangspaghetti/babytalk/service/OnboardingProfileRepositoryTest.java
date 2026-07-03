package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import java.sql.Timestamp;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest
class OnboardingProfileRepositoryTest extends AbstractIntegrationTest {

    private static final Instant NOW = Instant.parse("2026-07-03T02:00:00Z");

    @Autowired
    private OnboardingProfileRepository repository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void insertsAndReadsByAccountId() {
        insertAccount("acct_profile_1");
        repository.insert(draftRow("babyprof_1", "acct_profile_1", "小满"));

        var found = repository.findByAccountId("acct_profile_1");

        assertThat(found).isPresent();
        assertThat(found.get().profileId()).isEqualTo("babyprof_1");
        assertThat(found.get().babyName()).isEqualTo("小满");
        assertThat(found.get().version()).isEqualTo(1);
    }

    @Test
    void uniqueAccountIdAllowsOneProfilePerAccount() {
        insertAccount("acct_profile_unique");
        repository.insert(draftRow("babyprof_unique_1", "acct_profile_unique", null));

        assertThatThrownBy(() -> repository.insert(draftRow("babyprof_unique_2", "acct_profile_unique", null)))
                .isInstanceOf(DuplicateKeyException.class);
    }

    @Test
    void updateWithMatchingVersionChangesFieldsAndIncrementsVersion() {
        insertAccount("acct_profile_update");
        repository.insert(draftRow("babyprof_update", "acct_profile_update", null));

        var affected = repository.updateIfVersionMatches(
                "acct_profile_update",
                1,
                completedPatch("小满"),
                NOW.plusSeconds(60)
        );
        var updated = repository.findByAccountId("acct_profile_update").orElseThrow();

        assertThat(affected).isEqualTo(1);
        assertThat(updated.babyName()).isEqualTo("小满");
        assertThat(updated.onboardingState()).isEqualTo("completed");
        assertThat(updated.version()).isEqualTo(2);
        assertThat(updated.starterSource()).isEqualTo("catalog");
    }

    @Test
    void updateWithNonMatchingVersionAffectsZeroRows() {
        insertAccount("acct_profile_stale");
        repository.insert(draftRow("babyprof_stale", "acct_profile_stale", null));

        var affected = repository.updateIfVersionMatches(
                "acct_profile_stale",
                2,
                completedPatch("小满"),
                NOW.plusSeconds(60)
        );

        assertThat(affected).isZero();
        assertThat(repository.findByAccountId("acct_profile_stale").orElseThrow().version()).isEqualTo(1);
    }

    @Test
    void nullOptionalDraftFieldsPersist() {
        insertAccount("acct_profile_nulls");
        repository.insert(draftRow("babyprof_nulls", "acct_profile_nulls", null));

        var found = repository.findByAccountId("acct_profile_nulls").orElseThrow();

        assertThat(found.babyName()).isNull();
        assertThat(found.parentGoal()).isNull();
        assertThat(found.starterSceneId()).isNull();
        assertThat(found.onboardingCompletedAt()).isNull();
    }

    @Test
    void completedRowsWithRequiredFieldsPersist() {
        insertAccount("acct_profile_completed");
        repository.insert(completedRow("babyprof_completed", "acct_profile_completed"));

        var found = repository.findByAccountId("acct_profile_completed").orElseThrow();

        assertThat(found.onboardingState()).isEqualTo("completed");
        assertThat(found.parentGoal()).isEqualTo("calmer_care");
        assertThat(found.onboardingCompletedAt()).isEqualTo(NOW);
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
                Timestamp.from(NOW));
    }

    private OnboardingProfileRepository.ProfileRow draftRow(String profileId, String accountId, String babyName) {
        return new OnboardingProfileRepository.ProfileRow(
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
                NOW,
                NOW
        );
    }

    private OnboardingProfileRepository.ProfileRow completedRow(String profileId, String accountId) {
        return new OnboardingProfileRepository.ProfileRow(
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
                NOW,
                1,
                NOW,
                NOW
        );
    }

    private OnboardingProfileRepository.ProfilePatch completedPatch(String babyName) {
        return new OnboardingProfileRepository.ProfilePatch(
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
                NOW
        );
    }
}
