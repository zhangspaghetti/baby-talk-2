package com.zhangspaghetti.babytalk.service;

import java.time.Instant;
import java.util.Optional;
import org.springframework.stereotype.Repository;

@Repository
public class OnboardingProfileRepository {

    private final OnboardingProfileMapper mapper;

    public OnboardingProfileRepository(OnboardingProfileMapper mapper) {
        this.mapper = mapper;
    }

    public Optional<ProfileRow> findByAccountId(String accountId) {
        return Optional.ofNullable(mapper.findByAccountId(accountId));
    }

    public void insert(ProfileRow row) {
        mapper.insert(row);
    }

    public int updateIfVersionMatches(String accountId, int expectedVersion, ProfilePatch patch, Instant updatedAt) {
        return mapper.updateIfVersionMatches(accountId, expectedVersion, patch, updatedAt);
    }

    public Optional<Integer> findVersionByAccountId(String accountId) {
        return Optional.ofNullable(mapper.findVersionByAccountId(accountId));
    }

    public int deleteByAccountId(String accountId) {
        return mapper.deleteByAccountId(accountId);
    }

    public record ProfileRow(
            String profileId,
            String accountId,
            String babyName,
            String ageRange,
            String parentGoal,
            String starterSceneId,
            String starterMomentId,
            String starterActivityId,
            String starterUtteranceId,
            String starterPhraseId,
            String starterSource,
            String onboardingState,
            Instant onboardingCompletedAt,
            int version,
            Instant createdAt,
            Instant updatedAt
    ) {
    }

    public record ProfilePatch(
            String babyName,
            String ageRange,
            String parentGoal,
            String starterSceneId,
            String starterMomentId,
            String starterActivityId,
            String starterUtteranceId,
            String starterPhraseId,
            String starterSource,
            String onboardingState,
            Instant onboardingCompletedAt
    ) {
    }
}
