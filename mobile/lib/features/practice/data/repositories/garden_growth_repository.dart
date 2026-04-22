import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

class GardenGrowthRepository {
  GardenGrowthRepository({
    required PracticeRepository practiceRepository,
    required AssetPhraseService assetPhraseService,
  }) : _practiceRepository = practiceRepository,
       _assetPhraseService = assetPhraseService;

  final PracticeRepository _practiceRepository;
  final AssetPhraseService _assetPhraseService;

  Future<GardenGrowthSnapshot> buildSnapshot() async {
    final content = await _assetPhraseService.loadSeedContent();
    final inspection = await _practiceRepository.inspectEventLog();

    final spaceStates = <String, _SpaceProjectionState>{
      for (final space in content.spaces)
        space.id: _SpaceProjectionState.fromSeed(space),
    };
    final activityStates = <_ActivityKey, _ActivityProjectionState>{};
    final phraseRefs = <_PhraseKey, _PhraseReference>{};

    for (final space in content.spaces) {
      for (final activity in space.activities) {
        final activityKey = _ActivityKey(space.id, activity.id);
        activityStates[activityKey] = _ActivityProjectionState.fromSeed(
          space: space,
          activity: activity,
        );
        for (final phrase in activity.phrases) {
          phraseRefs[_PhraseKey(
            space.id,
            activity.id,
            phrase.id,
          )] = _PhraseReference(
            space: space,
            activity: activity,
            phrase: phrase,
          );
        }
      }
    }

    final diaryEntries = <GrowthDiaryEntry>[];
    final milestoneTimes = <String, DateTime>{};
    var knownEvents = 0;
    var skippedUnknownContentEvents = 0;
    var sawImitated = false;
    LatestPracticeImpact? latestImpact;

    for (final event in inspection.validEvents) {
      final phraseRef =
          phraseRefs[_PhraseKey(
            event.spaceId,
            event.activityId,
            event.phraseId,
          )];
      if (phraseRef == null) {
        skippedUnknownContentEvents += 1;
        continue;
      }

      final activityKey = _ActivityKey(event.spaceId, event.activityId);
      final activityState = activityStates[activityKey]!;
      final spaceState = spaceStates[event.spaceId]!;
      final previousFlowerStage = _deriveFlowerStage(activityState);
      final previousPatchStage = _derivePatchStage(spaceState);
      final wasStarted = activityState.isStarted;
      final wasCompleted = activityState.isCompleted;
      final wasSpaceStarted = spaceState.totalKnownEvents > 0;
      final hadImitated = sawImitated;

      activityState.record(event);
      spaceState.record(
        activityId: event.activityId,
        eventTime: event.clientTimestamp,
        activityCompleted: activityState.isCompleted,
      );
      knownEvents += 1;
      sawImitated =
          sawImitated || event.reactionType == BabyReactionType.imitated;

      final currentFlowerStage = _deriveFlowerStage(activityState);
      final currentPatchStage = _derivePatchStage(spaceState);

      latestImpact = LatestPracticeImpact(
        eventKey: event.eventKey,
        occurredAt: event.clientTimestamp,
        spaceId: phraseRef.space.id,
        spaceTitle: phraseRef.space.title,
        activityId: phraseRef.activity.id,
        activityTitle: phraseRef.activity.title,
        phraseId: phraseRef.phrase.id,
        phraseTitle: phraseRef.phrase.english,
        reactionType: event.reactionType,
        previousPatchStage: previousPatchStage,
        currentPatchStage: currentPatchStage,
        previousFlowerStage: previousFlowerStage,
        currentFlowerStage: currentFlowerStage,
        headline: _buildImpactHeadline(
          phraseTitle: phraseRef.phrase.english,
          activityTitle: phraseRef.activity.title,
          previousFlowerStage: previousFlowerStage,
          currentFlowerStage: currentFlowerStage,
        ),
        detail: _buildImpactDetail(
          spaceTitle: phraseRef.space.title,
          previousPatchStage: previousPatchStage,
          currentPatchStage: currentPatchStage,
          reactionType: event.reactionType,
        ),
      );

      diaryEntries.add(
        GrowthDiaryEntry(
          entryId: event.eventKey,
          kind: GrowthDiaryEntryKind.practice,
          occurredAt: event.clientTimestamp,
          title: phraseRef.activity.title,
          body: _buildPracticeDiaryBody(
            phraseTitle: phraseRef.phrase.english,
            reactionType: event.reactionType,
            flowerStage: currentFlowerStage,
          ),
          spaceId: phraseRef.space.id,
          activityId: phraseRef.activity.id,
        ),
      );

      if (knownEvents == 1) {
        milestoneTimes['first_opening'] = event.clientTimestamp;
      }
      if (!wasSpaceStarted && spaceState.totalKnownEvents == 1) {
        milestoneTimes['space_${event.spaceId}_awakened'] =
            event.clientTimestamp;
      }
      if (!wasStarted) {
        milestoneTimes['activity_${event.activityId}_started'] =
            event.clientTimestamp;
      }
      if (!hadImitated && event.reactionType == BabyReactionType.imitated) {
        milestoneTimes['first_imitated'] = event.clientTimestamp;
      }
      if (!wasCompleted && activityState.isCompleted) {
        milestoneTimes['activity_${event.activityId}_completed'] =
            event.clientTimestamp;
      }
    }

    final spaces = <GardenPatchSnapshot>[];
    for (final space in content.spaces) {
      final spaceState = spaceStates[space.id]!;
      final patchStage = _derivePatchStage(spaceState);
      final activities = <GardenFlowerSnapshot>[];
      for (final activity in space.activities) {
        final state = activityStates[_ActivityKey(space.id, activity.id)]!;
        final flowerStage = _deriveFlowerStage(state);
        activities.add(
          GardenFlowerSnapshot(
            spaceId: space.id,
            activityId: activity.id,
            title: activity.title,
            sceneTag: activity.sceneTag,
            summary: activity.summary,
            stage: flowerStage,
            totalEvents: state.totalEvents,
            completedPhraseCount: state.completedPhraseIds.length,
            totalPhraseCount: state.totalPhraseCount,
            completedPhraseIds: List.unmodifiable(
              state.completedPhraseIds.toList(growable: false),
            ),
            careNote: flowerStage.warmSummary,
            lastPracticedAt: state.lastEventTime,
          ),
        );
      }
      spaces.add(
        GardenPatchSnapshot(
          spaceId: space.id,
          title: space.title,
          description: space.description,
          stage: patchStage,
          totalKnownEvents: spaceState.totalKnownEvents,
          startedActivityCount: spaceState.startedActivityIds.length,
          completedActivityCount: spaceState.completedActivityIds.length,
          totalActivityCount: space.activities.length,
          activities: List.unmodifiable(activities),
          careNote: patchStage.warmSummary,
          lastPracticedAt: spaceState.lastEventTime,
        ),
      );
    }

    final milestones = _buildMilestones(
      content: content,
      milestoneTimes: milestoneTimes,
    );

    diaryEntries.sort((left, right) {
      final byTime = right.occurredAt.compareTo(left.occurredAt);
      if (byTime != 0) {
        return byTime;
      }
      return left.entryId.compareTo(right.entryId);
    });

    return GardenGrowthSnapshot(
      installationId: inspection.installationId,
      spaces: List.unmodifiable(spaces),
      diaryEntries: List.unmodifiable(diaryEntries),
      milestones: List.unmodifiable(milestones),
      latestImpact: latestImpact,
      totalStoredEvents: inspection.storedEventCount,
      validEvents: inspection.validEventCount,
      knownEvents: knownEvents,
      skippedMalformedEvents: inspection.skippedEventCount,
      skippedUnknownContentEvents: skippedUnknownContentEvents,
      lastIssueMessage: inspection.lastIssue?.message,
      projectionWarning: _buildProjectionWarning(
        skippedMalformedEvents: inspection.skippedEventCount,
        skippedUnknownContentEvents: skippedUnknownContentEvents,
      ),
    );
  }

