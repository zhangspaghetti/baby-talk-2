import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/practice/data/generated/generated_practice_content_registry.dart';
import 'package:mobile/features/practice/data/local/interaction_event_entity.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/preset_scene_catalog_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/data/services/dynamic_practice_api_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_content_source.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/domain/models/preset_scene_definition.dart';
import 'package:mobile/features/practice/domain/generated_care_turn_resume.dart';

class PracticeActivitySnapshot {
  const PracticeActivitySnapshot({
    required this.spaceId,
    required this.activityId,
    required this.title,
    required this.summary,
    required this.sceneTag,
    required this.coachTip,
    required this.phrases,
    this.contentSource = PracticeContentSource.seed,
    this.generatedContentId,
    this.utteranceIdsByPhraseId = const <String, String>{},
    this.reactionSupportPhraseIds = const <BabyReactionType, String>{},
  });

  final String spaceId;
  final String activityId;
  final String title;
  final String summary;
  final String sceneTag;
  final String coachTip;
  final List<PracticePhrase> phrases;
  final PracticeContentSource contentSource;
  final String? generatedContentId;
  final Map<String, String> utteranceIdsByPhraseId;
  final Map<BabyReactionType, String> reactionSupportPhraseIds;

  String? utteranceIdForPhrase(String phraseId) {
    return utteranceIdsByPhraseId[phraseId];
  }

  String? reactionSupportPhraseId(BabyReactionType reactionType) {
    return reactionSupportPhraseIds[reactionType];
  }
}

/// Resolves durable non-seed content before the seed bundle is consulted.
/// A missing generated record deliberately falls through to no result, never
/// to an unrelated seed activity.
abstract interface class PracticeContentResolver {
  Future<PracticeActivitySnapshot?> resolveActivity({
    required String spaceId,
    required String activityId,
  });

  Future<PracticeActivitySnapshot?> resolveGeneratedContent({
    required String generatedContentId,
  });

  Future<List<PracticeActivitySnapshot>> listGeneratedActivities();

  Future<GeneratedCareTurnResumeMarker?> loadGeneratedCareTurnResumeMarker();

  Future<void> completeGeneratedCareTurnResume({
    required String generatedContentId,
  });

  Future<void> clearForLifecycle();
}

class PracticeRecentResultSummary {
  const PracticeRecentResultSummary({
    required this.activityId,
    required this.activityTitle,
    required this.phraseId,
    required this.phraseEnglish,
    required this.reactionType,
    required this.eventTime,
    required this.totalEvents,
  });

  final String activityId;
  final String activityTitle;
  final String phraseId;
  final String phraseEnglish;
  final BabyReactionType reactionType;
  final DateTime eventTime;
  final int totalEvents;
}

class PracticeHomeSummary {
  const PracticeHomeSummary({
    required this.spaceId,
    required this.activityId,
    required this.activityTitle,
    required this.totalEvents,
    required this.lastEventTime,
    required this.recentResult,
  });

  final String spaceId;
  final String activityId;
  final String activityTitle;
  final int totalEvents;
  final DateTime? lastEventTime;
  final PracticeRecentResultSummary? recentResult;

  bool get isEmpty => totalEvents == 0;
}

class PracticeSyncSummary {
  const PracticeSyncSummary({
    this.pendingCount = 0,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.lastPendingAt,
    this.lastSyncedAt,
    this.lastFailedAt,
    this.lastSyncPhase,
    this.lastSyncError,
    this.lastSyncAt,
  });

  final int pendingCount;
  final int syncedCount;
  final int failedCount;
  final DateTime? lastPendingAt;
  final DateTime? lastSyncedAt;
  final DateTime? lastFailedAt;
  final String? lastSyncPhase;
  final String? lastSyncError;
  final DateTime? lastSyncAt;

  DateTime? get lastEventAt {
    if (lastSyncAt != null) {
      return lastSyncAt;
    }
    final candidates = [
      lastPendingAt,
      lastSyncedAt,
      lastFailedAt,
    ].whereType<DateTime>().toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort();
    return candidates.last;
  }
}

PracticeSyncSummary summarizePracticeSyncEvents(
  List<InteractionEventPayload> events,
) {
  DateTime? lastPendingAt;
  DateTime? lastSyncedAt;
  DateTime? lastFailedAt;
  var pendingCount = 0;
  var syncedCount = 0;
  var failedCount = 0;
  InteractionEventPayload? lastSyncedMetadataSource;

  for (final event in events) {
    switch (event.syncState) {
      case InteractionSyncState.pending:
        pendingCount += 1;
        lastPendingAt = event.clientTimestamp;
        break;
      case InteractionSyncState.synced:
        syncedCount += 1;
        lastSyncedAt = event.lastSyncAt ?? event.clientTimestamp;
        break;
      case InteractionSyncState.failed:
        failedCount += 1;
        lastFailedAt = event.lastSyncAt ?? event.clientTimestamp;
        break;
    }

    final syncTimestamp = event.lastSyncAt;
    if (syncTimestamp == null) {
      continue;
    }
    final currentLastTimestamp = lastSyncedMetadataSource?.lastSyncAt;
    if (currentLastTimestamp == null ||
        syncTimestamp.isAfter(currentLastTimestamp)) {
      lastSyncedMetadataSource = event;
    }
  }

  return PracticeSyncSummary(
    pendingCount: pendingCount,
    syncedCount: syncedCount,
    failedCount: failedCount,
    lastPendingAt: lastPendingAt,
    lastSyncedAt: lastSyncedAt,
    lastFailedAt: lastFailedAt,
    lastSyncPhase: lastSyncedMetadataSource?.lastSyncPhase,
    lastSyncError: lastSyncedMetadataSource?.lastSyncError,
    lastSyncAt: lastSyncedMetadataSource?.lastSyncAt,
  );
}

class PracticeResumeInfo {
  const PracticeResumeInfo({
    required this.activityId,
    required this.totalPhrases,
    required this.completedPhraseIds,
    required this.nextPhraseId,
    required this.lastEventTime,
  });

  final String activityId;
  final int totalPhrases;
  final List<String> completedPhraseIds;
  final String? nextPhraseId;
  final DateTime? lastEventTime;

  int get completedCount => completedPhraseIds.length;
  bool get isEmpty => completedPhraseIds.isEmpty;
  bool get isComplete => completedCount >= totalPhrases && totalPhrases > 0;
}

class PracticeEventInspectionIssue {
  const PracticeEventInspectionIssue({
    required this.message,
    this.localEventId,
    this.clientTimestamp,
  });

  final String message;
  final String? localEventId;
  final DateTime? clientTimestamp;
}

class PracticeEventInspection {
  const PracticeEventInspection({
    required this.installationId,
    required this.storedEventCount,
    required this.validEvents,
    required this.skippedEventCount,
    this.lastIssue,
    this.scanErrorMessage,
  });

  final String? installationId;
  final int storedEventCount;
  final List<InteractionEventPayload> validEvents;
  final int skippedEventCount;
  final PracticeEventInspectionIssue? lastIssue;
  final String? scanErrorMessage;

