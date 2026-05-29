import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

part '../../../../generated/features/practice/domain/models/garden_growth_snapshot.freezed.dart';

enum GardenPatchStage { quiet, tended, rooted, glowing }

extension GardenPatchStageCopy on GardenPatchStage {
  String get label {
    switch (this) {
      case GardenPatchStage.quiet:
        return '安静等待';
      case GardenPatchStage.tended:
        return '刚被照料';
      case GardenPatchStage.rooted:
        return '正在扎根';
      case GardenPatchStage.glowing:
        return '温柔发亮';
    }
  }

  String get warmSummary {
    switch (this) {
      case GardenPatchStage.quiet:
        return '还没有练习记录，第一句开口就会让花圃醒来。';
      case GardenPatchStage.tended:
        return '花圃刚收到今天的第一点照料，继续保持轻声重复。';
      case GardenPatchStage.rooted:
        return '花圃已经开始扎根，宝宝会慢慢把英语和熟悉动作连起来。';
      case GardenPatchStage.glowing:
        return '这片花圃已经有了稳定节奏，可以反复回来浇灌。';
    }
  }
}

enum GardenFlowerStage { seed, sprout, growing, blooming, fullBloom }

extension GardenFlowerStageCopy on GardenFlowerStage {
  String get label {
    switch (this) {
      case GardenFlowerStage.seed:
        return '种子';
      case GardenFlowerStage.sprout:
        return '发芽';
      case GardenFlowerStage.growing:
        return '生长';
      case GardenFlowerStage.blooming:
        return '开花';
      case GardenFlowerStage.fullBloom:
        return '盛放';
    }
  }

  String get warmSummary {
    switch (this) {
      case GardenFlowerStage.seed:
        return '这朵花还在等第一句温柔的开口。';
      case GardenFlowerStage.sprout:
        return '第一句已经落下，花朵开始冒芽。';
      case GardenFlowerStage.growing:
        return '这朵花正在长高，继续把动作和语气连起来。';
      case GardenFlowerStage.blooming:
        return '整段短语已经连起来了，花朵正在开花。';
      case GardenFlowerStage.fullBloom:
        return '这朵花已经盛放，可以回来复习和加深熟悉感。';
    }
  }
}

enum GrowthDiaryEntryKind { practice, milestone }

@freezed
class GardenFlowerSnapshot with _$GardenFlowerSnapshot {
  const GardenFlowerSnapshot._();

  const factory GardenFlowerSnapshot({
    required String spaceId,
    required String activityId,
    required String title,
    required String sceneTag,
    required String summary,
    required GardenFlowerStage stage,
    required int totalEvents,
    required int completedPhraseCount,
    required int totalPhraseCount,
    required List<String> completedPhraseIds,
    required String careNote,
    DateTime? lastPracticedAt,
  }) = _GardenFlowerSnapshot;

  bool get isStarted => totalEvents > 0;

  bool get isCompleted =>
      totalPhraseCount > 0 && completedPhraseCount >= totalPhraseCount;
}

@freezed
class GardenPatchSnapshot with _$GardenPatchSnapshot {
  const GardenPatchSnapshot._();

  const factory GardenPatchSnapshot({
    required String spaceId,
    required String title,
    required String description,
    required GardenPatchStage stage,
    required int totalKnownEvents,
    required int startedActivityCount,
    required int completedActivityCount,
    required int totalActivityCount,
    required List<GardenFlowerSnapshot> activities,
    required String careNote,
    DateTime? lastPracticedAt,
  }) = _GardenPatchSnapshot;

  bool get isStarted => totalKnownEvents > 0;
}

@freezed
class GrowthDiaryEntry with _$GrowthDiaryEntry {
  const factory GrowthDiaryEntry({
    required String entryId,
    required GrowthDiaryEntryKind kind,
    required DateTime occurredAt,
    required String title,
    required String body,
    required String spaceId,
    required String activityId,
  }) = _GrowthDiaryEntry;
}

@freezed
class GrowthMilestoneSnapshot with _$GrowthMilestoneSnapshot {
  const GrowthMilestoneSnapshot._();

  const factory GrowthMilestoneSnapshot({
    required String id,
    required String title,
    required String body,
    required int sortOrder,
    DateTime? achievedAt,
    String? remainingHint,
  }) = _GrowthMilestoneSnapshot;

  bool get isAchieved => achievedAt != null;
}

@freezed
class LatestPracticeImpact with _$LatestPracticeImpact {
  const LatestPracticeImpact._();

  const factory LatestPracticeImpact({
    required String eventKey,
    required DateTime occurredAt,
    required String spaceId,
    required String spaceTitle,
    required String activityId,
    required String activityTitle,
    required String phraseId,
    required String phraseTitle,
    required BabyReactionType reactionType,
    required GardenPatchStage previousPatchStage,
    required GardenPatchStage currentPatchStage,
    required GardenFlowerStage previousFlowerStage,
    required GardenFlowerStage currentFlowerStage,
    required String headline,
    required String detail,
  }) = _LatestPracticeImpact;

  bool get patchStageChanged => previousPatchStage != currentPatchStage;

  bool get flowerStageChanged => previousFlowerStage != currentFlowerStage;

  bool get changedAnyStage => patchStageChanged || flowerStageChanged;
}

@freezed
class GardenGrowthSnapshot with _$GardenGrowthSnapshot {
  const GardenGrowthSnapshot._();

  const factory GardenGrowthSnapshot({
    required String? installationId,
    required List<GardenPatchSnapshot> spaces,
    required List<GrowthDiaryEntry> diaryEntries,
    required List<GrowthMilestoneSnapshot> milestones,
    required LatestPracticeImpact? latestImpact,
    required int totalStoredEvents,
    required int validEvents,
    required int knownEvents,
    required int skippedMalformedEvents,
    required int skippedUnknownContentEvents,
    String? lastIssueMessage,
    String? projectionWarning,
  }) = _GardenGrowthSnapshot;

  factory GardenGrowthSnapshot.empty({String? installationId}) {
    return GardenGrowthSnapshot(
      installationId: installationId,
      spaces: const <GardenPatchSnapshot>[],
      diaryEntries: const <GrowthDiaryEntry>[],
      milestones: const <GrowthMilestoneSnapshot>[],
      latestImpact: null,
      totalStoredEvents: 0,
      validEvents: 0,
      knownEvents: 0,
      skippedMalformedEvents: 0,
      skippedUnknownContentEvents: 0,
    );
  }

  bool get isEmpty => knownEvents == 0;

  bool get hasIssues =>
      skippedMalformedEvents > 0 ||
      skippedUnknownContentEvents > 0 ||
      (projectionWarning?.trim().isNotEmpty ?? false);

  GardenPatchSnapshot? get primarySpace => spaces.isEmpty ? null : spaces.first;

  GardenFlowerSnapshot? get primaryActivity {
    final space = primarySpace;
    if (space == null || space.activities.isEmpty) {
      return null;
    }
    return space.activities.first;
  }
}
