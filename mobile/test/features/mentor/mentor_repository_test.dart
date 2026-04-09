import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/mentor/domain/models/local_mentor_suggestion.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  group('MentorRepository', () {
    late Directory tempDir;
    late String mentorDbName;
    late String practiceDbName;
    late MentorLocalDataSource mentorLocalDataSource;
    late PracticeLocalDataSource practiceLocalDataSource;
    late PracticeRepository practiceRepository;
    late OnboardingSnapshotStore onboardingSnapshotStore;
    late MentorRepository mentorRepository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mentor_repository_test_',
      );
      mentorDbName = 'mentor_${DateTime.now().microsecondsSinceEpoch}';
      practiceDbName = 'practice_${DateTime.now().microsecondsSinceEpoch}';
      mentorLocalDataSource = await MentorLocalDataSource.open(
        directory: tempDir.path,
        name: mentorDbName,
      );
      practiceLocalDataSource = await PracticeLocalDataSource.open(
        directory: tempDir.path,
        name: practiceDbName,
      );
      practiceRepository = PracticeRepository(
        assetPhraseService: AssetPhraseService(bundle: rootBundle),
        localDataSource: practiceLocalDataSource,
        installationIdService: InstallationIdService(
          directoryResolver: () async => tempDir,
          idGenerator: () => 'install_mentor_test',
        ),
      );
      onboardingSnapshotStore = OnboardingSnapshotStore(
        directoryResolver: () async => tempDir,
      );
      mentorRepository = MentorRepository(
        localDataSource: mentorLocalDataSource,
        practiceRepository: practiceRepository,
        onboardingSnapshotStore: onboardingSnapshotStore,
      );
    });

    tearDown(() async {
      try {
        await mentorRepository.close(deleteFromDisk: true);
      } catch (_) {}
      try {
        await practiceLocalDataSource.close(deleteFromDisk: true);
      } catch (_) {}
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('独立 mentor seam 保持 append-only，并把事实字段与诊断字段分层存储', () async {
      final fact = await mentorRepository.appendFact(
        eventType: MentorFactType.suggestionServed,
        phase: 'local_suggestion_ready',
        localEventId: 'mentor_evt_1',
        createdAt: DateTime.utc(2026, 4, 9, 8, 0),
        correlationId: 'corr_123',
        redactedSummary: 'starter phrase delivered from local context',
        visibleStatus: 'offline',
        visibleDetail: '当前展示本地建议',
        contextFallbackUsed: true,
      );

      final inspection = await mentorRepository.inspectFactLog();
      final storedEntities = await mentorLocalDataSource.listRawEntities();
      final practiceInspection = await practiceRepository.inspectEventLog();

      expect(fact.eventKey, 'install_mentor_test:mentor_evt_1');
      expect(inspection.storedFactCount, 1);
      expect(inspection.validFactCount, 1);
      expect(
        inspection.validFacts.single.eventType,
        MentorFactType.suggestionServed,
      );
      expect(practiceInspection.storedEventCount, 0);

      final factMap = storedEntities.single.toPersistedFactMap();
      final diagnosticsMap = storedEntities.single.toPersistedDiagnosticsMap();

      expect(
        factMap.keys,
        containsAll([
          'eventKey',
          'localEventId',
          'installationId',
          'eventType',
          'createdAt',
        ]),
      );
      expect(factMap.keys, isNot(contains('redactedSummary')));
      expect(factMap.keys, isNot(contains('visibleStatus')));
      expect(diagnosticsMap['phase'], 'local_suggestion_ready');
      expect(
        diagnosticsMap['redactedSummary'],
        'starter phrase delivered from local context',
      );
      expect(diagnosticsMap['visibleStatus'], 'offline');
      expect(diagnosticsMap['contextFallbackUsed'], isTrue);
      expect(diagnosticsMap.values.join(' '), isNot(contains('raw prompt')));
      expect(diagnosticsMap.values.join(' '), isNot(contains('raw response')));
    });

    test('拒绝重复 eventKey，并在本地库不可写时暴露明确错误', () async {
      await mentorRepository.appendFact(
        eventType: MentorFactType.panelOpened,
        phase: 'sheet_opened',
        localEventId: 'mentor_dup',
        createdAt: DateTime.utc(2026, 4, 9, 8, 1),
      );

      await expectLater(
        mentorRepository.appendFact(
          eventType: MentorFactType.panelOpened,
          phase: 'sheet_opened_again',
          localEventId: 'mentor_dup',
          createdAt: DateTime.utc(2026, 4, 9, 8, 1),
        ),
        throwsFormatException,
      );

      await mentorLocalDataSource.close();

      await expectLater(
        mentorRepository.appendFact(
          eventType: MentorFactType.chatFailed,
          phase: 'append_after_close',
          localEventId: 'mentor_closed',
          createdAt: DateTime.utc(2026, 4, 9, 8, 2),
        ),
        throwsA(
          isA<MentorPersistenceException>().having(
            (error) => error.message,
            'message',
            contains('追加 mentor fact 失败'),
          ),
        ),
      );
    });

    test('有最近练习结果时优先派生 recent-practice 建议', () async {
      await onboardingSnapshotStore.write(
        OnboardingSnapshot(
          childDisplayName: '小满',
          ageBucket: OnboardingAgeBucket.sixToTwelve,
          approxMonths: 9,
          currentStage: 'sound_turn_taking',
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
          starterPhraseId: 'bath_time_warm_water',
          consentState: OnboardingConsentState.localOnly,
          completedAt: DateTime.utc(2026, 4, 9, 8, 0),
        ),
      );
      await practiceRepository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_splash_splash',
        reactionType: BabyReactionType.imitated,
        clientTimestamp: DateTime.utc(2026, 4, 9, 8, 3),
        localEventId: 'practice_evt_1',
      );

      final result = await mentorRepository.deriveLocalSuggestions();

      expect(result.contextFallbackUsed, isFalse);
      expect(result.primaryOrigin, LocalMentorSuggestionOrigin.recentPractice);
      expect(result.fallbackReasonCode, isNull);
      expect(result.suggestions, isNotEmpty);
      expect(
        result.suggestions.first.origin,
        LocalMentorSuggestionOrigin.recentPractice,
      );
      expect(result.suggestions.first.phraseId, 'bath_time_splash_splash');
      expect(result.suggestions.first.phraseEnglish, 'Splash, splash!');
      expect(
        result.redactedContextSummary,
        contains('recent_result:bath_time/bath_time_splash_splash'),
      );
    });

    test('缺失 onboarding snapshot 时返回安全本地建议', () async {
      final result = await mentorRepository.deriveLocalSuggestions();

      expect(result.contextFallbackUsed, isTrue);
      expect(result.primaryOrigin, LocalMentorSuggestionOrigin.safeFallback);
      expect(result.fallbackReasonCode, 'onboarding_missing');
      expect(result.suggestions, isNotEmpty);
      expect(
        result.suggestions.every((suggestion) => suggestion.isSafeFallback),
        isTrue,
      );
    });

    test('starter seed 缺失或 restore 不兼容时留在 mentor seam 内并安全降级', () async {
      await onboardingSnapshotStore.write(
        OnboardingSnapshot(
          childDisplayName: '米米',
          ageBucket: OnboardingAgeBucket.zeroToSix,
          approxMonths: 3,
          currentStage: 'warm_routines',
          starterSpaceId: 'daily_care',
          starterActivityId: 'missing_activity',
          starterPhraseId: ' ',
          consentState: OnboardingConsentState.localOnly,
          completedAt: DateTime.utc(2026, 4, 9, 8, 0),
        ),
      );

      final result = await mentorRepository.deriveLocalSuggestions();
      final practiceInspection = await practiceRepository.inspectEventLog();

      expect(result.contextFallbackUsed, isTrue);
      expect(result.primaryOrigin, LocalMentorSuggestionOrigin.safeFallback);
      expect(result.fallbackReasonCode, 'starter_seed_missing');
      expect(practiceInspection.storedEventCount, 0);
    });
  });
}

String _resolveBundledIsarLibraryPath() {
  final pubCacheRoot = Platform.environment['PUB_CACHE'];
  final localAppData = Platform.environment['LOCALAPPDATA'];
  final candidateRoots = <Directory>[
    if (pubCacheRoot != null) Directory(pubCacheRoot),
    if (localAppData != null) Directory('$localAppData\\Pub\\Cache'),
  ];

  for (final root in candidateRoots) {
    final hostedDirectory = Directory(
      '${root.path}${Platform.pathSeparator}hosted',
    );
    if (!hostedDirectory.existsSync()) {
      continue;
    }

    for (final host in hostedDirectory.listSync().whereType<Directory>()) {
      for (final packageDir in host.listSync().whereType<Directory>()) {
        final packageName = packageDir.path.split(RegExp(r'[\\/]')).last;
        if (!packageName.startsWith('isar_flutter_libs-')) {
          continue;
        }

        final dll = File(
          '${packageDir.path}${Platform.pathSeparator}windows${Platform.pathSeparator}isar.dll',
        );
        if (dll.existsSync()) {
          return dll.path;
        }
      }
    }
  }

  throw StateError('未在 pub cache 中找到 isar_flutter_libs/windows/isar.dll');
}