  int get validEventCount => validEvents.length;
  bool get hasRecoverableIssue =>
      skippedEventCount > 0 || scanErrorMessage != null;
}

class PracticeRestoreSnapshot {
  const PracticeRestoreSnapshot({
    required this.installationId,
    required this.activitySnapshot,
    required this.homeSummary,
    required this.resumeInfo,
    required this.inspection,
    required this.restoreMessage,
    required this.hasRecoverableIssue,
  });

  final String? installationId;
  final PracticeActivitySnapshot activitySnapshot;
  final PracticeHomeSummary homeSummary;
  final PracticeResumeInfo resumeInfo;
  final PracticeEventInspection inspection;
  final String restoreMessage;
  final bool hasRecoverableIssue;
}

class PracticeRepository {
  PracticeRepository({
    required AssetPhraseService assetPhraseService,
    required PracticeLocalDataSource localDataSource,
    required InstallationIdService installationIdService,
    DynamicPracticeApiService? dynamicPracticeApiService,
    PracticeContentResolver? contentResolver,
    PresetSceneCatalogRepository? presetSceneCatalogRepository,
    Random? random,
  }) : _assetPhraseService = assetPhraseService,
       _localDataSource = localDataSource,
       _installationIdService = installationIdService,
       _dynamicPracticeApiService = dynamicPracticeApiService,
       _contentResolver = contentResolver,
       _presetSceneCatalogRepository = presetSceneCatalogRepository,
       _random = random ?? Random();

  final AssetPhraseService _assetPhraseService;
  final PracticeLocalDataSource _localDataSource;
  final InstallationIdService _installationIdService;
  final DynamicPracticeApiService? _dynamicPracticeApiService;
  final PracticeContentResolver? _contentResolver;
  final PresetSceneCatalogRepository? _presetSceneCatalogRepository;
  final Random _random;
  bool _isClosed = false;

  Future<PracticeActivityCatalog> getActivityCatalog() async {
    final presetCatalog = await _loadPresetSceneCatalog();
    final content = await _assetPhraseService.loadSeedContent();
    final installationId = await _safeEnsureInstallationId();
    late final List<PracticeActivitySnapshot> generatedActivities;
    try {
      generatedActivities = await getGeneratedActivitySnapshots();
    } on GeneratedPracticeProjectionUnavailableException catch (error) {
      if (error.reason !=
          GeneratedPracticeProjectionUnavailableReason.accountUnavailable) {
        rethrow;
      }
      generatedActivities = const <PracticeActivitySnapshot>[];
    }
    final generatedByContentId = <String, PracticeActivitySnapshot>{
      for (final activity in generatedActivities)
        if (activity.generatedContentId != null)
          activity.generatedContentId!: activity,
    };

    List<InteractionEventEntity> rawEntities;
    String? scanErrorMessage;
    try {
      rawEntities = await _localDataSource.listRawEntities();
    } catch (error) {
      rawEntities = const <InteractionEventEntity>[];
      scanErrorMessage = '本地事件读取失败：$error';
    }

    final seedSpacesById = <String, SeedSpace>{
      for (final space in content.spaces) space.id: space,
    };
    final seedActivitiesByRoute = <_CatalogActivityKey, SeedActivity>{
      for (final space in content.spaces)
        for (final activity in space.activities)
          _CatalogActivityKey(space.id, activity.id): activity,
    };
    final activityStates = <_CatalogActivityKey, _CatalogActivityState>{};
    final orderedSpaceIds = <String>[];
    for (final definition in presetCatalog.scenes) {
      final seedActivity =
          seedActivitiesByRoute[_CatalogActivityKey(
            definition.spaceId,
            definition.presetSceneId,
          )];
      final state = _CatalogActivityState.fromPublished(
        definition: definition,
        seedSpace: seedSpacesById[definition.spaceId],
        seedActivity: seedActivity,
      );
      final key = _CatalogActivityKey(
        definition.spaceId,
        definition.presetSceneId,
      );
      activityStates[key] = state;
      if (!orderedSpaceIds.contains(definition.spaceId)) {
        orderedSpaceIds.add(definition.spaceId);
      }
    }

    var validEvents = 0;
    var knownGeneratedEvents = 0;
    var skippedMalformedEvents = 0;
    var skippedUnknownContentEvents = 0;
    String? lastIssueMessage = scanErrorMessage;

    for (final entity in rawEntities) {
      try {
        final event = PracticeLocalDataSource.payloadFromEntity(entity);
        validEvents += 1;

        final generated = event.generatedContentId == null
            ? null
            : generatedByContentId[event.generatedContentId];
        if (generated != null && _matchesGeneratedEvent(event, generated)) {
          knownGeneratedEvents += 1;
          continue;
        }

        final activityState =
            activityStates[_CatalogActivityKey(
              event.spaceId,
              event.activityId,
            )];
        if (activityState == null) {
          skippedUnknownContentEvents += 1;
          lastIssueMessage =
              '跳过未知 activity 事件：${event.spaceId}/${event.activityId}/${event.phraseId}';
          continue;
        }
        if (event.generatedContentId != null || event.utteranceId != null) {
          skippedUnknownContentEvents += 1;
          lastIssueMessage = 'seed activity 事件包含 generated identity。';
          continue;
        }
        if (!activityState.containsPhrase(event.phraseId)) {
          activityState.recordUnknownPhrase(event);
          skippedUnknownContentEvents += 1;
          lastIssueMessage =
              '跳过未知短语事件：${event.spaceId}/${event.activityId}/${event.phraseId}';
          continue;
        }

        activityState.record(event);
      } catch (error) {
        skippedMalformedEvents += 1;
        lastIssueMessage = '$error';
        activityStates[_CatalogActivityKey(entity.spaceId, entity.activityId)]
            ?.recordMalformed(
              localEventId: entity.localEventId,
              clientTimestamp: entity.clientTimestamp,
              message: '$error',
            );
      }
    }

    final activities = <PracticeCatalogActivitySummary>[];
    final summariesBySpace = <String, List<PracticeCatalogActivitySummary>>{};
    for (final definition in presetCatalog.scenes) {
      final state =
          activityStates[_CatalogActivityKey(
            definition.spaceId,
            definition.presetSceneId,
          )]!;
      final summary = state.toSummary();
      activities.add(summary);
      (summariesBySpace[definition.spaceId] ??=
              <PracticeCatalogActivitySummary>[])
          .add(summary);
    }

    final spaces = <PracticeCatalogSpaceSummary>[];
    for (final spaceId in orderedSpaceIds) {
      final space = seedSpacesById[spaceId];
      final spaceActivities = summariesBySpace[spaceId]!;
      DateTime? lastEventTime;
      var totalEvents = 0;
      var startedActivityCount = 0;
      var completedActivityCount = 0;

      for (final summary in spaceActivities) {
        totalEvents += summary.totalEvents;
        if (!summary.isEmpty) {
          startedActivityCount += 1;
        }
        if (summary.isComplete) {
          completedActivityCount += 1;
        }
        final summaryLastEventTime = summary.lastEventTime;
        if (summaryLastEventTime != null &&
            (lastEventTime == null ||
                summaryLastEventTime.isAfter(lastEventTime))) {
          lastEventTime = summaryLastEventTime;
        }
      }

      spaces.add(
        PracticeCatalogSpaceSummary(
          spaceId: spaceId,
          title: space?.title ?? spaceId,
          description: space?.description ?? '',
          activities: List.unmodifiable(spaceActivities),
          totalEvents: totalEvents,
          startedActivityCount: startedActivityCount,
          completedActivityCount: completedActivityCount,
          lastEventTime: lastEventTime,
        ),
      );
    }

    final knownEvents =
        activities.fold<int>(0, (sum, activity) => sum + activity.totalEvents) +
        knownGeneratedEvents;

    return PracticeActivityCatalog(
      installationId: installationId,
      spaces: List.unmodifiable(spaces),
      activities: List.unmodifiable(activities),
      totalStoredEvents: rawEntities.length,
      validEvents: validEvents,
      knownEvents: knownEvents,
      skippedMalformedEvents: skippedMalformedEvents,
      skippedUnknownContentEvents: skippedUnknownContentEvents,
      lastIssueMessage: lastIssueMessage,
      catalogWarning: _buildCatalogWarning(
        scanErrorMessage: scanErrorMessage,
        skippedMalformedEvents: skippedMalformedEvents,
        skippedUnknownContentEvents: skippedUnknownContentEvents,
      ),
    );
  }

