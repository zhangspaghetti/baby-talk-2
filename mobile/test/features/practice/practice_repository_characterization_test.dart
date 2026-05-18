import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

import 'practice_repository_characterization_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ensurePracticeRepositoryHarnessIsarInitialized);

  group('PracticeRepository characterization harness', () {
    late PracticeRepositoryCharacterizationHarness harness;

    setUp(() async {
      harness = await PracticeRepositoryCharacterizationHarness.create();
    });

    tearDown(() async {
      await harness.dispose();
    });

    test(
      'captures append-only facts, upload payload, sync metadata, restore, catalog, and continuity',
      () async {
        final firstEvent = await harness.recordBathTimeReaction(
          localEventId: 'evt_harness_warm_water',
          phraseId: 'bath_time_warm_water',
          reactionType: BabyReactionType.engaged,
          clientTimestamp: DateTime.utc(2026, 4, 10, 9),
        );
        final secondEvent = await harness.recordBathTimeReaction(
          localEventId: 'evt_harness_splash',
          phraseId: 'bath_time_splash_splash',
          reactionType: BabyReactionType.imitated,
          clientTimestamp: DateTime.utc(2026, 4, 10, 9, 1),
        );

        final pendingSnapshot = await harness.captureBathTimeState();

        expect(pendingSnapshot, _pendingPracticeSnapshot());

        await harness.repository.markEventsSynced(
          [firstEvent.eventKey],
          phase: 'batch_ack_applied',
          syncedAt: DateTime.utc(2026, 4, 10, 9, 2),
        );
        await harness.repository.markEventsFailed(
          [secondEvent.eventKey],
          phase: 'batch_upload_failed',
          errorMessage: 'server 500 while syncing',
          failedAt: DateTime.utc(2026, 4, 10, 9, 3),
        );

        final syncedSnapshot = await harness.captureBathTimeState();

        expect(syncedSnapshot['historyFacts'], pendingSnapshot['historyFacts']);
        expect(syncedSnapshot, _syncedPracticeSnapshot());
      },
    );
  });
}

Map<String, Object?> _pendingPracticeSnapshot() {
  return {
    'historyFacts': _expectedFactMaps(),
    'historySyncMetadata': const [
      {
        'syncState': 'pending',
        'lastSyncPhase': null,
        'lastSyncError': null,
        'lastSyncAt': null,
      },
      {
        'syncState': 'pending',
        'lastSyncPhase': null,
        'lastSyncError': null,
        'lastSyncAt': null,
      },
    ],
    'pendingUploads': _expectedUploadMaps(),
    'restore': _expectedRestoreMap(),
    'catalog': _expectedCatalogMap(),
    'continuity': _expectedContinuityMap(),
    'syncSummary': const {
      'pendingCount': 2,
      'syncedCount': 0,
      'failedCount': 0,
      'lastPendingAt': '2026-04-10T09:01:00.000Z',
      'lastSyncedAt': null,
      'lastFailedAt': null,
      'lastSyncPhase': null,
      'lastSyncError': null,
      'lastSyncAt': null,
    },
  };
}

Map<String, Object?> _syncedPracticeSnapshot() {
  return {
    'historyFacts': _expectedFactMaps(),
    'historySyncMetadata': const [
      {
        'syncState': 'synced',
        'lastSyncPhase': 'batch_ack_applied',
        'lastSyncError': null,
        'lastSyncAt': '2026-04-10T09:02:00.000Z',
      },
      {
        'syncState': 'failed',
        'lastSyncPhase': 'batch_upload_failed',
        'lastSyncError': 'server 500 while syncing',
        'lastSyncAt': '2026-04-10T09:03:00.000Z',
      },
    ],
    'pendingUploads': const <Map<String, Object?>>[],
    'restore': _expectedRestoreMap(),
    'catalog': _expectedCatalogMap(),
    'continuity': _expectedContinuityMap(),
    'syncSummary': const {
      'pendingCount': 0,
      'syncedCount': 1,
      'failedCount': 1,
      'lastPendingAt': null,
      'lastSyncedAt': '2026-04-10T09:02:00.000Z',
      'lastFailedAt': '2026-04-10T09:03:00.000Z',
      'lastSyncPhase': 'batch_upload_failed',
      'lastSyncError': 'server 500 while syncing',
      'lastSyncAt': '2026-04-10T09:03:00.000Z',
    },
  };
}

