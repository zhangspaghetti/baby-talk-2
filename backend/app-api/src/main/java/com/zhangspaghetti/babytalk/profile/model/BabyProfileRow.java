package com.zhangspaghetti.babytalk.profile.model;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.OffsetDateTime;

@TableName("baby_profiles")
public class BabyProfileRow {

    @TableId(value = "profile_id", type = IdType.INPUT)
    private String profileId;
    private String accountId;
    private String babyName;
    private String ageRange;
    private String parentGoal;
    private String starterSceneId;
    private String starterMomentId;
    private String starterActivityId;
    private String starterUtteranceId;
    private String starterPhraseId;
    private String starterSource;
    private String onboardingState;
    private OffsetDateTime onboardingCompletedAt;
    private int version;
    private OffsetDateTime createdAt;
    private OffsetDateTime updatedAt;

    public BabyProfileRow() {
    }

    public BabyProfileRow(
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
            OffsetDateTime onboardingCompletedAt,
            int version,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
        this.profileId = profileId;
        this.accountId = accountId;
        this.babyName = babyName;
        this.ageRange = ageRange;
        this.parentGoal = parentGoal;
        this.starterSceneId = starterSceneId;
        this.starterMomentId = starterMomentId;
        this.starterActivityId = starterActivityId;
        this.starterUtteranceId = starterUtteranceId;
        this.starterPhraseId = starterPhraseId;
        this.starterSource = starterSource;
        this.onboardingState = onboardingState;
        this.onboardingCompletedAt = onboardingCompletedAt;
        this.version = version;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    public String profileId() { return profileId; }
    public String accountId() { return accountId; }
    public String babyName() { return babyName; }
    public String ageRange() { return ageRange; }
    public String parentGoal() { return parentGoal; }
    public String starterSceneId() { return starterSceneId; }
    public String starterMomentId() { return starterMomentId; }
    public String starterActivityId() { return starterActivityId; }
    public String starterUtteranceId() { return starterUtteranceId; }
    public String starterPhraseId() { return starterPhraseId; }
    public String starterSource() { return starterSource; }
    public String onboardingState() { return onboardingState; }
    public OffsetDateTime onboardingCompletedAt() { return onboardingCompletedAt; }
    public int version() { return version; }
    public OffsetDateTime createdAt() { return createdAt; }
    public OffsetDateTime updatedAt() { return updatedAt; }

    public String getProfileId() { return profileId; }
    public void setProfileId(String profileId) { this.profileId = profileId; }
    public String getAccountId() { return accountId; }
    public void setAccountId(String accountId) { this.accountId = accountId; }
    public String getBabyName() { return babyName; }
    public void setBabyName(String babyName) { this.babyName = babyName; }
    public String getAgeRange() { return ageRange; }
    public void setAgeRange(String ageRange) { this.ageRange = ageRange; }
    public String getParentGoal() { return parentGoal; }
    public void setParentGoal(String parentGoal) { this.parentGoal = parentGoal; }
    public String getStarterSceneId() { return starterSceneId; }
    public void setStarterSceneId(String starterSceneId) { this.starterSceneId = starterSceneId; }
    public String getStarterMomentId() { return starterMomentId; }
    public void setStarterMomentId(String starterMomentId) { this.starterMomentId = starterMomentId; }
    public String getStarterActivityId() { return starterActivityId; }
    public void setStarterActivityId(String starterActivityId) { this.starterActivityId = starterActivityId; }
    public String getStarterUtteranceId() { return starterUtteranceId; }
    public void setStarterUtteranceId(String starterUtteranceId) { this.starterUtteranceId = starterUtteranceId; }
    public String getStarterPhraseId() { return starterPhraseId; }
    public void setStarterPhraseId(String starterPhraseId) { this.starterPhraseId = starterPhraseId; }
    public String getStarterSource() { return starterSource; }
    public void setStarterSource(String starterSource) { this.starterSource = starterSource; }
    public String getOnboardingState() { return onboardingState; }
    public void setOnboardingState(String onboardingState) { this.onboardingState = onboardingState; }
    public OffsetDateTime getOnboardingCompletedAt() { return onboardingCompletedAt; }
    public void setOnboardingCompletedAt(OffsetDateTime onboardingCompletedAt) { this.onboardingCompletedAt = onboardingCompletedAt; }
    public int getVersion() { return version; }
    public void setVersion(int version) { this.version = version; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(OffsetDateTime updatedAt) { this.updatedAt = updatedAt; }
}
