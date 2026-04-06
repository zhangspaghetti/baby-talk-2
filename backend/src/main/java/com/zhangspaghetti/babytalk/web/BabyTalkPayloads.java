package com.zhangspaghetti.babytalk.web;

import java.util.List;
import java.util.Map;

public final class BabyTalkPayloads {

    private BabyTalkPayloads() {
    }

    public record AppSnapshotResponse(
            String caregiverName,
            String childName,
            int childAgeMonths,
            String difficulty,
            boolean onboardingComplete,
            int growthPoints,
            int weeklyPhraseCount,
            int streakDays,
            List<String> earnedMilestoneIds,
            List<SpaceResponse> spaces,
            List<DiaryEntryResponse> diaryEntries,
            List<MilestoneEntryResponse> milestones,
            List<CoachSuggestionResponse> coachSuggestions
    ) {
    }

    public record AppActionResponse(
            AppSnapshotResponse snapshot,
            CelebrationMomentResponse celebration
    ) {
    }

    public record SpaceResponse(
            String id,
            String name,
            String subtitle,
            String iconKey,
            String colorHex,
            double mapOffsetX,
            double mapOffsetY,
            List<ActivityResponse> activities
    ) {
    }

    public record ActivityResponse(
            String id,
            String name,
            String shortLabel,
            String iconKey,
            double progress,
            String growthStage,
            List<PhraseResponse> phrases
    ) {
    }

    public record PhraseResponse(
            String id,
            String english,
            String chinese,
            boolean mastered
    ) {
    }

    public record DiaryEntryResponse(
            String title,
            String subtitle,
            String timeLabel,
            String type
    ) {
    }

    public record MilestoneEntryResponse(
            String title,
            String detail,
            String timeLabel
    ) {
    }

    public record CoachSuggestionResponse(
            String title,
            String detail
    ) {
    }

    public record CelebrationMomentResponse(
            String title,
            String detail,
            String activityName,
            int gainedPoints
    ) {
    }

    public record OnboardingRequest(
            String caregiverName,
            String childName,
            int childAgeMonths,
            String difficulty
    ) {
    }

    public record PracticeReactionRequest(
            String activityId,
            String phraseId,
            String reaction
    ) {
    }

    public record WaterPatchRequest(String spaceId) {
    }

    public record SessionResponse(String sessionId) {
    }

    public record AnalyticsBatchRequest(List<AnalyticsEventRequest> events) {
    }

    public record AnalyticsEventRequest(
            String eventId,
            String eventName,
            String screenName,
            String occurredAt,
            Map<String, Object> properties
    ) {
    }

    public record AnalyticsIngestResponse(int acceptedCount) {
    }

    public record RetentionWindowResponse(
            int days,
            int cohortUsers,
            int retainedUsers,
            double retentionRate
    ) {
    }

    public record RetentionSummaryResponse(List<RetentionWindowResponse> windows) {
    }

    public record CoachAskRequest(String prompt) {
    }

    public record CoachAskResponse(
            String answer,
            String suggestedPhraseEnglish,
            String suggestedPhraseChinese,
            String followUpPrompt
    ) {
    }

    public record ApiVersionResponse(
            String currentVersion,
            String minSupportedVersion,
            String requestedVersion,
            boolean upgradeRequired,
            String message
    ) {
    }
}