  List<GrowthMilestoneSnapshot> _buildMilestones({
    required SeedContentBundle content,
    required Map<String, DateTime> milestoneTimes,
  }) {
    final definitions = <_MilestoneDefinition>[
      const _MilestoneDefinition(
        id: 'first_opening',
        title: '第一句已经说出口',
        body: '从这一句开始，花园会记住每一次温柔的练习。',
        sortOrder: 0,
      ),
      const _MilestoneDefinition(
        id: 'first_imitated',
        title: '宝宝开始回应你的声音',
        body: '一旦出现模仿反应，成长页会把它记成一次暖暖的回声。',
        sortOrder: 1,
      ),
    ];

    var sortOrder = definitions.length;
    final expanded = <_MilestoneDefinition>[...definitions];
    for (final space in content.spaces) {
      expanded.add(
        _MilestoneDefinition(
          id: 'space_${space.id}_awakened',
          title: '${space.title} 花圃醒来了',
          body: '这个空间已经收到第一点照料，后续练习会继续在这里生长。',
          sortOrder: sortOrder++,
        ),
      );
      for (final activity in space.activities) {
        expanded.add(
          _MilestoneDefinition(
            id: 'activity_${activity.id}_started',
            title: '开始照料“${activity.title}”',
            body: '你已经把第一句放进真实动作里，这朵花开始冒芽。',
            sortOrder: sortOrder++,
          ),
        );
        expanded.add(
          _MilestoneDefinition(
            id: 'activity_${activity.id}_completed',
            title: '“${activity.title}” 完整开过一遍',
            body: '这一段短语已经能顺着一次完整照护流程说下来。',
            sortOrder: sortOrder++,
          ),
        );
      }
    }

    return expanded
        .map(
          (definition) => GrowthMilestoneSnapshot(
            id: definition.id,
            title: definition.title,
            body: definition.body,
            sortOrder: definition.sortOrder,
            achievedAt: milestoneTimes[definition.id],
          ),
        )
        .toList(growable: false);
  }

