package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.OffsetDateTime;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class CaregiverInviteRepositoryTest {

    private static final OffsetDateTime NOW = OffsetDateTime.parse("2026-08-16T03:00:00Z");

    @Mock
    private CaregiverInviteMapper mapper;

    private CaregiverInviteRepository repository;

    @BeforeEach
    void setUp() {
        repository = new CaregiverInviteRepository(mapper);
    }

    @Test
    void existingMembershipIsTheOnlyPrimaryHouseholdReturned() {
        var existing = member("household_existing", "acct_a");
        when(mapper.findActiveMembershipByAccount("acct_a")).thenReturn(existing);

        var result = repository.ensurePrimaryHousehold("acct_a", NOW);

        assertThat(result).isSameAs(existing);
        verify(mapper, never()).insertHousehold(any());
        verify(mapper, never()).insertMember(any());
    }

    @Test
    void concurrentPrimaryCreationReturnsTheMembershipCreatedByTheOtherRequest() {
        var concurrentMember = member("household_concurrent", "acct_a");
        when(mapper.findActiveMembershipByAccount("acct_a"))
                .thenReturn(null, concurrentMember);
        when(mapper.insertMemberIfAbsent(any())).thenReturn(0);

        var result = repository.ensurePrimaryHousehold("acct_a", NOW);

        assertThat(result).isSameAs(concurrentMember);
        var household = ArgumentCaptor.forClass(CaregiverInviteRepository.HouseholdRow.class);
        verify(mapper).insertHousehold(household.capture());
        verify(mapper).insertMemberIfAbsent(any());
        verify(mapper).deleteHouseholdIfUnassigned(household.getValue().householdId());
        assertThat(household.getValue().ownerAccountId()).isEqualTo("acct_a");
        assertThat(household.getValue().status()).isEqualTo("active");
    }

    private CaregiverInviteRepository.HouseholdMemberRow member(
            String householdId,
            String accountId
    ) {
        return new CaregiverInviteRepository.HouseholdMemberRow(
                1,
                householdId,
                accountId,
                "primary_caregiver",
                "active",
                null,
                NOW,
                null
        );
    }
}