  Future<PracticeContinuitySnapshot> getContinuitySnapshot({
    String? starterSpaceId,
    String? starterActivityId,
  }) async {
    final catalog = await getActivityCatalog();
    if (catalog.activities.isEmpty) {
      throw const FormatException('活动目录为空，无法生成 continuity snapshot。');
    }

    final normalizedStarterSpaceId = (starterSpaceId ?? '').trim();
    final normalizedStarterActivityId = (starterActivityId ?? '').trim();
    final hasStarterContext =
        normalizedStarterSpaceId.isNotEmpty ||
        normalizedStarterActivityId.isNotEmpty;

    PracticeCatalogActivitySummary? starterActivity;
    String? starterWarning;
    if (normalizedStarterSpaceId.isNotEmpty &&
        normalizedStarterActivityId.isNotEmpty) {
      starterActivity = catalog.findActivity(
        spaceId: normalizedStarterSpaceId,
        activityId: normalizedStarterActivityId,
      );
      if (starterActivity == null) {
        starterWarning =
            'starter activity 不存在：$normalizedStarterSpaceId/$normalizedStarterActivityId；已忽略原始入口。';
      }
    } else if (hasStarterContext) {
      starterWarning = 'starter activity 参数不完整；已忽略原始入口。';
    }

    final generatedResumeMarker = await _contentResolver
        ?.loadGeneratedCareTurnResumeMarker();
    final generatedRecentActivities = await _loadGeneratedContinuityActivities(
      resumableGeneratedContentId: generatedResumeMarker?.generatedContentId,
    );
    final recentCandidates =
        <PracticeCatalogActivitySummary>[
          ...catalog.activities,
          ...generatedRecentActivities,
        ]..sort((left, right) {
          final leftTime = left.lastEventTime;
          final rightTime = right.lastEventTime;
          if (leftTime == null && rightTime == null) {
            return left.activityId.compareTo(right.activityId);
          }
          if (leftTime == null) {
            return 1;
          }
          if (rightTime == null) {
            return -1;
          }
          return rightTime.compareTo(leftTime);
        });
    final recentActivity = recentCandidates.firstWhere(
      (activity) => activity.lastEventTime != null,
      orElse: () => catalog.mostRecentActivity ?? catalog.activities.first,
    );
    final hasRecentActivity = recentActivity.lastEventTime != null;
    PracticeCatalogActivitySummary? resumableGeneratedActivity;
    if (generatedResumeMarker != null) {
      for (final activity in generatedRecentActivities) {
        if (activity.generatedContentId ==
            generatedResumeMarker.generatedContentId) {
          resumableGeneratedActivity = activity;
          break;
        }
      }
    }
    final resumeMarkerIsNewer =
        resumableGeneratedActivity != null &&
        (recentActivity.lastEventTime == null ||
            generatedResumeMarker!.confirmedAt.isAfter(
              recentActivity.lastEventTime!,
            ));
    if (generatedResumeMarker != null &&
        resumableGeneratedActivity != null &&
        !resumeMarkerIsNewer) {
      try {
        await _contentResolver?.completeGeneratedCareTurnResume(
          generatedContentId: generatedResumeMarker.generatedContentId,
        );
      } on Object {
        // Event continuity already owns recovery. Marker cleanup is retried by
        // the next reaction or continuity read.
      }
    }
    final nextIncompleteActivity = catalog.firstIncompleteActivity;

    late final PracticeCatalogActivitySummary recommendedActivity;
    late final PracticeContinuityReason recommendationReason;
    late final String? fallbackReason;

    if (resumeMarkerIsNewer) {
      recommendedActivity = resumableGeneratedActivity;
      recommendationReason = PracticeContinuityReason.recentActivity;
      fallbackReason = null;
    } else if (hasRecentActivity) {
      recommendedActivity = recentActivity;
      recommendationReason = PracticeContinuityReason.recentActivity;
      fallbackReason = null;
    } else if (starterActivity != null) {
      recommendedActivity = starterActivity;
      recommendationReason = PracticeContinuityReason.starterFallback;
      fallbackReason = '暂无最近 activity，先从 starter activity 继续。';
    } else if (nextIncompleteActivity != null) {
      recommendedActivity = nextIncompleteActivity;
      recommendationReason = PracticeContinuityReason.nextIncomplete;
      fallbackReason = starterWarning == null
          ? '暂无最近 activity，先接上尚未完成的 activity。'
          : 'starter activity 不可用，已退回尚未完成的 activity。';
    } else {
      recommendedActivity = catalog.activities.first;
      recommendationReason = PracticeContinuityReason.safeCatalogFallback;
      fallbackReason = '未找到可继续的未完成 activity，已回退到目录中的首个 activity。';
    }

    final warningParts = <String>[
      if (starterWarning != null && starterWarning.trim().isNotEmpty)
        starterWarning,
      if (catalog.catalogWarning != null &&
          catalog.catalogWarning!.trim().isNotEmpty)
        catalog.catalogWarning!,
    ];

    return PracticeContinuitySnapshot(
      catalog: catalog,
      recommendedActivity: recommendedActivity,
      recentActivity: hasRecentActivity ? recentActivity : null,
      nextIncompleteActivity: nextIncompleteActivity,
      starterActivity: starterActivity,
      recommendation: PracticeContinuityRecommendation(
        spaceId: recommendedActivity.spaceId,
        activityId: recommendedActivity.activityId,
        activityTitle: recommendedActivity.title,
        reason: recommendationReason,
        reasonLabel: recommendationReason.label,
        generatedContentId: recommendedActivity.generatedContentId,
        fallbackReason: fallbackReason,
      ),
      cadence: _buildContinuityCadenceSummary(
        catalog: catalog,
        recommendedActivity: recommendedActivity,
      ),
      warningMessage: warningParts.isEmpty ? null : warningParts.join('；'),
    );
  }