  GardenFlowerStage _deriveFlowerStage(_ActivityProjectionState state) {
    if (state.totalEvents == 0) {
      return GardenFlowerStage.seed;
    }
    if (state.isCompleted) {
      if (state.hasImitated || state.totalEvents > state.totalPhraseCount) {
        return GardenFlowerStage.fullBloom;
      }
      return GardenFlowerStage.blooming;
    }
    if (state.completedPhraseIds.length >= 2 || state.totalEvents >= 2) {
      return GardenFlowerStage.growing;
    }
    return GardenFlowerStage.sprout;
  }

  GardenPatchStage _derivePatchStage(_SpaceProjectionState state) {
    if (state.totalKnownEvents == 0) {
      return GardenPatchStage.quiet;
    }
    if (state.totalActivityCount > 0 &&
        state.completedActivityIds.length >= state.totalActivityCount) {
      return GardenPatchStage.glowing;
    }
    if (state.totalKnownEvents >= 2 || state.startedActivityIds.isNotEmpty) {
      return GardenPatchStage.rooted;
    }
    return GardenPatchStage.tended;
  }

  String? _buildProjectionWarning({
    required int skippedMalformedEvents,
    required int skippedUnknownContentEvents,
  }) {
    final parts = <String>[];
    if (skippedMalformedEvents > 0) {
      parts.add('跳过 $skippedMalformedEvents 条损坏事件');
    }
    if (skippedUnknownContentEvents > 0) {
      parts.add('跳过 $skippedUnknownContentEvents 条未知内容事件');
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join('；');
  }

  String _buildImpactHeadline({
    required String phraseTitle,
    required String activityTitle,
    required GardenFlowerStage previousFlowerStage,
    required GardenFlowerStage currentFlowerStage,
  }) {
    if (previousFlowerStage != currentFlowerStage) {
      return '“$phraseTitle” 让“$activityTitle”从${previousFlowerStage.label}走到${currentFlowerStage.label}。';
    }
    return '这次开口又给“$activityTitle”浇了一点水。';
  }

  String _buildImpactDetail({
    required String spaceTitle,
    required GardenPatchStage previousPatchStage,
    required GardenPatchStage currentPatchStage,
    required BabyReactionType reactionType,
  }) {
    final reactionLabel = _labelForReaction(reactionType);
    if (previousPatchStage != currentPatchStage) {
      return '$spaceTitle 花圃现在是“${currentPatchStage.label}”，这次记录到的是“$reactionLabel”。';
    }
    return '花圃保持在“${currentPatchStage.label}”，宝宝这次是“$reactionLabel”。';
  }

  String _buildPracticeDiaryBody({
    required String phraseTitle,
    required BabyReactionType reactionType,
    required GardenFlowerStage flowerStage,
  }) {
    return '你说了“$phraseTitle”，宝宝表现为“${_labelForReaction(reactionType)}”，花朵停在“${flowerStage.label}”。';
  }

  String _labelForReaction(BabyReactionType reactionType) {
    switch (reactionType) {
      case BabyReactionType.calm:
        return '宝宝放松';
      case BabyReactionType.engaged:
        return '宝宝在看';
      case BabyReactionType.imitated:
        return '宝宝模仿';
      case BabyReactionType.needsBreak:
        return '先休息';
    }
  }
}

class _SpaceProjectionState {
  _SpaceProjectionState({required this.totalActivityCount});

