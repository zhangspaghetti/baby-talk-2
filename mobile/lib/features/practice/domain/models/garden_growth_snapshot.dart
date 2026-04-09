import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

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

class GardenFlowerSnapshot {
  const GardenFlowerSnapshot({
    required this.spaceId,
    required this.activityId,
    required this.title,
    required this.sceneTag,
    required this.summary,
    required this.stage,
    required this.totalEvents,
    required this.completedPhraseCount,
    required this.totalPhraseCount,
    required this.completedPhraseIds,
    required this.careNote,
    this.lastPracticedAt,
  });

  final String spaceId;
  final String activityId;
  final String title;
  final String sceneTag;
  final String summary;
  final GardenFlowerStage stage;
  final int totalEvents;
  final int completedPhraseCount;
  final int totalPhraseCount;
  final List<String> completedPhraseIds;
  final String careNote;
  final DateTime? lastPracticedAt;

  bool get isStarted => totalEvents > 0;

  bool get isCompleted =>
      totalPhraseCount > 0 && completedPhraseCount >= totalPhraseCount;
}

class GardenPatchSnapshot {
  const GardenPatchSnapshot({
    required this.spaceId,
    required this.title,
    required this.description,
    required this.stage,
    required this.totalKnownEvents,
    required this.startedActivityCount,
    required this.completedActivityCount,
    required this.totalActivityCount,
    required this.activities,
    required this.careNote,
    this.lastPracticedAt,
  });

  final String spaceId;
  final String title;
  final String description;
  final GardenPatchStage stage;
  final int totalKnownEvents;
  final int startedActivityCount;
  final int completedActivityCount;
  final int totalActivityCount;
  final List<GardenFlowerSnapshot> activities;
  final String careNote;
  final DateTime? lastPracticedAt;

  bool get isStarted => totalKnownEvents > 0;
}

class GrowthDiaryEntry {
  const GrowthDiaryEntry({
    required this.entryId,
    required this.kind,
    required this.occurredAt,
    required this.title,
    required this.body,
    required this.spaceId,
    required this.activityId,
  });

  final String entryId;
  final GrowthDiaryEntryKind kind;
  final DateTime occurredAt;
  final String title;
  final String body;
  final String spaceId;
  final String activityId;
}

class GrowthMilestoneSnapshot {
  const GrowthMilestoneSnapshot({
    required this.id,
    required this.title,
    required this.body,
    required this.sortOrder,
    this.achievedAt,
  });

  final String id;
  final String title;
  final String body;
  final int sortOrder;
  final DateTime? achievedAt;

  bool get isAchieved => achievedAt != null;
}

class LatestPracticeImpact {
  const LatestPracticeImpact({
    required this.eventKey,
    required this.occurredAt,
    required this.spaceId,
    required this.spaceTitle,
    required this.activityId,
    required this.activityTitle,
    required this.phraseId,
    required this.phraseTitle,
    required this.reactionType,
    required this.previousPatchStage,
    required this.currentPatchStage,
    required this.previousFlowerStage,
    required this.currentFlowerStage,
    required this.headline,
    required this.detail,
  });

  final String eventKey;
  final DateTime occurredAt;
  final String spaceId;
  final String spaceTitle;
  final String activityId;
  final String activityTitle;
  final String phraseId;
  final String phraseTitle;
  final BabyReactionType reactionType;
  final GardenPatchStage previousPatchStage;
  final GardenPatchStage currentPatchStage;
  final GardenFlowerStage previousFlowerStage;
  final GardenFlowerStage currentFlowerStage;
  final String headline;
  final String detail;

  bool get patchStageChanged => previousPatchStage != currentPatchStage;

  bool get flowerStageChanged => previousFlowerStage != currentFlowerStage;

  bool get changedAnyStage => patchStageChanged || flowerStageChanged;
}

class GardenGrowthSnapshot {
  const GardenGrowthSnapshot({
    required this.installationId,
    required this.spaces,
    required this.diaryEntries,
    required this.milestones,
    required this.latestImpact,
    required this.totalStoredEvents,
    required this.validEvents,
    required this.knownEvents,
    required this.skippedMalformedEvents,
    required this.skippedUnknownContentEvents,
    this.lastIssueMessage,
    this.projectionWarning,
  });

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

  final String? installationId;
  final List<GardenPatchSnapshot> spaces;
  final List<GrowthDiaryEntry> diaryEntries;
  final List<GrowthMilestoneSnapshot> milestones;
  final LatestPracticeImpact? latestImpact;
  final int totalStoredEvents;
  final int validEvents;
  final int knownEvents;
  final int skippedMalformedEvents;
  final int skippedUnknownContentEvents;
  final String? lastIssueMessage;
  final String? projectionWarning;

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