  Future<List<PracticeCatalogActivitySummary>>
  _loadGeneratedContinuityActivities({
    String? resumableGeneratedContentId,
  }) async {
    final snapshots = await getGeneratedActivitySnapshots();
    if (snapshots.isEmpty) {
      return const <PracticeCatalogActivitySummary>[];
    }
    final inspection = await inspectEventLog();
    final summaries = <PracticeCatalogActivitySummary>[];
    for (final snapshot in snapshots) {
      if (snapshot.generatedContentId == null) {
        continue;
      }
      final events =
          inspection.validEvents
              .where((event) => _matchesGeneratedEvent(event, snapshot))
              .toList(growable: false)
            ..sort(
              (left, right) =>
                  left.clientTimestamp.compareTo(right.clientTimestamp),
            );
      if (events.isEmpty &&
          snapshot.generatedContentId != resumableGeneratedContentId) {
        continue;
      }
      final resume = _buildResumeInfo(snapshot: snapshot, events: events);
      final home = _buildHomeSummary(snapshot: snapshot, events: events);
      final nextPhraseId = resume.nextPhraseId;
      PracticePhrase? nextPhrase;
      if (nextPhraseId != null) {
        for (final phrase in snapshot.phrases) {
          if (phrase.phraseId == nextPhraseId) {
            nextPhrase = phrase;
            break;
          }
        }
      }
      summaries.add(
        PracticeCatalogActivitySummary(
          spaceId: snapshot.spaceId,
          spaceTitle: '此刻照护',
          activityId: snapshot.activityId,
          generatedContentId: snapshot.generatedContentId,
          title: snapshot.title,
          summary: snapshot.summary,
          sceneTag: snapshot.sceneTag,
          coachTip: snapshot.coachTip,
          totalPhraseCount: snapshot.phrases.length,
          completedPhraseCount: resume.completedCount,
          completedPhraseIds: resume.completedPhraseIds,
          nextPhraseId: nextPhraseId,
          nextPhraseEnglish: nextPhrase?.english,
          totalEvents: home.totalEvents,
          skippedUnknownPhraseCount: 0,
          skippedMalformedEventCount: 0,
          lastEventTime: home.lastEventTime,
          recentResult: home.recentResult == null
              ? null
              : PracticeCatalogRecentResultSummary(
                  phraseId: home.recentResult!.phraseId,
                  phraseEnglish: home.recentResult!.phraseEnglish,
                  reactionType: home.recentResult!.reactionType,
                  eventTime: home.recentResult!.eventTime,
                  totalEvents: home.recentResult!.totalEvents,
                ),
        ),
      );
    }
    return List<PracticeCatalogActivitySummary>.unmodifiable(summaries);
  }

  Future<PracticeActivitySnapshot> getActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async {
    final generated = await _contentResolver?.resolveActivity(
      spaceId: spaceId,
      activityId: activityId,
    );
    if (generated != null) {
      return generated;
    }
    if (_presetSceneCatalogRepository != null) {
      final presetCatalog = await _loadPresetSceneCatalog();
      PresetSceneDefinition? definition;
      for (final candidate in presetCatalog.scenes) {
        if (candidate.spaceId == spaceId &&
            candidate.presetSceneId == activityId) {
          definition = candidate;
          break;
        }
      }
      if (definition == null) {
        throw FormatException('未知 preset scene: $spaceId/$activityId');
      }
      final content = await _assetPhraseService.loadSeedContent();
      SeedActivity? seedActivity;
      for (final space in content.spaces) {
        if (space.id != definition.spaceId) {
          continue;
        }
        for (final activity in space.activities) {
          if (activity.id == definition.presetSceneId) {
            seedActivity = activity;
            break;
          }
        }
        break;
      }
      final phrases = seedActivity == null
          ? const <PracticePhrase>[]
          : await _assetPhraseService.loadPracticePhrases(
              spaceId: definition.spaceId,
              activityId: definition.presetSceneId,
            );
      return PracticeActivitySnapshot(
        spaceId: definition.spaceId,
        activityId: definition.presetSceneId,
        title: definition.title,
        summary: definition.summary,
        sceneTag: definition.sceneTag,
        coachTip: definition.coachTip,
        phrases: phrases,
      );
    }
    final activity = await _assetPhraseService.loadActivity(
      spaceId: spaceId,
      activityId: activityId,
    );
    final phrases = await _assetPhraseService.loadPracticePhrases(
      spaceId: spaceId,
      activityId: activityId,
    );
    return PracticeActivitySnapshot(
      spaceId: spaceId,
      activityId: activityId,
      title: activity.title,
      summary: activity.summary,
      sceneTag: activity.sceneTag,
      coachTip: activity.coachTip,
      phrases: phrases,
    );
  }

  /// Loads only shipped seed content for static onboarding/registration
  /// previews. This seam intentionally never consults published remote/cache
  /// catalog state.
  Future<PracticeActivitySnapshot> getBundledActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async {
    final activity = await _assetPhraseService.loadActivity(
      spaceId: spaceId,
      activityId: activityId,
    );
    final phrases = await _assetPhraseService.loadPracticePhrases(
      spaceId: spaceId,
      activityId: activityId,
    );
    return PracticeActivitySnapshot(
      spaceId: spaceId,
      activityId: activityId,
      title: activity.title,
      summary: activity.summary,
      sceneTag: activity.sceneTag,
      coachTip: activity.coachTip,
      phrases: phrases,
    );
  }

  Future<PresetSceneCatalogSnapshot> _loadPresetSceneCatalog() async {
    final repository = _presetSceneCatalogRepository;
    if (repository != null) {
      return repository.loadCatalog();
    }
    final bundledScenes = await _assetPhraseService.loadBundledPresetScenes();
    return PresetSceneCatalogSnapshot(
      source: PresetSceneCatalogSource.bundled,
      scenes: bundledScenes,
    );
  }

  Future<PracticeActivitySnapshot> getGeneratedActivitySnapshot({
    required String generatedContentId,
  }) async {
    final normalized = generatedContentId.trim();
    if (normalized.isEmpty) {
      throw const FormatException('generatedContentId 不能为空。');
    }
    final snapshot = await _contentResolver?.resolveGeneratedContent(
      generatedContentId: normalized,
    );
    if (snapshot == null ||
        snapshot.contentSource != PracticeContentSource.generated) {
      throw FormatException('未知 generatedContentId: $normalized');
    }
    return snapshot;
  }

  /// Current-account generated content for private projections such as Today
  /// and Garden. It is deliberately not added to the preset activity catalog.
  Future<List<PracticeActivitySnapshot>> getGeneratedActivitySnapshots() async {
    final snapshots =
        await _contentResolver?.listGeneratedActivities() ??
        const <PracticeActivitySnapshot>[];
    return List<PracticeActivitySnapshot>.unmodifiable(
      snapshots.where(
        (snapshot) =>
            snapshot.contentSource == PracticeContentSource.generated &&
            snapshot.generatedContentId != null,
      ),
    );
  }