List<Map<String, Object?>> _expectedFactMaps() {
  return const [
    {
      'eventKey': 'install_practice_characterize:evt_harness_warm_water',
      'localEventId': 'evt_harness_warm_water',
      'installationId': 'install_practice_characterize',
      'spaceId': 'daily_care',
      'activityId': 'bath_time',
      'phraseId': 'bath_time_warm_water',
      'reactionType': 'engaged',
      'clientTimestamp': '2026-04-10T09:00:00.000Z',
    },
    {
      'eventKey': 'install_practice_characterize:evt_harness_splash',
      'localEventId': 'evt_harness_splash',
      'installationId': 'install_practice_characterize',
      'spaceId': 'daily_care',
      'activityId': 'bath_time',
      'phraseId': 'bath_time_splash_splash',
      'reactionType': 'imitated',
      'clientTimestamp': '2026-04-10T09:01:00.000Z',
    },
  ];
}

List<Map<String, Object?>> _expectedUploadMaps() {
  return const [
    {
      'eventKey': 'install_practice_characterize:evt_harness_warm_water',
      'localEventId': 'evt_harness_warm_water',
      'installationId': 'install_practice_characterize',
      'spaceId': 'daily_care',
      'activityId': 'bath_time',
      'phraseId': 'bath_time_warm_water',
      'reactionType': 'engaged',
      'clientTimestamp': '2026-04-10T09:00:00.000Z',
    },
    {
      'eventKey': 'install_practice_characterize:evt_harness_splash',
      'localEventId': 'evt_harness_splash',
      'installationId': 'install_practice_characterize',
      'spaceId': 'daily_care',
      'activityId': 'bath_time',
      'phraseId': 'bath_time_splash_splash',
      'reactionType': 'imitated',
      'clientTimestamp': '2026-04-10T09:01:00.000Z',
    },
  ];
}

Map<String, Object?> _expectedRestoreMap() {
  return const {
    'installationId': 'install_practice_characterize',
    'totalEvents': 2,
    'lastEventTime': '2026-04-10T09:01:00.000Z',
    'recentResult': {
      'activityId': 'bath_time',
      'phraseId': 'bath_time_splash_splash',
      'phraseEnglish': 'Splash, splash!',
      'reactionType': 'imitated',
      'eventTime': '2026-04-10T09:01:00.000Z',
      'totalEvents': 2,
    },
    'completedPhraseIds': ['bath_time_warm_water', 'bath_time_splash_splash'],
    'nextPhraseId': 'bath_time_all_clean',
    'restoreMessage': '已从本地恢复最近一次练习结果，共 2 条记录。',
    'hasRecoverableIssue': false,
  };
}

Map<String, Object?> _expectedCatalogMap() {
  return const {
    'installationId': 'install_practice_characterize',
    'totalStoredEvents': 2,
    'validEvents': 2,
    'knownEvents': 2,
    'skippedMalformedEvents': 0,
    'skippedUnknownContentEvents': 0,
    'catalogWarning': null,
    'activity': {
      'spaceId': 'daily_care',
      'activityId': 'bath_time',
      'title': '洗澡时间',
      'totalPhraseCount': 3,
      'completedPhraseCount': 2,
      'completedPhraseIds': ['bath_time_warm_water', 'bath_time_splash_splash'],
      'nextPhraseId': 'bath_time_all_clean',
      'nextPhraseEnglish': 'All clean.',
      'totalEvents': 2,
      'lastEventTime': '2026-04-10T09:01:00.000Z',
      'recentResult': {
        'phraseId': 'bath_time_splash_splash',
        'phraseEnglish': 'Splash, splash!',
        'reactionType': 'imitated',
        'eventTime': '2026-04-10T09:01:00.000Z',
        'totalEvents': 2,
      },
      'skippedUnknownPhraseCount': 0,
      'skippedMalformedEventCount': 0,
      'warningMessage': null,
    },
  };
}

Map<String, Object?> _expectedContinuityMap() {
  return const {
    'recommendedSpaceId': 'daily_care',
    'recommendedActivityId': 'bath_time',
    'reason': 'recent_activity',
    'fallbackReason': null,
    'cadenceTotalKnownEvents': 2,
    'cadenceStartedActivityCount': 1,
    'cadenceLastEventTime': '2026-04-10T09:01:00.000Z',
    'cadenceHeadline': '正在围绕单一 activity 形成节奏',
    'warningMessage': null,
  };
}
