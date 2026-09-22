package com.zhangspaghetti.babytalk.profile;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.scene.GenerationSubject;
import com.zhangspaghetti.babytalk.profile.model.BabyProfileRow;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import com.zhangspaghetti.babytalk.service.CaregiverInviteRepository;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.stream.Stream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

@ExtendWith(MockitoExtension.class)
class HouseholdBabyProfileAccessServiceTest {

    private static final OffsetDateTime NOW = OffsetDateTime.parse("2026-08-31T02:00:00Z");

    @Mock
    private AuthConsentSyncService authConsentSyncService;

    @Mock
    private CaregiverInviteRepository householdRepository;

    @Mock
    private BabyProfileMapper babyProfileMapper;

    private HouseholdBabyProfileAccessService service;

    @BeforeEach
    void setUp() {
        service = new HouseholdBabyProfileAccessService(
                authConsentSyncService,
                householdRepository,
                babyProfileMapper
        );
    }

    @Test
    void caregiverWithoutOwnProfileUsesActiveHouseholdPrimaryProfile() {
        stubAcceptedSession("sess_caregiver", "acct_caregiver");
        when(householdRepository.findGenerationAccessStateByAccount("acct_caregiver"))
                .thenReturn(Optional.of(activeState("household_primary", "acct_caregiver", "caregiver")));
        when(babyProfileMapper.findSharedByHouseholdMemberAccountId("acct_caregiver"))
                .thenReturn(profile("babyprof_primary", "acct_primary", "小满"));

        var subject = service.resolve("sess_caregiver");

        assertThat(subject.actorAccountId()).isEqualTo("acct_caregiver");
        assertThat(subject.ownerAccountId()).isEqualTo("acct_primary");
        assertThat(subject.profileId()).isEqualTo("babyprof_primary");
        assertThat(subject.profileVersion()).isEqualTo(7);
        assertThat(subject.householdId()).isEqualTo("household_primary");
        assertThat(subject.actorRole()).isEqualTo("caregiver");
        verify(babyProfileMapper, never()).findByAccountId("acct_caregiver");
    }

    @Test
    void caregiverWithHistoricalOwnProfileStillUsesSharedProfileOnly() {
        stubAcceptedSession("sess_caregiver_with_own_profile", "acct_caregiver");
        when(householdRepository.findGenerationAccessStateByAccount("acct_caregiver"))
                .thenReturn(Optional.of(activeState("household_primary", "acct_caregiver", "caregiver")));
        when(babyProfileMapper.findSharedByHouseholdMemberAccountId("acct_caregiver"))
                .thenReturn(profile("babyprof_primary", "acct_primary", "小满"));

        var subject = service.resolve("sess_caregiver_with_own_profile");

        assertThat(subject.actorAccountId()).isEqualTo("acct_caregiver");
        assertThat(subject.ownerAccountId()).isEqualTo("acct_primary");
        assertThat(subject.profileId()).isEqualTo("babyprof_primary");
        assertThat(subject.babyName()).isEqualTo("小满");
        verify(babyProfileMapper, never()).findByAccountId("acct_caregiver");
    }

    @Test
    void caregiverResolvesSharedProfileBeforeAnyOwnProfileQuery() {
        stubAcceptedSession("sess_caregiver_order", "acct_caregiver");
        when(householdRepository.findGenerationAccessStateByAccount("acct_caregiver"))
                .thenReturn(Optional.of(activeState("household_primary", "acct_caregiver", "caregiver")));
        when(babyProfileMapper.findSharedByHouseholdMemberAccountId("acct_caregiver"))
                .thenReturn(profile("babyprof_primary", "acct_primary", "小满"));

        service.resolve("sess_caregiver_order");

        InOrder order = inOrder(householdRepository, babyProfileMapper);
        order.verify(householdRepository).findGenerationAccessStateByAccount("acct_caregiver");
        order.verify(babyProfileMapper).findSharedByHouseholdMemberAccountId("acct_caregiver");
        order.verifyNoMoreInteractions();
    }

