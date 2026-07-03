package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class OnboardingProfileServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-03T02:00:00Z");

    @Mock
    private AuthConsentSyncService authConsentSyncService;

    @Mock
    private OnboardingProfileRepository repository;

    private OnboardingProfileService service;

    @BeforeEach
    void setUp() {
        service = new OnboardingProfileService(
                authConsentSyncService,
                repository,
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
        when(authConsentSyncService.requireAcceptedConsumerSession(eq("sess_1"), any()))
                .thenReturn(new AuthConsentSyncService.ConsumerSessionView(
                        "acct_session",
                        "sess_1",
                        "install_1",
                        "accepted"
                ));
    }

    @Test
    void createUsesAccountResolvedFromSessionAndGeneratesProfileId() {
        when(repository.findByAccountId("acct_session")).thenReturn(Optional.empty());

        var response = service.putProfile("sess_1", draftRequest(null, "小满"));

        var row = captureInsertedRow();
        assertThat(row.accountId()).isEqualTo("acct_session");
        assertThat(row.profileId()).startsWith("babyprof_");
        assertThat(row.version()).isEqualTo(1);
        assertThat(response.babyProfileId()).isEqualTo(row.profileId());
        verify(repository).findByAccountId("acct_session");
    }

    @Test
    void blankBabyNameIsStoredAsNull() {
        when(repository.findByAccountId("acct_session")).thenReturn(Optional.empty());

        service.putProfile("sess_1", draftRequest(null, "   "));

        assertThat(captureInsertedRow().babyName()).isNull();
    }

    @Test
    void completedProfileRequiresGoalStarterAndCompletedAt() {
        assertContract(
                completedRequest(null, null, completedStarter(), NOW),
                "completed_profile_missing_parent_goal",
                HttpStatus.BAD_REQUEST
        );
        assertContract(
                completedRequest(null, "calmer_care", null, NOW),
                "completed_profile_missing_starter",
                HttpStatus.BAD_REQUEST
        );
        assertContract(
                completedRequest(null, "calmer_care", completedStarter(), null),
                "completed_at_required",
                HttpStatus.BAD_REQUEST
        );
    }

    @Test
    void futureCompletedAtIsRejected() {
        assertContract(
                completedRequest(null, "calmer_care", completedStarter(), NOW.plusSeconds(301)),
                "completed_at_in_future",
                HttpStatus.BAD_REQUEST
        );
    }

    @Test
    void invalidEnumsAreRejected() {
        assertContract(
                new OnboardingProfileService.PutOnboardingProfileRequest(
                        null,
                        null,
                        "m99",
                        null,
                        null,
                        "draft",
                        null,
                        null
                ),
                "invalid_age_range",
                HttpStatus.BAD_REQUEST
        );
        assertContract(
                new OnboardingProfileService.PutOnboardingProfileRequest(
                        null,
                        null,
                        "m7_11",
                        "sleep_better",
                        null,
                        "draft",
                        null,
                        null
                ),
                "invalid_parent_goal",
                HttpStatus.BAD_REQUEST
        );
        assertContract(
                new OnboardingProfileService.PutOnboardingProfileRequest(
                        null,
                        null,
                        "m7_11",
                        null,
                        null,
                        "done",
                        null,
                        null
                ),
                "invalid_onboarding_state",
                HttpStatus.BAD_REQUEST
        );
    }

    @Test
    void staleUpdateReportsCurrentVersionWithoutBabyName() {
        when(repository.findByAccountId("acct_session")).thenReturn(Optional.of(existingRow(2, "小满")));

        assertThatThrownBy(() -> service.putProfile("sess_1", draftRequest(1, "秘密宝宝")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.CONFLICT);
                    assertThat(contract.code()).isEqualTo("version_conflict");
                    assertThat(contract.details()).containsEntry("expectedVersion", 1);
                    assertThat(contract.details()).containsEntry("currentVersion", 2);
                    assertThat(contract.details().toString()).doesNotContain("秘密宝宝");
                });
    }

    @Test
    void createRaceReturnsVersionConflict() {
        when(repository.findByAccountId("acct_session")).thenReturn(Optional.empty());
        org.mockito.Mockito.doThrow(new DuplicateKeyException("duplicate"))
                .when(repository)
                .insert(any());
        when(repository.findVersionByAccountId("acct_session")).thenReturn(Optional.of(3));

        assertThatThrownBy(() -> service.putProfile("sess_1", draftRequest(null, "小满")))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.CONFLICT);
                    assertThat(contract.code()).isEqualTo("version_conflict");
                    assertThat(contract.details()).containsEntry("currentVersion", 3);
                });
    }

    private void assertContract(
            OnboardingProfileService.PutOnboardingProfileRequest request,
            String code,
            HttpStatus status
    ) {
        assertThatThrownBy(() -> service.putProfile("sess_1", request))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(status);
                    assertThat(contract.code()).isEqualTo(code);
                });
    }

    private OnboardingProfileRepository.ProfileRow captureInsertedRow() {
        ArgumentCaptor<OnboardingProfileRepository.ProfileRow> captor =
                ArgumentCaptor.forClass(OnboardingProfileRepository.ProfileRow.class);
        verify(repository).insert(captor.capture());
        return captor.getValue();
    }

    private OnboardingProfileService.PutOnboardingProfileRequest draftRequest(Integer expectedVersion, String babyName) {
        return new OnboardingProfileService.PutOnboardingProfileRequest(
                expectedVersion,
                babyName,
                "m7_11",
                null,
                null,
                "draft",
                null,
                "onb_profile_001"
        );
    }

    private OnboardingProfileService.PutOnboardingProfileRequest completedRequest(
            Integer expectedVersion,
            String parentGoal,
            OnboardingProfileService.StarterRequest starter,
            Instant completedAt
    ) {
        return new OnboardingProfileService.PutOnboardingProfileRequest(
                expectedVersion,
                "小满",
                "m7_11",
                parentGoal,
                starter,
                "completed",
                completedAt,
                "onb_profile_001"
        );
    }

    private OnboardingProfileService.StarterRequest completedStarter() {
        return new OnboardingProfileService.StarterRequest(
                "daily_care",
                "bath_time",
                "bath_time",
                "bath_time_warm_water",
                "bath_time_warm_water",
                "catalog"
        );
    }

    private OnboardingProfileRepository.ProfileRow existingRow(int version, String babyName) {
        return new OnboardingProfileRepository.ProfileRow(
                "babyprof_existing",
                "acct_session",
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
                version,
                NOW,
                NOW
        );
    }
}