  /// Legacy non-formal preview path for the old dynamic-practice surface.
  ///
  /// It deliberately uses ephemeral IDs and its caller never records reaction
  /// events. M2 Custom Scene must instead resolve a registered approved bundle
  /// through [getGeneratedActivitySnapshot] and [PracticeContentResolver].
  ///
  /// 从后端 API 动态生成练习内容，失败时 fallback 到首个 seed_content.json activity。
  ///
  /// [babyAgeMonths] 宝宝月龄
  /// [sceneTag] 可选场景标签
  /// [fallbackSpaceId] fallback 时使用的 spaceId
  /// [fallbackActivityId] fallback 时使用的 activityId
  Future<PracticeActivitySnapshot> getActivitySnapshotDynamic({
    required int babyAgeMonths,
    String? sceneTag,
    String? fallbackSpaceId,
    String? fallbackActivityId,
    String? accessToken,
  }) async {
    final apiService = _dynamicPracticeApiService;
    if (apiService != null) {
      try {
        final installationId = await _safeEnsureInstallationId() ?? '';
        final response = await apiService.generatePractice(
          installationId: installationId,
          babyAgeMonths: babyAgeMonths,
          sceneTag: sceneTag,
          accessToken: accessToken,
        );
        if (response.activities.isNotEmpty) {
          final activity = response.activities.first;
          final phrases = <PracticePhrase>[];
          for (var i = 0; i < activity.phrases.length; i++) {
            final dp = activity.phrases[i];
            phrases.add(
              PracticePhrase(
                spaceId: 'dynamic',
                activityId: 'dynamic_${DateTime.now().millisecondsSinceEpoch}',
                phraseId: 'dyn_${i}_${DateTime.now().microsecondsSinceEpoch}',
                step: i + 1,
                english: dp.english,
                chinese: dp.chinese,
                pronunciation: dp.pronunciation,
                difficulty: dp.difficulty,
                audioAsset: '', // 空字符串标记为 TTS 模式
              ),
            );
          }
          debugPrint(
            '[PracticeRepository] dynamic generate OK: '
            '${activity.title}, ${phrases.length} phrases',
          );
          return PracticeActivitySnapshot(
            spaceId: 'dynamic',
            activityId: 'dynamic',
            title: activity.title,
            summary: activity.summary,
            sceneTag: activity.sceneTag,
            coachTip: activity.coachTip,
            phrases: List.unmodifiable(phrases),
          );
        }
      } catch (error) {
        debugPrint(
          '[PracticeRepository] dynamic generate failed, '
          'falling back to seed: $error',
        );
      }
    }

    // fallback: 使用 seed_content.json 首个 activity
    final content = await _assetPhraseService.loadSeedContent();
    final firstSpace = content.spaces.isNotEmpty ? content.spaces.first : null;
    final firstActivity = firstSpace != null && firstSpace.activities.isNotEmpty
        ? firstSpace.activities.first
        : null;

    final spaceId = fallbackSpaceId ?? firstSpace?.id ?? 'default';
    final activityId = fallbackActivityId ?? firstActivity?.id ?? 'default';

    return getActivitySnapshot(spaceId: spaceId, activityId: activityId);
  }

  Future<String> ensureInstallationId() {
    return _installationIdService.getOrCreate();
  }

  Future<String?> readExistingInstallationId() {
    return _installationIdService.readExisting();
  }

  Future<InteractionEventPayload?> findEventByLocalEventId(
    String localEventId,
  ) {
    return _localDataSource.getInteractionEventByLocalEventId(localEventId);
  }

  Future<InteractionEventPayload> recordReaction({
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
    String? generatedContentId,
    String? utteranceId,
    DateTime? clientTimestamp,
    String? localEventId,
  }) async {
    final normalizedGeneratedContentId = _trimToNull(generatedContentId);
    final normalizedUtteranceId = _trimToNull(utteranceId);
    if ((normalizedGeneratedContentId == null) !=
        (normalizedUtteranceId == null)) {
      throw const FormatException('generatedContentId 与 utteranceId 必须同时存在。');
    }
    final snapshot = normalizedGeneratedContentId == null
        ? await getActivitySnapshot(spaceId: spaceId, activityId: activityId)
        : await getGeneratedActivitySnapshot(
            generatedContentId: normalizedGeneratedContentId,
          );
    if (snapshot.spaceId != spaceId || snapshot.activityId != activityId) {
      throw const FormatException('generated content 与 practice scope 不匹配。');
    }
    final phraseExists = snapshot.phrases.any(
      (phrase) => phrase.phraseId == phraseId,
    );
    if (!phraseExists) {
      throw FormatException('未知 phraseId: $spaceId/$activityId/$phraseId');
    }
    final expectedGeneratedContentId = snapshot.generatedContentId;
    final expectedUtteranceId = snapshot.utteranceIdForPhrase(phraseId);
    if (expectedGeneratedContentId == null) {
      if (normalizedGeneratedContentId != null) {
        throw const FormatException(
          'seed practice event 不接受 generated identity。',
        );
      }
    } else if (normalizedGeneratedContentId != expectedGeneratedContentId ||
        normalizedUtteranceId != expectedUtteranceId) {
      throw const FormatException('generated interaction identity 不匹配。');
    }

    final normalizedLocalEventId = localEventId?.trim();
    final isGeneratedReaction = normalizedGeneratedContentId != null;
    final resolvedLocalEventId = isGeneratedReaction
        ? _generatedReactionLocalEventId(
            generatedContentId: normalizedGeneratedContentId,
            utteranceId: normalizedUtteranceId!,
            reactionType: reactionType,
          )
        : normalizedLocalEventId == null || normalizedLocalEventId.isEmpty
        ? _generateLocalEventId()
        : normalizedLocalEventId;
    final payload = InteractionEventPayload(
      localEventId: resolvedLocalEventId,
      installationId: await _installationIdService.getOrCreate(),
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp: clientTimestamp ?? DateTime.now().toUtc(),
      generatedContentId: normalizedGeneratedContentId,
      utteranceId: normalizedUtteranceId,
    );
    if (isGeneratedReaction ||
        normalizedLocalEventId != null && normalizedLocalEventId.isNotEmpty) {
      final existing = await findEventByLocalEventId(resolvedLocalEventId);
      if (existing != null) {
        return _completeGeneratedResumeAfterEvent(
          _reconcileOrThrow(existing, payload),
        );
      }
    }

    try {
      await _localDataSource.appendInteractionEvent(payload);
      return _completeGeneratedResumeAfterEvent(payload);
    } catch (_) {
      final reconciliationId =
          isGeneratedReaction ||
              normalizedLocalEventId == null ||
              normalizedLocalEventId.isEmpty
          ? resolvedLocalEventId
          : normalizedLocalEventId;
      final existing = await findEventByLocalEventId(reconciliationId);
      if (existing == null) {
        rethrow;
      }
      return _completeGeneratedResumeAfterEvent(
        _reconcileOrThrow(existing, payload),
      );
    }
  }

