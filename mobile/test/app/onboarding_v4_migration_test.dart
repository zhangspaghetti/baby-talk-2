import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app_reentry_orchestrator.dart';
import 'package:mobile/app/onboarding_v4_migration.dart';
import 'package:mobile/features/care_entry/data/file_onboarding_conversation_repository.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';

void main() {
  test('completed M1 snapshot becomes a minimal completed v2 marker', () async {
    final directory = await Directory.systemTemp.createTemp(
      'onboarding_v4_completed_migration_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = FileOnboardingConversationRepository(
      directoryResolver: () async => directory,
    );
    final completedAt = DateTime.utc(2026, 8, 1, 8);
    final migration = OnboardingV4Migration(
      directoryResolver: () async => directory,
      conversationRepository: repository,
      clock: () => DateTime.utc(2026, 8, 14, 12),
    );

    final migrated = await migration.run(
      legacySnapshot: OnboardingSnapshot(
        schemaVersion: 1,
        childDisplayName: '宝宝',
        ageBucket: OnboardingAgeBucket.oneToTwo,
        approxMonths: 15,
        currentStage: 'stage_13_18m',
        starterSpaceId: 'daily_care',
        starterActivityId: 'bedtime',
        starterPhraseId: 'phrase-1',
        consentState: OnboardingConsentState.localOnly,
        completedAt: completedAt,
      ),
    );

    expect(migrated?.schemaVersion, 2);
    expect(migrated?.status, OnboardingConversationStatus.completed);
    expect(migrated?.selectedEntryId, isNull);
    expect(migrated?.completedAt, completedAt);
    expect(
      resolveOnboardingLaunchDestination(
        completedSnapshot: null,
        conversationSnapshot: migrated,
      ),
      AppLaunchDestination.shell,
    );
  });

  test('in-progress M1 metadata is quarantined and V4 starts fresh', () async {
    final directory = await Directory.systemTemp.createTemp(
      'onboarding_v4_in_progress_migration_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final legacy = File(
      '${directory.path}${Platform.pathSeparator}onboarding_flow_snapshot.json',
    );
    await legacy.writeAsString(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'step': 'care_turn',
        'starterPhraseId': 'private-legacy-phrase',
        'updatedAt': '2026-08-01T08:00:00.000Z',
      }),
    );
    final repository = FileOnboardingConversationRepository(
      directoryResolver: () async => directory,
    );
    final migration = OnboardingV4Migration(
      directoryResolver: () async => directory,
      conversationRepository: repository,
      clock: () => DateTime.utc(2026, 8, 14, 12),
    );

    final migrated = await migration.run(legacySnapshot: null);

    expect(migrated, isNull);
    expect(await legacy.exists(), isFalse);
    final quarantine = File(
      '${directory.path}${Platform.pathSeparator}onboarding_flow_snapshot.m1_quarantine.json',
    );
    final metadata = jsonDecode(await quarantine.readAsString()) as Map;
    expect(metadata['reasonCode'], 'legacy_m1_in_progress');
    expect(metadata['sourceSchemaVersion'], 1);
    expect(metadata.toString(), isNot(contains('private-legacy-phrase')));
    expect(
      resolveOnboardingLaunchDestination(
        completedSnapshot: null,
        conversationSnapshot: null,
      ),
      AppLaunchDestination.onboarding,
    );
  });

  test('deferred v2 never forces onboarding on cold start', () {
    final deferred = OnboardingConversationSnapshot(
      status: OnboardingConversationStatus.deferred,
      deferredAt: DateTime.utc(2026, 8, 14, 12),
      registryRevision: 'test.2',
      phase: OnboardingCheckpointPhase.selection,
      selectedEntryId: const CareEntryId('care.bedtime_soothing'),
    );

    expect(
      resolveOnboardingLaunchDestination(
        completedSnapshot: null,
        conversationSnapshot: deferred,
      ),
      AppLaunchDestination.shell,
    );
  });

  test('failed quarantine keeps M1 source intact and retry is atomic', () async {
    final directory = await Directory.systemTemp.createTemp(
      'onboarding_v4_quarantine_retry_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final legacy = File(
      '${directory.path}${Platform.pathSeparator}onboarding_flow_snapshot.json',
    );
    await legacy.writeAsString(
      '{"schemaVersion":1,"step":"welcome","updatedAt":"2026-08-01T08:00:00.000Z"}',
    );
    final blockedTarget = Directory(
      '${directory.path}${Platform.pathSeparator}onboarding_flow_snapshot.m1_quarantine.json',
    );
    await blockedTarget.create();
    final migration = OnboardingV4Migration(
      directoryResolver: () async => directory,
      conversationRepository: FileOnboardingConversationRepository(
        directoryResolver: () async => directory,
      ),
      clock: () => DateTime.utc(2026, 8, 14, 12),
    );

    await expectLater(
      migration.run(legacySnapshot: null),
      throwsA(isA<FileSystemException>()),
    );
    expect(await legacy.exists(), isTrue);

    await blockedTarget.delete();
    await migration.run(legacySnapshot: null);
    expect(await legacy.exists(), isFalse);
    expect(await File(blockedTarget.path).exists(), isTrue);
  });

  test('in-progress M1 snapshot is quarantined without private data', () async {
    final directory = await Directory.systemTemp.createTemp(
      'onboarding_v4_snapshot_quarantine_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final legacy = File(
      '${directory.path}${Platform.pathSeparator}onboarding_snapshot.json',
    );
    await legacy.writeAsString(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'childDisplayName': 'private-baby-name',
      }),
    );
    final migration = OnboardingV4Migration(
      directoryResolver: () async => directory,
      conversationRepository: FileOnboardingConversationRepository(
        directoryResolver: () async => directory,
      ),
      clock: () => DateTime.utc(2026, 8, 14, 12),
    );
    final inProgress = OnboardingSnapshot(
      schemaVersion: 1,
      childDisplayName: 'private-baby-name',
      ageBucket: OnboardingAgeBucket.oneToTwo,
      approxMonths: 15,
      currentStage: 'stage_13_18m',
      starterSpaceId: 'daily_care',
      starterActivityId: 'bedtime',
      starterPhraseId: 'private-phrase',
      consentState: OnboardingConsentState.localOnly,
    );

    final migrated = await migration.run(legacySnapshot: inProgress);

    expect(migrated, isNull);
    expect(await legacy.exists(), isFalse);
    final quarantine = File(
      '${directory.path}${Platform.pathSeparator}onboarding_snapshot.m1_quarantine.json',
    );
    final metadata = jsonDecode(await quarantine.readAsString()) as Map;
    expect(metadata['reasonCode'], 'legacy_m1_in_progress');
    expect(metadata['sourceSchemaVersion'], 1);
    expect(metadata.toString(), isNot(contains('private-baby-name')));
    expect(metadata.toString(), isNot(contains('private-phrase')));
  });
}