  factory _SpaceProjectionState.fromSeed(SeedSpace space) {
    return _SpaceProjectionState(totalActivityCount: space.activities.length);
  }

  final int totalActivityCount;
  int totalKnownEvents = 0;
  final Set<String> startedActivityIds = <String>{};
  final Set<String> completedActivityIds = <String>{};
  DateTime? lastEventTime;

  void record({
    required String activityId,
    required DateTime eventTime,
    required bool activityCompleted,
  }) {
    totalKnownEvents += 1;
    startedActivityIds.add(activityId);
    if (activityCompleted) {
      completedActivityIds.add(activityId);
    }
    lastEventTime = eventTime;
  }
}

class _ActivityProjectionState {
  _ActivityProjectionState({
    required this.space,
    required this.activity,
    required this.totalPhraseCount,
  });

  factory _ActivityProjectionState.fromSeed({
    required SeedSpace space,
    required SeedActivity activity,
  }) {
    return _ActivityProjectionState(
      space: space,
      activity: activity,
      totalPhraseCount: activity.phrases.length,
    );
  }

  final SeedSpace space;
  final SeedActivity activity;
  final int totalPhraseCount;
  int totalEvents = 0;
  final Set<String> completedPhraseIds = <String>{};
  bool hasImitated = false;
  DateTime? lastEventTime;

  bool get isStarted => totalEvents > 0;

  bool get isCompleted =>
      totalPhraseCount > 0 && completedPhraseIds.length >= totalPhraseCount;

  void record(InteractionEventPayload event) {
    totalEvents += 1;
    completedPhraseIds.add(event.phraseId);
    hasImitated =
        hasImitated || event.reactionType == BabyReactionType.imitated;
    lastEventTime = event.clientTimestamp;
  }
}

class _PhraseReference {
  const _PhraseReference({
    required this.space,
    required this.activity,
    required this.phrase,
  });

  final SeedSpace space;
  final SeedActivity activity;
  final SeedPhrase phrase;
}

class _MilestoneDefinition {
  const _MilestoneDefinition({
    required this.id,
    required this.title,
    required this.body,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final String body;
  final int sortOrder;
}

class _ActivityKey {
  const _ActivityKey(this.spaceId, this.activityId);

  final String spaceId;
  final String activityId;

  @override
  bool operator ==(Object other) {
    return other is _ActivityKey &&
        other.spaceId == spaceId &&
        other.activityId == activityId;
  }

  @override
  int get hashCode => Object.hash(spaceId, activityId);
}

class _PhraseKey {
  const _PhraseKey(this.spaceId, this.activityId, this.phraseId);

  final String spaceId;
  final String activityId;
  final String phraseId;

  @override
  bool operator ==(Object other) {
    return other is _PhraseKey &&
        other.spaceId == spaceId &&
        other.activityId == activityId &&
        other.phraseId == phraseId;
  }

  @override
  int get hashCode => Object.hash(spaceId, activityId, phraseId);
}