    @Test
    void activePrimaryMemberUsesOwnProfileAndRetainsHouseholdId() {
        stubAcceptedSession("sess_primary", "acct_primary");
        when(householdRepository.findGenerationAccessStateByAccount("acct_primary"))
                .thenReturn(Optional.of(activeState("household_primary", "acct_primary", "primary_caregiver")));
        when(babyProfileMapper.findByAccountId("acct_primary"))
                .thenReturn(profile("babyprof_primary", "acct_primary", "小满"));

        var subject = service.resolve("sess_primary");

        assertThat(subject.ownerAccountId()).isEqualTo("acct_primary");
        assertThat(subject.profileId()).isEqualTo("babyprof_primary");
        assertThat(subject.householdId()).isEqualTo("household_primary");
        assertThat(subject.actorRole()).isEqualTo("primary_caregiver");
        verify(babyProfileMapper, never()).findSharedByHouseholdMemberAccountId("acct_primary");
    }

    @Test
    void neverMemberUsesOwnProfileAsStandalonePrimaryCaregiver() {
        stubAcceptedSession("sess_standalone", "acct_standalone");
        when(householdRepository.findGenerationAccessStateByAccount("acct_standalone"))
                .thenReturn(Optional.of(neverMemberState("acct_standalone")));
        when(babyProfileMapper.findByAccountId("acct_standalone"))
                .thenReturn(profile("babyprof_standalone", "acct_standalone", "独立宝宝"));

        var subject = service.resolve("sess_standalone");

        assertThat(subject.actorAccountId()).isEqualTo("acct_standalone");
        assertThat(subject.ownerAccountId()).isEqualTo("acct_standalone");
        assertThat(subject.profileId()).isEqualTo("babyprof_standalone");
        assertThat(subject.householdId()).isNull();
        assertThat(subject.actorRole()).isEqualTo("primary_caregiver");
    }

    @Test
    void unknownActiveRoleIsRejectedBeforeProfileDisclosure() {
        stubAcceptedSession("sess_unknown_role", "acct_unknown_role");
        when(householdRepository.findGenerationAccessStateByAccount("acct_unknown_role"))
                .thenReturn(Optional.of(activeState("household_unknown", "acct_unknown_role", "unknown")));

        assertHouseholdAccessRequired(() -> service.resolve("sess_unknown_role"));

        verify(babyProfileMapper, never()).findByAccountId(anyString());
        verify(babyProfileMapper, never()).findSharedByHouseholdMemberAccountId(anyString());
    }

