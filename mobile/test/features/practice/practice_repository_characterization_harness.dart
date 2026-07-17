import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import '../../support/isar_test_library.dart';

const practiceCharacterizationInstallationId = 'install_practice_characterize';

var _practiceHarnessIsarInitialized = false;

Future<void> ensurePracticeRepositoryHarnessIsarInitialized() async {
  if (_practiceHarnessIsarInitialized) {
    return;
  }
  await Isar.initializeIsarCore(
    libraries: {Abi.current(): resolveBundledIsarLibraryPath()},
  );
  _practiceHarnessIsarInitialized = true;
}

class PracticeRepositoryCharacterizationHarness {
  PracticeRepositoryCharacterizationHarness({
    required this.tempDir,
    required this.localDataSource,
    required this.repository,
    this.installationId = practiceCharacterizationInstallationId,
  });

  final Directory tempDir;
  final PracticeLocalDataSource localDataSource;
  final PracticeRepository repository;
  final String installationId;

  static Future<PracticeRepositoryCharacterizationHarness> create({
    String installationId = practiceCharacterizationInstallationId,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'practice_repository_characterization_',
    );
    final localDataSource = await PracticeLocalDataSource.open(
      directory: tempDir.path,
      name: 'practice_${DateTime.now().microsecondsSinceEpoch}',
    );
    final repository = PracticeRepository(
      assetPhraseService: AssetPhraseService(bundle: rootBundle),
      localDataSource: localDataSource,
      installationIdService: InstallationIdService(
        directoryResolver: () async => tempDir,
        idGenerator: () => installationId,
      ),
    );
    return PracticeRepositoryCharacterizationHarness(
      tempDir: tempDir,
      localDataSource: localDataSource,
      repository: repository,
      installationId: installationId,
    );
  }

  Future<void> dispose() async {
    await repository.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }

  Future<InteractionEventPayload> recordBathTimeReaction({
    required String localEventId,
    required String phraseId,
    required BabyReactionType reactionType,
    required DateTime clientTimestamp,
  }) {
    return repository.recordReaction(
      spaceId: 'daily_care',
      activityId: 'bath_time',
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp: clientTimestamp,
      localEventId: localEventId,
    );
  }

  Future<Map<String, Object?>> captureBathTimeState() async {
    final history = await repository.listEventHistory(activityId: 'bath_time');
    final pendingUploads = await repository.listPendingUploadRecords(
      activityId: 'bath_time',
    );
    final restore = await repository.restorePracticeState(
      spaceId: 'daily_care',
      activityId: 'bath_time',
    );
    final catalog = await repository.getActivityCatalog();
    final catalogActivity = catalog.findActivity(
      spaceId: 'daily_care',
      activityId: 'bath_time',
    );
    final continuity = await repository.getContinuitySnapshot(
      starterSpaceId: 'daily_care',
      starterActivityId: 'bath_time',
    );
    final syncSummary = await repository.getSyncSummary(
      activityId: 'bath_time',
    );

    return {
      'historyFacts': history
          .map((event) => event.toFactMap())
          .toList(growable: false),
      'historySyncMetadata': history
          .map((event) => event.toSyncMetadataMap())
          .toList(growable: false),
      'pendingUploads': pendingUploads
          .map((record) => record.toJsonMap())
          .toList(growable: false),
      'restore': {
        'installationId': restore.installationId,
        'totalEvents': restore.homeSummary.totalEvents,
        'lastEventTime': restore.homeSummary.lastEventTime?.toIso8601String(),
        'recentResult': _practiceRecentResultMap(
          restore.homeSummary.recentResult,
        ),
        'completedPhraseIds': restore.resumeInfo.completedPhraseIds,
        'nextPhraseId': restore.resumeInfo.nextPhraseId,
        'restoreMessage': restore.restoreMessage,
        'hasRecoverableIssue': restore.hasRecoverableIssue,
      },
      'catalog': {
        'installationId': catalog.installationId,
        'totalStoredEvents': catalog.totalStoredEvents,
        'validEvents': catalog.validEvents,
        'knownEvents': catalog.knownEvents,
        'skippedMalformedEvents': catalog.skippedMalformedEvents,
        'skippedUnknownContentEvents': catalog.skippedUnknownContentEvents,
        'catalogWarning': catalog.catalogWarning,
        'activity': _catalogActivityMap(catalogActivity),
      },
      'continuity': {
        'recommendedSpaceId': continuity.recommendation.spaceId,
        'recommendedActivityId': continuity.recommendation.activityId,
        'reason': continuity.recommendation.reason.wireValue,
        'fallbackReason': continuity.fallbackReason,
        'cadenceTotalKnownEvents': continuity.cadence.totalKnownEvents,
        'cadenceStartedActivityCount': continuity.cadence.startedActivityCount,
        'cadenceLastEventTime': continuity.cadence.lastEventTime
            ?.toIso8601String(),
        'cadenceHeadline': continuity.cadence.headline,
        'warningMessage': continuity.warningMessage,
      },
      'syncSummary': {
        'pendingCount': syncSummary.pendingCount,
        'syncedCount': syncSummary.syncedCount,
        'failedCount': syncSummary.failedCount,
        'lastPendingAt': syncSummary.lastPendingAt?.toIso8601String(),
        'lastSyncedAt': syncSummary.lastSyncedAt?.toIso8601String(),
        'lastFailedAt': syncSummary.lastFailedAt?.toIso8601String(),
        'lastSyncPhase': syncSummary.lastSyncPhase,
        'lastSyncError': syncSummary.lastSyncError,
        'lastSyncAt': syncSummary.lastSyncAt?.toIso8601String(),
      },
    };
  }
}

Map<String, Object?>? _practiceRecentResultMap(
  PracticeRecentResultSummary? recentResult,
) {
  if (recentResult == null) {
    return null;
  }
  return {
    'activityId': recentResult.activityId,
    'phraseId': recentResult.phraseId,
    'phraseEnglish': recentResult.phraseEnglish,
    'reactionType': recentResult.reactionType.wireValue,
    'eventTime': recentResult.eventTime.toIso8601String(),
    'totalEvents': recentResult.totalEvents,
  };
}

Map<String, Object?>? _catalogActivityMap(
  PracticeCatalogActivitySummary? activity,
) {
  if (activity == null) {
    return null;
  }
  return {
    'spaceId': activity.spaceId,
    'activityId': activity.activityId,
    'title': activity.title,
    'totalPhraseCount': activity.totalPhraseCount,
    'completedPhraseCount': activity.completedPhraseCount,
    'completedPhraseIds': activity.completedPhraseIds,
    'nextPhraseId': activity.nextPhraseId,
    'nextPhraseEnglish': activity.nextPhraseEnglish,
    'totalEvents': activity.totalEvents,
    'lastEventTime': activity.lastEventTime?.toIso8601String(),
    'recentResult': _catalogRecentResultMap(activity.recentResult),
    'skippedUnknownPhraseCount': activity.skippedUnknownPhraseCount,
    'skippedMalformedEventCount': activity.skippedMalformedEventCount,
    'warningMessage': activity.warningMessage,
  };
}

Map<String, Object?>? _catalogRecentResultMap(
  PracticeCatalogRecentResultSummary? recentResult,
) {
  if (recentResult == null) {
    return null;
  }
  return {
    'phraseId': recentResult.phraseId,
    'phraseEnglish': recentResult.phraseEnglish,
    'reactionType': recentResult.reactionType.wireValue,
    'eventTime': recentResult.eventTime.toIso8601String(),
    'totalEvents': recentResult.totalEvents,
  };
}
