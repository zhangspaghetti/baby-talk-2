import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';

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
    final seedSpacesById = <String, SeedSpace>{
      for (final space in content.spaces) space.id: space,
    };
    final seedActivitiesByKey = <_ActivityKey, SeedActivity>{};

    for (final space in content.spaces) {
      for (final activity in space.activities) {
        final activityKey = _ActivityKey(space.id, activity.id);
        seedActivitiesByKey[activityKey] = activity;
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
    var sawCooperatingReaction = false;
    LatestPracticeImpact? latestImpact;

    // 阈值里程碑追踪（spec §7 累计句数 / 场景覆盖 / 坚持天数）。
    final coveredSpaceIds = <String>{};
    DateTime? streakLastDay;
    var streakRun = 0;
    final generatedSnapshotsByContentId = <String, PracticeActivitySnapshot?>{};

    for (final event in inspection.validEvents) {
      final generatedPreset = event.generatedContentId == null
          ? null
          : await _resolvePresetSnapshot(
              generatedContentId: event.generatedContentId!,
              cache: generatedSnapshotsByContentId,
            );
      final phraseRef = generatedPreset == null
          ? event.generatedContentId == null
                ? phraseRefs[_PhraseKey(
                    event.spaceId,
                    event.activityId,
                    event.phraseId,
                  )]
                : null
          : _toPresetPhraseReference(
              event: event,
              snapshot: generatedPreset,
              space: seedSpacesById[event.spaceId],
              activity:
                  seedActivitiesByKey[_ActivityKey(
                    event.spaceId,
                    event.activityId,
                  )],
            );
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
      final hadCooperatingReaction = sawCooperatingReaction;

      if (generatedPreset == null) {
        activityState.record(event);
      } else {
        activityState.recordGeneratedPreset(event);
      }
      spaceState.record(
        activityId: event.activityId,
        eventTime: event.clientTimestamp,
        activityCompleted: activityState.isCompleted,
      );
      knownEvents += 1;
      sawCooperatingReaction =
          sawCooperatingReaction ||
          event.reactionType == BabyReactionType.cooperating;

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
      if (!hadCooperatingReaction &&
          event.reactionType == BabyReactionType.cooperating) {
        milestoneTimes['first_cooperating'] = event.clientTimestamp;
      }
      if (!wasCompleted && activityState.isCompleted) {
        milestoneTimes['activity_${event.activityId}_completed'] =
            event.clientTimestamp;
      }

      // 累计句数里程碑：10 / 25 / 50 / 100。
      for (final threshold in _cumulativeThresholds) {
        if (knownEvents == threshold) {
          milestoneTimes['cumulative_$threshold'] = event.clientTimestamp;
        }
      }

      // 场景覆盖里程碑：3 / 5 个场景。
      final spaceNewlyCovered = coveredSpaceIds.add(event.spaceId);
      if (spaceNewlyCovered) {
        for (final threshold in _coverageThresholds) {
          if (coveredSpaceIds.length == threshold) {
            milestoneTimes['coverage_$threshold'] = event.clientTimestamp;
          }
        }
      }

      // 坚持天数里程碑：7 / 14 / 30 天连续练习。
      final local = event.clientTimestamp.toLocal();
      final eventDay = DateTime(local.year, local.month, local.day);
      if (streakLastDay == null) {
        streakRun = 1;
      } else {
        final dayGap = eventDay.difference(streakLastDay).inDays;
        if (dayGap == 1) {
          streakRun += 1;
        } else if (dayGap > 1) {
          streakRun = 1;
        }
      }
      streakLastDay = eventDay;
      for (final threshold in _streakThresholds) {
        if (streakRun == threshold &&
            !milestoneTimes.containsKey('streak_$threshold')) {
          milestoneTimes['streak_$threshold'] = event.clientTimestamp;
        }
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

    final generatedProjection = await _buildGeneratedProjection(
      inspection.validEvents,
    );
    final totalKnownEvents = knownEvents + generatedProjection.knownEvents;
    final remainingUnknownContentEvents =
        skippedUnknownContentEvents - generatedProjection.knownEvents;
    final totalSkippedUnknownContentEvents = remainingUnknownContentEvents < 0
        ? 0
        : remainingUnknownContentEvents;

    final milestones = _buildMilestones(
      content: content,
      milestoneTimes: milestoneTimes,
      knownEvents: knownEvents,
      coveredSpaceCount: coveredSpaceIds.length,
      currentStreakDays: streakRun,
    );

    final combinedDiaryEntries =
        <GrowthDiaryEntry>[...diaryEntries, ...generatedProjection.diaryEntries]
          ..sort((left, right) {
            final byTime = right.occurredAt.compareTo(left.occurredAt);
            if (byTime != 0) {
              return byTime;
            }
            return left.entryId.compareTo(right.entryId);
          });

    return GardenGrowthSnapshot(
      installationId: inspection.installationId,
      spaces: List.unmodifiable(<GardenPatchSnapshot>[
        ...spaces,
        ...generatedProjection.spaces,
      ]),
      diaryEntries: List.unmodifiable(combinedDiaryEntries),
      milestones: List.unmodifiable(milestones),
      latestImpact: _latestImpact(
        seedImpact: latestImpact,
        generatedImpact: generatedProjection.latestImpact,
      ),
      totalStoredEvents: inspection.storedEventCount,
      validEvents: inspection.validEventCount,
      knownEvents: totalKnownEvents,
      skippedMalformedEvents: inspection.skippedEventCount,
      skippedUnknownContentEvents: totalSkippedUnknownContentEvents,
      currentStreakDays: streakRun,
      lastIssueMessage: inspection.lastIssue?.message,
      projectionWarning: _buildProjectionWarning(
        skippedMalformedEvents: inspection.skippedEventCount,
        skippedUnknownContentEvents: totalSkippedUnknownContentEvents,
      ),
    );
  }

  Future<_GeneratedGardenProjection> _buildGeneratedProjection(
    List<InteractionEventPayload> events,
  ) async {
    final snapshots = await _practiceRepository.getGeneratedActivitySnapshots();

    final spaces = <GardenPatchSnapshot>[];
    final diaryEntries = <GrowthDiaryEntry>[];
    var knownEvents = 0;
    LatestPracticeImpact? latestImpact;

    for (final snapshot in snapshots) {
      if (snapshot.inputSource == SceneGenerationSourceType.preset) {
        continue;
      }
      final generatedContentId = snapshot.generatedContentId;
      if (generatedContentId == null) {
        continue;
      }
      final phraseById = <String, String>{
        for (final phrase in snapshot.phrases) phrase.phraseId: phrase.english,
      };
      final utteranceByPhraseId = <String, String>{
        for (final phrase in snapshot.phrases)
          phrase.phraseId: snapshot.utteranceIdForPhrase(phrase.phraseId)!,
      };
      final matchingEvents =
          events
              .where(
                (event) =>
                    event.generatedContentId == generatedContentId &&
                    event.spaceId == snapshot.spaceId &&
                    event.activityId == snapshot.activityId &&
                    event.utteranceId == utteranceByPhraseId[event.phraseId],
              )
              .toList(growable: false)
            ..sort(
              (left, right) =>
                  left.clientTimestamp.compareTo(right.clientTimestamp),
            );
      if (matchingEvents.isEmpty) {
        continue;
      }

      var totalEvents = 0;
      DateTime? lastEventTime;
      for (final event in matchingEvents) {
        totalEvents += 1;
        lastEventTime = event.clientTimestamp;
        knownEvents += 1;
        final phraseTitle = phraseById[event.phraseId]!;
        final impact = LatestPracticeImpact(
          eventKey: event.eventKey,
          occurredAt: event.clientTimestamp,
          spaceId: snapshot.spaceId,
          spaceTitle: '此刻照护',
          activityId: snapshot.activityId,
          activityTitle: snapshot.title,
          phraseId: event.phraseId,
          phraseTitle: phraseTitle,
          reactionType: event.reactionType,
          previousPatchStage: GardenPatchStage.tended,
          currentPatchStage: GardenPatchStage.tended,
          previousFlowerStage: GardenFlowerStage.sprout,
          currentFlowerStage: GardenFlowerStage.sprout,
          headline: '已记下这次照护回应。',
          detail: '这条照护记录会保留在当前时刻，稍后可从同一内容继续。',
        );
        latestImpact = _latestImpact(
          seedImpact: latestImpact,
          generatedImpact: impact,
        );
        diaryEntries.add(
          GrowthDiaryEntry(
            entryId: event.eventKey,
            kind: GrowthDiaryEntryKind.practice,
            occurredAt: event.clientTimestamp,
            title: snapshot.title,
            body: _buildGeneratedTraceBody(event.reactionType),
            spaceId: snapshot.spaceId,
            activityId: snapshot.activityId,
          ),
        );
      }

      spaces.add(
        GardenPatchSnapshot(
          spaceId: 'generated_${snapshot.generatedContentId}',
          title: '此刻照护',
          description: '仅当前账号可见的照护时刻。',
          stage: GardenPatchStage.tended,
          totalKnownEvents: totalEvents,
          startedActivityCount: 1,
          completedActivityCount: 0,
          totalActivityCount: 1,
          activities: <GardenFlowerSnapshot>[
            GardenFlowerSnapshot(
              spaceId: snapshot.spaceId,
              activityId: snapshot.activityId,
              title: snapshot.title,
              sceneTag: snapshot.sceneTag,
              summary: snapshot.summary,
              stage: GardenFlowerStage.sprout,
              totalEvents: totalEvents,
              completedPhraseCount: 0,
              totalPhraseCount: snapshot.phrases.length,
              completedPhraseIds: const <String>[],
              careNote: '已保留这次照护记录。',
              lastPracticedAt: lastEventTime,
            ),
          ],
          careNote: '已保留这次照护记录。',
          lastPracticedAt: lastEventTime,
        ),
      );
    }

    return _GeneratedGardenProjection(
      spaces: List.unmodifiable(spaces),
      diaryEntries: List.unmodifiable(diaryEntries),
      knownEvents: knownEvents,
      latestImpact: latestImpact,
    );
  }

  Future<PracticeActivitySnapshot?> _resolvePresetSnapshot({
    required String generatedContentId,
    required Map<String, PracticeActivitySnapshot?> cache,
  }) async {
    if (cache.containsKey(generatedContentId)) {
      return cache[generatedContentId];
    }
    try {
      final snapshot = await _practiceRepository.getGeneratedActivitySnapshot(
        generatedContentId: generatedContentId,
      );
      final preset = snapshot.inputSource == SceneGenerationSourceType.preset
          ? snapshot
          : null;
      cache[generatedContentId] = preset;
      return preset;
    } on Object {
      cache[generatedContentId] = null;
      return null;
    }
  }

  _PhraseReference? _toPresetPhraseReference({
    required InteractionEventPayload event,
    required PracticeActivitySnapshot snapshot,
    required SeedSpace? space,
    required SeedActivity? activity,
  }) {
    if (space == null ||
        activity == null ||
        snapshot.generatedContentId != event.generatedContentId ||
        snapshot.spaceId != event.spaceId ||
        snapshot.activityId != event.activityId) {
      return null;
    }
    final expectedUtteranceId = snapshot.utteranceIdForPhrase(event.phraseId);
    if (expectedUtteranceId == null ||
        event.utteranceId != expectedUtteranceId) {
      return null;
    }
    PracticePhrase? generatedPhrase;
    for (final phrase in snapshot.phrases) {
      if (phrase.phraseId == event.phraseId) {
        generatedPhrase = phrase;
        break;
      }
    }
    if (generatedPhrase == null) {
      return null;
    }
    return _PhraseReference(
      space: space,
      activity: activity,
      phrase: SeedPhrase(
        id: generatedPhrase.phraseId,
        step: generatedPhrase.step,
        english: generatedPhrase.english,
        chinese: generatedPhrase.chinese,
        pronunciation: generatedPhrase.pronunciation,
        difficulty: generatedPhrase.difficulty,
        audioAsset: '',
      ),
    );
  }

  LatestPracticeImpact? _latestImpact({
    required LatestPracticeImpact? seedImpact,
    required LatestPracticeImpact? generatedImpact,
  }) {
    if (seedImpact == null) {
      return generatedImpact;
    }
    if (generatedImpact == null) {
      return seedImpact;
    }
    final byTime = generatedImpact.occurredAt.compareTo(seedImpact.occurredAt);
    if (byTime > 0 ||
        (byTime == 0 &&
            generatedImpact.eventKey.compareTo(seedImpact.eventKey) > 0)) {
      return generatedImpact;
    }
    return seedImpact;
  }

  List<GrowthMilestoneSnapshot> _buildMilestones({
    required SeedContentBundle content,
    required Map<String, DateTime> milestoneTimes,
    required int knownEvents,
    required int coveredSpaceCount,
    required int currentStreakDays,
  }) {
    final definitions = <_MilestoneDefinition>[
      const _MilestoneDefinition(
        id: 'first_opening',
        title: '第一句已经说出口',
        body: '从这一句开始，花园会记住每一次温柔的练习。',
        sortOrder: 0,
      ),
      const _MilestoneDefinition(
        id: 'first_cooperating',
        title: '宝宝开始回应你的声音',
        body: '一旦出现配合反应，成长页会把它记成一次暖暖的回声。',
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

    // 累计句数里程碑。
    for (final threshold in _cumulativeThresholds) {
      expanded.add(
        _MilestoneDefinition(
          id: 'cumulative_$threshold',
          title: '累计 $threshold 句',
          body: '已经把 $threshold 句英语带进真实的日常照护。',
          sortOrder: sortOrder++,
          threshold: threshold,
          currentValue: knownEvents,
          unit: '句',
        ),
      );
    }
    // 场景覆盖里程碑。
    for (final threshold in _coverageThresholds) {
      expanded.add(
        _MilestoneDefinition(
          id: 'coverage_$threshold',
          title: '覆盖 $threshold 个场景',
          body: '在 $threshold 个不同场景里都自然开过口。',
          sortOrder: sortOrder++,
          threshold: threshold,
          currentValue: coveredSpaceCount,
          unit: '个场景',
        ),
      );
    }
    // 坚持天数里程碑。
    for (final threshold in _streakThresholds) {
      expanded.add(
        _MilestoneDefinition(
          id: 'streak_$threshold',
          title: '坚持 $threshold 天',
          body: '连续 $threshold 天都没有断过这份温柔的练习。',
          sortOrder: sortOrder++,
          threshold: threshold,
          currentValue: currentStreakDays,
          unit: '天',
        ),
      );
    }

    return expanded
        .map(
          (definition) => GrowthMilestoneSnapshot(
            id: definition.id,
            title: definition.title,
            body: definition.body,
            sortOrder: definition.sortOrder,
            achievedAt: milestoneTimes[definition.id],
            remainingHint: _remainingHint(definition, milestoneTimes),
          ),
        )
        .toList(growable: false);
  }

  /// 为未完成的阈值里程碑生成温和的“还差 N 单位”提示（spec §7）。
  String? _remainingHint(
    _MilestoneDefinition definition,
    Map<String, DateTime> milestoneTimes,
  ) {
    final threshold = definition.threshold;
    final unit = definition.unit;
    if (threshold == null || unit == null) {
      return null;
    }
    if (milestoneTimes.containsKey(definition.id)) {
      return null;
    }
    final remaining = threshold - definition.currentValue;
    if (remaining <= 0) {
      return null;
    }
    return '还差$remaining$unit';
  }

  GardenFlowerStage _deriveFlowerStage(_ActivityProjectionState state) {
    if (state.totalEvents == 0) {
      return GardenFlowerStage.seed;
    }
    if (state.isCompleted) {
      if (state.hasCooperatingReaction ||
          state.totalEvents > state.totalPhraseCount) {
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

  String _buildGeneratedTraceBody(BabyReactionType reactionType) {
    return '已记录本次照护回应：${_labelForReaction(reactionType)}。';
  }

  String _labelForReaction(BabyReactionType reactionType) {
    switch (reactionType) {
      case BabyReactionType.cooperating:
        return '配合';
      case BabyReactionType.hesitant:
        return '犹豫';
      case BabyReactionType.resisting:
        return '不想';
      case BabyReactionType.noResponse:
        return '没反应';
      case BabyReactionType.other:
        return '其他';
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
  bool hasCooperatingReaction = false;
  DateTime? lastEventTime;

  bool get isStarted => totalEvents > 0;

  bool get isCompleted =>
      totalPhraseCount > 0 && completedPhraseIds.length >= totalPhraseCount;

  void record(InteractionEventPayload event) {
    totalEvents += 1;
    completedPhraseIds.add(event.phraseId);
    hasCooperatingReaction =
        hasCooperatingReaction ||
        event.reactionType == BabyReactionType.cooperating;
    lastEventTime = event.clientTimestamp;
  }

  void recordGeneratedPreset(InteractionEventPayload event) {
    totalEvents += 1;
    hasCooperatingReaction =
        hasCooperatingReaction ||
        event.reactionType == BabyReactionType.cooperating;
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

class _GeneratedGardenProjection {
  const _GeneratedGardenProjection({
    required this.spaces,
    required this.diaryEntries,
    required this.knownEvents,
    required this.latestImpact,
  });

  final List<GardenPatchSnapshot> spaces;
  final List<GrowthDiaryEntry> diaryEntries;
  final int knownEvents;
  final LatestPracticeImpact? latestImpact;
}

const List<int> _cumulativeThresholds = <int>[10, 25, 50, 100];
const List<int> _coverageThresholds = <int>[3, 5];
const List<int> _streakThresholds = <int>[7, 14, 30];

class _MilestoneDefinition {
  const _MilestoneDefinition({
    required this.id,
    required this.title,
    required this.body,
    required this.sortOrder,
    this.threshold,
    this.currentValue = 0,
    this.unit,
  });

  final String id;
  final String title;
  final String body;
  final int sortOrder;
  final int? threshold;
  final int currentValue;
  final String? unit;
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
