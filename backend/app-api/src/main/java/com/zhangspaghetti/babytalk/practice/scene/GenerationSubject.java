package com.zhangspaghetti.babytalk.practice.scene;

/**
 * Server-resolved identity and baby profile used by scene generation.
 *
 * <p>The values are intentionally kept out of logs and error details because
 * this object contains account, household, profile, and baby information.</p>
 */
public record GenerationSubject(
        String actorAccountId,
        String ownerAccountId,
        String profileId,
        int profileVersion,
        String babyName,
        String ageRange,
        String parentGoal,
        String householdId,
        String actorRole
) {

    @Override
    public String toString() {
        return "GenerationSubject{resolved=true}";
    }
}