    @Test
    void missingSharedProfileHasDedicatedPrivacySafeError() {
        stubAcceptedSession("sess_missing_shared", "acct_caregiver");
        when(householdRepository.findGenerationAccessStateByAccount("acct_caregiver"))
                .thenReturn(Optional.of(activeState("household_primary", "acct_caregiver", "caregiver")));
        when(babyProfileMapper.findSharedByHouseholdMemberAccountId("acct_caregiver"))
                .thenReturn(null);

        assertThatThrownBy(() -> service.resolve("sess_missing_shared"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.NOT_FOUND);
                    assertThat(contract.code()).isEqualTo("shared_profile_unavailable");
                    assertPrivacySafe(
                            contract,
                            "小满",
                            "acct_caregiver",
                            "acct_primary",
                            "babyprof_primary",
                            "household_primary"
                    );
                });
        verify(babyProfileMapper, never()).findByAccountId(anyString());
    }

    @Test
    void inactiveMembershipCannotFallbackToHistoricalOwnProfile() {
        stubAcceptedSession("sess_inactive_membership", "acct_caregiver");
        when(householdRepository.findGenerationAccessStateByAccount("acct_caregiver"))
                .thenReturn(Optional.of(inactiveMembershipState("household_primary", "acct_caregiver", "caregiver")));
        assertHouseholdAccessRequired(() -> service.resolve("sess_inactive_membership"));

        verify(babyProfileMapper, never()).findByAccountId(anyString());
        verify(babyProfileMapper, never()).findSharedByHouseholdMemberAccountId(anyString());
    }

    @Test
    void inactiveHouseholdCannotFallbackToHistoricalOwnProfile() {
        stubAcceptedSession("sess_inactive_household", "acct_caregiver");
        when(householdRepository.findGenerationAccessStateByAccount("acct_caregiver"))
                .thenReturn(Optional.of(inactiveHouseholdState("household_revoked", "acct_caregiver", "caregiver")));
        assertHouseholdAccessRequired(() -> service.resolve("sess_inactive_household"));

        verify(babyProfileMapper, never()).findByAccountId(anyString());
        verify(babyProfileMapper, never()).findSharedByHouseholdMemberAccountId(anyString());
    }

    @Test
    void invalidSessionStopsBeforeHouseholdOrProfileLookup() {
        var failure = new ContractException(HttpStatus.UNAUTHORIZED, "invalid_session", "session 不存在或已失效。");
        when(authConsentSyncService.requireAcceptedConsumerSession(eq("sess_invalid"), anyString()))
                .thenThrow(failure);

        assertThatThrownBy(() -> service.resolve("sess_invalid")).isSameAs(failure);

        verify(householdRepository, never()).findGenerationAccessStateByAccount(anyString());
        verify(babyProfileMapper, never()).findByAccountId(anyString());
        verify(babyProfileMapper, never()).findSharedByHouseholdMemberAccountId(anyString());
    }

    @Test
    void profileValuesAreTrimmedAndAllowedOptionsArePreserved() {
        stubAcceptedSession("sess_normalized", "acct_primary");
        when(householdRepository.findGenerationAccessStateByAccount("acct_primary"))
                .thenReturn(Optional.of(activeState(" household_primary ", "acct_primary", "primary_caregiver")));
        when(babyProfileMapper.findByAccountId("acct_primary"))
                .thenReturn(profileWithValues(
                        " babyprof_primary ",
                        " acct_primary ",
                        " 小满 ",
                        " m7_11 ",
                        " calmer_care "
                ));

        var subject = service.resolve("sess_normalized");

        assertThat(subject.ownerAccountId()).isEqualTo("acct_primary");
        assertThat(subject.profileId()).isEqualTo("babyprof_primary");
        assertThat(subject.babyName()).isEqualTo("小满");
        assertThat(subject.ageRange()).isEqualTo(BabyProfileOptions.AGE_RANGE_M7_11);
        assertThat(subject.parentGoal()).isEqualTo(BabyProfileOptions.PARENT_GOAL_CALMER_CARE);
        assertThat(subject.householdId()).isEqualTo("household_primary");
    }

    @Test
    void invalidAgeRangeFailsClosedWithoutProfileIdentity() {
        stubAcceptedSession("sess_corrupt_profile", "acct_primary");
        when(householdRepository.findGenerationAccessStateByAccount("acct_primary"))
                .thenReturn(Optional.of(activeState("household_primary", "acct_primary", "primary_caregiver")));
        when(babyProfileMapper.findByAccountId("acct_primary"))
                .thenReturn(profileWithValues(
                        "babyprof_corrupt",
                        "acct_primary",
                        "秘密宝宝",
                        "m99",
                        "calmer_care"
                ));

        assertThatThrownBy(() -> service.resolve("sess_corrupt_profile"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.NOT_FOUND);
                    assertThat(contract.code()).isEqualTo("profile_unavailable");
                    assertPrivacySafe(contract, "秘密宝宝", "acct_primary", "babyprof_corrupt", "household_primary");
                });
    }

    @Test
    void invalidParentGoalFailsClosedWithoutProfileIdentity() {
        stubAcceptedSession("sess_corrupt_goal", "acct_primary");
        when(householdRepository.findGenerationAccessStateByAccount("acct_primary"))
                .thenReturn(Optional.of(activeState("household_primary", "acct_primary", "primary_caregiver")));
        when(babyProfileMapper.findByAccountId("acct_primary"))
                .thenReturn(profileWithValues(
                        "babyprof_corrupt_goal",
                        "acct_primary",
                        "秘密宝宝",
                        "m7_11",
                        "unknown_goal"
                ));

        assertThatThrownBy(() -> service.resolve("sess_corrupt_goal"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.NOT_FOUND);
                    assertThat(contract.code()).isEqualTo("profile_unavailable");
                    assertPrivacySafe(contract, "秘密宝宝", "acct_primary", "babyprof_corrupt_goal", "household_primary");
                });
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("incompleteProfileCases")
    void incompleteProfileFieldsFailClosedByResolvedRole(
            String caseName,
            String role,
            String accessState,
            String householdId,
            String ageRange,
            String parentGoal,
            String expectedCode
    ) {
        var actorAccountId = "caregiver".equals(role) ? "acct_caregiver" : "acct_primary";
        stubAcceptedSession("sess_incomplete", actorAccountId);
        var state = "never_member".equals(accessState)
                ? neverMemberState(actorAccountId)
                : activeState(householdId, actorAccountId, role);
        when(householdRepository.findGenerationAccessStateByAccount(actorAccountId))
                .thenReturn(Optional.of(state));
        var profile = profileWithValues(
                "babyprof_incomplete",
                "caregiver".equals(role) ? "acct_primary" : actorAccountId,
                "秘密宝宝",
                ageRange,
                parentGoal
        );
        if ("caregiver".equals(role)) {
            when(babyProfileMapper.findSharedByHouseholdMemberAccountId(actorAccountId)).thenReturn(profile);
        } else {
            when(babyProfileMapper.findByAccountId(actorAccountId)).thenReturn(profile);
        }

        assertThatThrownBy(() -> service.resolve("sess_incomplete"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.NOT_FOUND);
                    assertThat(contract.code()).isEqualTo(expectedCode);
                    assertPrivacySafe(
                            contract,
                            "秘密宝宝",
                            "acct_caregiver",
                            "acct_primary",
                            "babyprof_incomplete",
                            "household_primary"
                    );
                });
    }

    private static Stream<Arguments> incompleteProfileCases() {
        return Stream.of(
                Arguments.of("caregiver null age", "caregiver", "active_membership", "household_primary", null, "calmer_care", "shared_profile_unavailable"),
                Arguments.of("caregiver blank age", "caregiver", "active_membership", "household_primary", "  ", "calmer_care", "shared_profile_unavailable"),
                Arguments.of("caregiver null goal", "caregiver", "active_membership", "household_primary", "m7_11", null, "shared_profile_unavailable"),
                Arguments.of("caregiver blank goal", "caregiver", "active_membership", "household_primary", "m7_11", "  ", "shared_profile_unavailable"),
                Arguments.of("primary null age", "primary_caregiver", "active_membership", "household_primary", null, "calmer_care", "profile_unavailable"),
                Arguments.of("primary blank age", "primary_caregiver", "active_membership", "household_primary", "  ", "calmer_care", "profile_unavailable"),
                Arguments.of("primary null goal", "primary_caregiver", "active_membership", "household_primary", "m7_11", null, "profile_unavailable"),
                Arguments.of("primary blank goal", "primary_caregiver", "active_membership", "household_primary", "m7_11", "  ", "profile_unavailable"),
                Arguments.of("standalone null age", "primary_caregiver", "never_member", null, null, "calmer_care", "profile_unavailable"),
                Arguments.of("standalone blank age", "primary_caregiver", "never_member", null, "  ", "calmer_care", "profile_unavailable"),
                Arguments.of("standalone null goal", "primary_caregiver", "never_member", null, "m7_11", null, "profile_unavailable"),
                Arguments.of("standalone blank goal", "primary_caregiver", "never_member", null, "m7_11", "  ", "profile_unavailable")
        );
    }

    @Test
    void missingPersonalProfileHasProfileUnavailableError() {
        stubAcceptedSession("sess_missing_profile", "acct_primary");
        when(householdRepository.findGenerationAccessStateByAccount("acct_primary"))
                .thenReturn(Optional.of(neverMemberState("acct_primary")));
        when(babyProfileMapper.findByAccountId("acct_primary")).thenReturn(null);

        assertThatThrownBy(() -> service.resolve("sess_missing_profile"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.NOT_FOUND);
                    assertThat(contract.code()).isEqualTo("profile_unavailable");
                    assertPrivacySafe(contract, "acct_primary", "babyprof_primary", "household_primary");
                });
    }

    @Test
    void generationSubjectToStringDoesNotExposePersonalOrHouseholdIdentifiers() {
        var subject = new GenerationSubject(
                "acct_actor_secret",
                "acct_owner_secret",
                "babyprof_secret",
                4,
                "秘密宝宝",
                "m7_11",
                "calmer_care",
                "household_secret",
                "caregiver"
        );

        assertThat(subject.toString())
                .doesNotContain(
                        "acct_actor_secret",
                        "acct_owner_secret",
                        "babyprof_secret",
                        "秘密宝宝",
                        "household_secret"
                );
    }

    private void stubAcceptedSession(String sessionId, String accountId) {
        when(authConsentSyncService.requireAcceptedConsumerSession(eq(sessionId), anyString()))
                .thenReturn(new AuthConsentSyncService.ConsumerSessionView(
                        accountId,
                        sessionId,
                        "install_opaque",
                        "accepted"
                ));
    }

    private CaregiverInviteRepository.GenerationAccessStateRow activeState(
            String householdId,
            String accountId,
            String role
    ) {
        return new CaregiverInviteRepository.GenerationAccessStateRow(
                "active_membership",
                householdId,
                accountId,
                role
        );
    }

    private CaregiverInviteRepository.GenerationAccessStateRow inactiveMembershipState(
            String householdId,
            String accountId,
            String role
    ) {
        return new CaregiverInviteRepository.GenerationAccessStateRow(
                "inactive_membership",
                householdId,
                accountId,
                role
        );
    }

    private CaregiverInviteRepository.GenerationAccessStateRow inactiveHouseholdState(
            String householdId,
            String accountId,
            String role
    ) {
        return new CaregiverInviteRepository.GenerationAccessStateRow(
                "inactive_household",
                householdId,
                accountId,
                role
        );
    }

    private CaregiverInviteRepository.GenerationAccessStateRow neverMemberState(String accountId) {
        return new CaregiverInviteRepository.GenerationAccessStateRow(
                "never_member",
                null,
                accountId,
                null
        );
    }

    private BabyProfileRow profile(String profileId, String accountId, String babyName) {
        return profileWithValues(profileId, accountId, babyName, "m7_11", "calmer_care");
    }

    private BabyProfileRow profileWithValues(
            String profileId,
            String accountId,
            String babyName,
            String ageRange,
            String parentGoal
    ) {
        return new BabyProfileRow(
                profileId,
                accountId,
                babyName,
                ageRange,
                parentGoal,
                "daily_care",
                "bath_time",
                "bath_time",
                "bath_time_warm_water",
                "bath_time_warm_water",
                "catalog",
                "completed",
                NOW,
                7,
                NOW,
                NOW
        );
    }

    private void assertHouseholdAccessRequired(Runnable action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.FORBIDDEN);
                    assertThat(contract.code()).isEqualTo("household_access_required");
                });
    }

    private void assertPrivacySafe(ContractException contract, String... secrets) {
        var rendered = contract.getMessage() + " " + contract.details();
        assertThat(rendered).doesNotContain(secrets);
    }
}