  Future<InteractionEventPayload> _completeGeneratedResumeAfterEvent(
    InteractionEventPayload event,
  ) async {
    final generatedContentId = event.generatedContentId;
    if (generatedContentId != null) {
      try {
        await _contentResolver?.completeGeneratedCareTurnResume(
          generatedContentId: generatedContentId,
        );
      } on Object {
        // Event is durable and authoritative. Cleanup remains best-effort so a
        // marker I/O failure cannot turn a recorded reaction into a false error.
      }
    }
    return event;
  }

  bool _sameImmutableEventFacts(
    InteractionEventPayload existing,
    InteractionEventPayload requested,
  ) {
    return existing.spaceId == requested.spaceId &&
        existing.activityId == requested.activityId &&
        existing.phraseId == requested.phraseId &&
        existing.reactionType == requested.reactionType &&
        existing.generatedContentId == requested.generatedContentId &&
        existing.utteranceId == requested.utteranceId;
  }

  InteractionEventPayload _reconcileOrThrow(
    InteractionEventPayload existing,
    InteractionEventPayload requested,
  ) {
    if (!_sameImmutableEventFacts(existing, requested)) {
      throw const FormatException('localEventId 已绑定不同事件事实。');
    }
    return existing;
  }

  Future<PracticeRestoreSnapshot> restorePracticeState({
    required String spaceId,
    required String activityId,
  }) async {
    final snapshot = await getActivitySnapshot(
      spaceId: spaceId,
      activityId: activityId,
    );

    final installationId = await _safeEnsureInstallationId();
    final inspection = await _safeInspectEventLog(
      spaceId: spaceId,
      activityId: activityId,
      installationId: installationId,
    );

    final derivableEvents = _filterDerivableEvents(
      snapshot: snapshot,
      events: inspection.validEvents,
    );
    final skippedUnknownPhraseCount =
        inspection.validEventCount - derivableEvents.length;

    final homeSummary = _buildHomeSummary(
      snapshot: snapshot,
      events: derivableEvents,
    );
    final resumeInfo = _buildResumeInfo(
      snapshot: snapshot,
      events: derivableEvents,
    );

    final hasRecoverableIssue =
        inspection.hasRecoverableIssue || skippedUnknownPhraseCount > 0;

    return PracticeRestoreSnapshot(
      installationId: installationId,
      activitySnapshot: snapshot,
      homeSummary: homeSummary,
      resumeInfo: resumeInfo,
      inspection: inspection,
      restoreMessage: _buildRestoreMessage(
        homeSummary: homeSummary,
        inspection: inspection,
        skippedUnknownPhraseCount: skippedUnknownPhraseCount,
      ),
      hasRecoverableIssue: hasRecoverableIssue,
    );
  }

  Future<PracticeHomeSummary> getHomeSummary({
    required String spaceId,
    required String activityId,
  }) async {
    final restored = await restorePracticeState(
      spaceId: spaceId,
      activityId: activityId,
    );
    return restored.homeSummary;
  }

  Future<PracticeResumeInfo> getResumeInfo({
    required String spaceId,
    required String activityId,
  }) async {
    final restored = await restorePracticeState(
      spaceId: spaceId,
      activityId: activityId,
    );
    return restored.resumeInfo;
  }

  Future<PracticeResumeInfo> getGeneratedResumeInfo({
    required String generatedContentId,
  }) async {
    final snapshot = await getGeneratedActivitySnapshot(
      generatedContentId: generatedContentId,
    );
    final inspection = await inspectEventLog(
      spaceId: snapshot.spaceId,
      activityId: snapshot.activityId,
    );
    return _buildResumeInfo(
      snapshot: snapshot,
      events: _filterDerivableEvents(
        snapshot: snapshot,
        events: inspection.validEvents,
      ),
    );
  }

  Future<PracticeEventInspection> inspectEventLog({
    String? spaceId,
    String? activityId,
    String? installationIdOverride,
  }) async {
    final rawEntities = await _localDataSource.listRawEntities(
      spaceId: spaceId,
      activityId: activityId,
    );

    final validEvents = <InteractionEventPayload>[];
    var skippedEventCount = 0;
    PracticeEventInspectionIssue? lastIssue;

    for (final entity in rawEntities) {
      try {
        validEvents.add(PracticeLocalDataSource.payloadFromEntity(entity));
      } catch (error) {
        skippedEventCount += 1;
        lastIssue = PracticeEventInspectionIssue(
          localEventId: entity.localEventId,
          clientTimestamp: entity.clientTimestamp,
          message: '$error',
        );
      }
    }

    return PracticeEventInspection(
      installationId:
          installationIdOverride ?? await _installationIdService.readExisting(),
      storedEventCount: rawEntities.length,
      validEvents: List.unmodifiable(validEvents),
      skippedEventCount: skippedEventCount,
      lastIssue: lastIssue,
    );
  }

  Future<PracticeSyncSummary> getSyncSummary({
    String? spaceId,
    String? activityId,
  }) async {
    final events = await listEventHistory(
      spaceId: spaceId,
      activityId: activityId,
    );
    return summarizePracticeSyncEvents(events);
  }

  Future<List<InteractionEventPayload>> listEventHistory({
    String? spaceId,
    String? activityId,
  }) {
    return _localDataSource.listInteractionEvents(
      spaceId: spaceId,
      activityId: activityId,
    );
  }

  Future<List<InteractionEventPayload>> listPendingEvents({
    String? spaceId,
    String? activityId,
    int? limit,
  }) {
    return _localDataSource.listPendingEvents(
      spaceId: spaceId,
      activityId: activityId,
      limit: limit,
    );
  }

  Future<List<InteractionEventUploadRecord>> listPendingUploadRecords({
    String? spaceId,
    String? activityId,
    int? limit,
  }) async {
    final events = await listPendingEvents(
      spaceId: spaceId,
      activityId: activityId,
      limit: limit,
    );
    return events.map((event) => event.uploadRecord).toList(growable: false);
  }

  Future<void> markEventsSynced(
    Iterable<String> eventKeys, {
    String phase = 'batch_ack_applied',
    DateTime? syncedAt,
  }) {
    return _localDataSource.markEventsSynced(
      eventKeys,
      phase: phase,
      syncedAt: syncedAt,
    );
  }

  Future<void> markEventsFailed(
    Iterable<String> eventKeys, {
    required String phase,
    required String errorMessage,
    DateTime? failedAt,
    bool keepPending = false,
  }) {
    return _localDataSource.markEventsFailed(
      eventKeys,
      phase: phase,
      errorMessage: errorMessage,
      failedAt: failedAt,
      keepPending: keepPending,
    );
  }

  Future<void> importServerEvents(Iterable<InteractionEventPayload> events) {
    return _localDataSource.importServerEvents(events);
  }

  Future<void> close({bool deleteFromDisk = false}) async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    try {
      await _localDataSource.close(deleteFromDisk: deleteFromDisk);
    } finally {
      if (deleteFromDisk) {
        await _contentResolver?.clearForLifecycle();
      }
    }
  }

  Future<void> deleteInstallationIdForLifecycle() {
    return _installationIdService.deleteIfExists();
  }

  Future<String?> _safeEnsureInstallationId() async {
    try {
      return await _installationIdService.getOrCreate();
    } catch (_) {
      return await _installationIdService.readExisting();
    }
  }

  Future<PracticeEventInspection> _safeInspectEventLog({
    required String spaceId,
    required String activityId,
    required String? installationId,
  }) async {
    try {
      return await inspectEventLog(
        spaceId: spaceId,
        activityId: activityId,
        installationIdOverride: installationId,
      );
    } catch (error) {
      return PracticeEventInspection(
        installationId: installationId,
        storedEventCount: 0,
        validEvents: const <InteractionEventPayload>[],
        skippedEventCount: 0,
        scanErrorMessage: '本地事件读取失败：$error',
      );
    }
  }

  List<InteractionEventPayload> _filterDerivableEvents({
    required PracticeActivitySnapshot snapshot,
    required List<InteractionEventPayload> events,
  }) {
    final knownPhraseIds = snapshot.phrases
        .map((phrase) => phrase.phraseId)
        .toSet();
    return events
        .where(
          (event) =>
              knownPhraseIds.contains(event.phraseId) &&
              (snapshot.generatedContentId == null
                  ? event.generatedContentId == null &&
                        event.utteranceId == null
                  : _matchesGeneratedEvent(event, snapshot)),
        )
        .toList(growable: false);
  }

  bool _matchesGeneratedEvent(
    InteractionEventPayload event,
    PracticeActivitySnapshot snapshot,
  ) {
    final generatedContentId = snapshot.generatedContentId;
    if (generatedContentId == null ||
        event.generatedContentId != generatedContentId ||
        event.spaceId != snapshot.spaceId ||
        event.activityId != snapshot.activityId) {
      return false;
    }
    return event.utteranceId == snapshot.utteranceIdForPhrase(event.phraseId);
  }

  PracticeHomeSummary _buildHomeSummary({
    required PracticeActivitySnapshot snapshot,
    required List<InteractionEventPayload> events,
  }) {
    if (events.isEmpty) {
      return PracticeHomeSummary(
        spaceId: snapshot.spaceId,
        activityId: snapshot.activityId,
        activityTitle: snapshot.title,
        totalEvents: 0,
        lastEventTime: null,
        recentResult: null,
      );
    }

    final latest = events.last;
    final phraseById = {
      for (final phrase in snapshot.phrases) phrase.phraseId: phrase,
    };
    final latestPhrase = phraseById[latest.phraseId];
    if (latestPhrase == null) {
      return PracticeHomeSummary(
        spaceId: snapshot.spaceId,
        activityId: snapshot.activityId,
        activityTitle: snapshot.title,
        totalEvents: 0,
        lastEventTime: null,
        recentResult: null,
      );
    }

    return PracticeHomeSummary(
      spaceId: snapshot.spaceId,
      activityId: snapshot.activityId,
      activityTitle: snapshot.title,
      totalEvents: events.length,
      lastEventTime: latest.clientTimestamp,
      recentResult: PracticeRecentResultSummary(
        activityId: snapshot.activityId,
        activityTitle: snapshot.title,
        phraseId: latest.phraseId,
        phraseEnglish: latestPhrase.english,
        reactionType: latest.reactionType,
        eventTime: latest.clientTimestamp,
        totalEvents: events.length,
      ),
    );
  }

  PracticeResumeInfo _buildResumeInfo({
    required PracticeActivitySnapshot snapshot,
    required List<InteractionEventPayload> events,
  }) {
    if (snapshot.generatedContentId != null && events.isNotEmpty) {
      final latest = events.reduce(
        (left, right) =>
            left.clientTimestamp.isAfter(right.clientTimestamp) ? left : right,
      );
      return PracticeResumeInfo(
        activityId: snapshot.activityId,
        totalPhrases: snapshot.phrases.length,
        completedPhraseIds: const <String>[],
        nextPhraseId: snapshot.reactionSupportPhraseId(latest.reactionType),
        lastEventTime: latest.clientTimestamp,
      );
    }
    final completedPhraseIds = <String>[];
    for (final event in events) {
      if (!completedPhraseIds.contains(event.phraseId)) {
        completedPhraseIds.add(event.phraseId);
      }
    }

    String? nextPhraseId;
    if (snapshot.contentSource == PracticeContentSource.generated) {
      final latestReaction = events.isEmpty ? null : events.last.reactionType;
      nextPhraseId = latestReaction == null
          ? (snapshot.phrases.isEmpty ? null : snapshot.phrases.first.phraseId)
          : snapshot.reactionSupportPhraseId(latestReaction);
    } else {
      for (final phrase in snapshot.phrases) {
        if (!completedPhraseIds.contains(phrase.phraseId)) {
          nextPhraseId = phrase.phraseId;
          break;
        }
      }
      nextPhraseId ??= snapshot.phrases.isEmpty
          ? null
          : snapshot.phrases.last.phraseId;
    }

    return PracticeResumeInfo(
      activityId: snapshot.activityId,
      totalPhrases: snapshot.phrases.length,
      completedPhraseIds: List.unmodifiable(completedPhraseIds),
      nextPhraseId: nextPhraseId,
      lastEventTime: events.isEmpty ? null : events.last.clientTimestamp,
    );
  }

  String _buildRestoreMessage({
    required PracticeHomeSummary homeSummary,
    required PracticeEventInspection inspection,
    required int skippedUnknownPhraseCount,
  }) {
    if (inspection.scanErrorMessage != null) {
      return '${inspection.scanErrorMessage}；已退回安全空态，可直接重新开始练习。';
    }

    if (inspection.skippedEventCount > 0) {
      return '恢复时跳过 ${inspection.skippedEventCount} 条暂不可用记录，其余本地结果已保留。';
    }

    if (skippedUnknownPhraseCount > 0) {
      return '恢复时跳过 $skippedUnknownPhraseCount 条未知短语记录；已保留其余本地结果。';
    }

    if (homeSummary.isEmpty) {
      return '未找到本地记录，可以直接开始练习。';
    }

    return '已从本地恢复最近一次练习结果，共 ${homeSummary.totalEvents} 条记录。';
  }

  String? _buildCatalogWarning({
    required String? scanErrorMessage,
    required int skippedMalformedEvents,
    required int skippedUnknownContentEvents,
  }) {
    final parts = <String>[];
    if (scanErrorMessage != null && scanErrorMessage.trim().isNotEmpty) {
      parts.add(scanErrorMessage);
    }
    if (skippedMalformedEvents > 0) {
      parts.add('跳过 $skippedMalformedEvents 条损坏记录');
    }
    if (skippedUnknownContentEvents > 0) {
      parts.add('跳过 $skippedUnknownContentEvents 条未知内容记录');
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join('；');
  }

  PracticeContinuityCadenceSummary _buildContinuityCadenceSummary({
    required PracticeActivityCatalog catalog,
    required PracticeCatalogActivitySummary recommendedActivity,
  }) {
    final latestEventTime = catalog.mostRecentActivity?.lastEventTime;
    final startedActivityCount = catalog.startedActivityCount;

    late final String headline;
    late final String detail;

    if (catalog.knownEvents == 0) {
      headline = '还没形成 cadence';
      detail = '先从 ${recommendedActivity.title} 开始，第一条本地记录会从这里累积。';
    } else if (startedActivityCount <= 1) {
      headline = '正在围绕单一 activity 形成节奏';
      detail = latestEventTime == null
          ? '当前推荐 ${recommendedActivity.title} · 已累计 ${catalog.knownEvents} 条记录。'
          : '最近一次 ${_formatContinuityTime(latestEventTime)} · 当前推荐 ${recommendedActivity.title}。';
    } else {
      headline = '已经带出跨 activity 的节奏';
      detail = latestEventTime == null
          ? '已开始 $startedActivityCount 个 activity · 当前推荐 ${recommendedActivity.title}。'
          : '最近一次 ${_formatContinuityTime(latestEventTime)} · 已开始 $startedActivityCount 个 activity。';
    }

    return PracticeContinuityCadenceSummary(
      totalKnownEvents: catalog.knownEvents,
      startedActivityCount: startedActivityCount,
      lastEventTime: latestEventTime,
      headline: headline,
      detail: detail,
    );
  }

  String _formatContinuityTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  String _generateLocalEventId() {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final entropy = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'evt_${timestamp}_$entropy';
  }

  String _generatedReactionLocalEventId({
    required String generatedContentId,
    required String utteranceId,
    required BabyReactionType reactionType,
  }) {
    final canonicalIdentity = [
      generatedContentId,
      utteranceId,
      reactionType.wireValue,
    ].join('|');
    return 'generated_reaction_${sha256.convert(utf8.encode(canonicalIdentity))}';
  }

  String? _trimToNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class _CatalogActivityState {
  _CatalogActivityState({
    required this.spaceId,
    required this.spaceTitle,
    required this.activityId,
    required this.title,
    required this.summary,
    required this.sceneTag,
    required this.coachTip,
    required List<SeedPhrase> phrases,
  }) : _phrases = List<SeedPhrase>.unmodifiable(phrases),
       _phraseById = {for (final phrase in phrases) phrase.id: phrase};

  factory _CatalogActivityState.fromPublished({
    required PresetSceneDefinition definition,
    required SeedSpace? seedSpace,
    required SeedActivity? seedActivity,
  }) {
    return _CatalogActivityState(
      spaceId: definition.spaceId,
      spaceTitle: seedSpace?.title ?? definition.spaceId,
      activityId: definition.presetSceneId,
      title: definition.title,
      summary: definition.summary,
      sceneTag: definition.sceneTag,
      coachTip: definition.coachTip,
      phrases: seedActivity?.phrases ?? const <SeedPhrase>[],
    );
  }

  final String spaceId;
  final String spaceTitle;
  final String activityId;
  final String title;
  final String summary;
  final String sceneTag;
  final String coachTip;
  final List<SeedPhrase> _phrases;
  final Map<String, SeedPhrase> _phraseById;
  final Set<String> _completedPhraseIds = <String>{};
  int totalEvents = 0;
  int skippedUnknownPhraseCount = 0;
  int skippedMalformedEventCount = 0;
  InteractionEventPayload? latestKnownEvent;
  String? latestWarningMessage;

  bool containsPhrase(String phraseId) => _phraseById.containsKey(phraseId);

  void record(InteractionEventPayload event) {
    totalEvents += 1;
    _completedPhraseIds.add(event.phraseId);
    latestKnownEvent = event;
  }

  void recordUnknownPhrase(InteractionEventPayload event) {
    skippedUnknownPhraseCount += 1;
    latestWarningMessage = '跳过未知短语记录：${event.activityId}/${event.phraseId}';
  }

  void recordMalformed({
    required String? localEventId,
    required DateTime? clientTimestamp,
    required String message,
  }) {
    skippedMalformedEventCount += 1;
    final detail = [
      if (localEventId != null && localEventId.trim().isNotEmpty)
        'localEventId=$localEventId',
      if (clientTimestamp != null) clientTimestamp.toIso8601String(),
      message,
    ].join(' @ ');
    latestWarningMessage = '跳过损坏记录：$detail';
  }

  PracticeCatalogActivitySummary toSummary() {
    final completedPhraseIds = _phrases
        .where((phrase) => _completedPhraseIds.contains(phrase.id))
        .map((phrase) => phrase.id)
        .toList(growable: false);

    SeedPhrase? nextPhrase;
    for (final phrase in _phrases) {
      if (!_completedPhraseIds.contains(phrase.id)) {
        nextPhrase = phrase;
        break;
      }
    }
    nextPhrase ??= _phrases.isEmpty ? null : _phrases.last;

    final latestPhrase = latestKnownEvent == null
        ? null
        : _phraseById[latestKnownEvent!.phraseId];

    return PracticeCatalogActivitySummary(
      spaceId: spaceId,
      spaceTitle: spaceTitle,
      activityId: activityId,
      title: title,
      summary: summary,
      sceneTag: sceneTag,
      coachTip: coachTip,
      totalPhraseCount: _phrases.length,
      completedPhraseCount: completedPhraseIds.length,
      completedPhraseIds: List.unmodifiable(completedPhraseIds),
      nextPhraseId: nextPhrase?.id,
      nextPhraseEnglish: nextPhrase?.english,
      totalEvents: totalEvents,
      skippedUnknownPhraseCount: skippedUnknownPhraseCount,
      skippedMalformedEventCount: skippedMalformedEventCount,
      lastEventTime: latestKnownEvent?.clientTimestamp,
      recentResult: latestKnownEvent == null || latestPhrase == null
          ? null
          : PracticeCatalogRecentResultSummary(
              phraseId: latestKnownEvent!.phraseId,
              phraseEnglish: latestPhrase.english,
              reactionType: latestKnownEvent!.reactionType,
              eventTime: latestKnownEvent!.clientTimestamp,
              totalEvents: totalEvents,
            ),
      warningMessage: _buildWarningMessage(),
    );
  }

  String? _buildWarningMessage() {
    final parts = <String>[];
    if (skippedMalformedEventCount > 0) {
      parts.add('跳过 $skippedMalformedEventCount 条损坏记录');
    }
    if (skippedUnknownPhraseCount > 0) {
      parts.add('跳过 $skippedUnknownPhraseCount 条未知短语记录');
    }
    if (latestWarningMessage != null &&
        latestWarningMessage!.trim().isNotEmpty) {
      parts.add(latestWarningMessage!);
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join('；');
  }
}

class _CatalogActivityKey {
  const _CatalogActivityKey(this.spaceId, this.activityId);

  final String spaceId;
  final String activityId;

  @override
  bool operator ==(Object other) {
    return other is _CatalogActivityKey &&
        other.spaceId == spaceId &&
        other.activityId == activityId;
  }

  @override
  int get hashCode => Object.hash(spaceId, activityId);
}
