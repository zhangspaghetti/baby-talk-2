import 'dart:async';
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
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';

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
      practiceRepository = _buildPracticeRepository(
        localDataSource: practiceLocalDataSource,
        directory: tempDir,
      );
      onboardingSnapshotStore = OnboardingSnapshotStore(
        directoryResolver: () async => tempDir,
      );
      mentorRepository = _buildMentorRepository(
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

    test(
      'recent continuity 来自非 starter activity 时复用同一 activity 与 phrase',
      () async {
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
          spaceId: 'family_rhythm',
          activityId: 'feeding_time',
          phraseId: 'feeding_time_open_wide',
          reactionType: BabyReactionType.calm,
          clientTimestamp: DateTime.utc(2026, 4, 9, 8, 3),
          localEventId: 'practice_evt_feed_1',
        );
        await practiceRepository.recordReaction(
          spaceId: 'family_rhythm',
          activityId: 'feeding_time',
          phraseId: 'feeding_time_yummy_bite',
          reactionType: BabyReactionType.imitated,
          clientTimestamp: DateTime.utc(2026, 4, 9, 8, 4),
          localEventId: 'practice_evt_feed_2',
        );

        final result = await mentorRepository.deriveLocalSuggestions();

        expect(result.contextFallbackUsed, isFalse);
        expect(
          result.primaryOrigin,
          LocalMentorSuggestionOrigin.recentPractice,
        );
        expect(result.fallbackReasonCode, isNull);
        expect(result.suggestions, isNotEmpty);
        expect(
          result.suggestions.first.origin,
          LocalMentorSuggestionOrigin.recentPractice,
        );
        expect(result.suggestions.first.activityId, 'feeding_time');
        expect(result.suggestions.first.phraseId, 'feeding_time_yummy_bite');
        expect(result.suggestions.first.phraseEnglish, 'Yummy bite.');
        expect(
          result.redactedContextSummary,
          'recent_result:feeding_time/feeding_time_yummy_bite:imitated',
        );
      },
    );

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
      expect(result.redactedContextSummary, 'fallback:onboarding_missing');
    });

    test(
      '零事件 continuity 时退回 starter phrase 并显式暴露 starter fallback code',
      () async {
        await onboardingSnapshotStore.write(
          OnboardingSnapshot(
            childDisplayName: '米米',
            ageBucket: OnboardingAgeBucket.zeroToSix,
            approxMonths: 4,
            currentStage: 'warm_routines',
            starterSpaceId: 'daily_care',
            starterActivityId: 'bath_time',
            starterPhraseId: 'bath_time_warm_water',
            consentState: OnboardingConsentState.localOnly,
            completedAt: DateTime.utc(2026, 4, 9, 8, 0),
          ),
        );

        final result = await mentorRepository.deriveLocalSuggestions();

        expect(result.contextFallbackUsed, isFalse);
        expect(result.primaryOrigin, LocalMentorSuggestionOrigin.starterPhrase);
        expect(result.fallbackReasonCode, 'starter_fallback');
        expect(result.suggestions.first.activityId, 'bath_time');
        expect(result.suggestions.first.phraseId, 'bath_time_warm_water');
        expect(
          result.redactedContextSummary,
          'starter_fallback:bath_time/bath_time_warm_water',
        );
      },
    );

    test('continuity 读取超时时返回安全本地建议并标记 reason', () async {
      await onboardingSnapshotStore.write(
        OnboardingSnapshot(
          childDisplayName: '可可',
          ageBucket: OnboardingAgeBucket.zeroToSix,
          approxMonths: 5,
          currentStage: 'warm_routines',
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
          starterPhraseId: 'bath_time_warm_water',
          consentState: OnboardingConsentState.localOnly,
          completedAt: DateTime.utc(2026, 4, 9, 8, 0),
        ),
      );
      practiceRepository = _ContinuityOverridePracticeRepository(
        assetPhraseService: AssetPhraseService(bundle: rootBundle),
        localDataSource: practiceLocalDataSource,
        installationIdService: InstallationIdService(
          directoryResolver: () async => tempDir,
          idGenerator: () => 'install_mentor_test',
        ),
        continuityLoader: ({starterSpaceId, starterActivityId}) {
          throw TimeoutException('continuity timeout');
        },
      );
      mentorRepository = _buildMentorRepository(
        localDataSource: mentorLocalDataSource,
        practiceRepository: practiceRepository,
        onboardingSnapshotStore: onboardingSnapshotStore,
      );

      final result = await mentorRepository.deriveLocalSuggestions();

      expect(result.contextFallbackUsed, isTrue);
      expect(result.primaryOrigin, LocalMentorSuggestionOrigin.safeFallback);
      expect(result.fallbackReasonCode, 'continuity_timeout');
      expect(result.redactedContextSummary, 'fallback:continuity_timeout');
    });

    test(
      'recent continuity 映射异常时退回 starter phrase 并保留 fallback reason',
      () async {
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
          spaceId: 'family_rhythm',
          activityId: 'feeding_time',
          phraseId: 'feeding_time_yummy_bite',
          reactionType: BabyReactionType.imitated,
          clientTimestamp: DateTime.utc(2026, 4, 9, 8, 4),
          localEventId: 'practice_evt_recent_1',
        );
        final realContinuity = await practiceRepository.getContinuitySnapshot(
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
        );
        final malformedRecentActivity = _copyActivitySummary(
          realContinuity.recommendedActivity,
          recentResult: PracticeCatalogRecentResultSummary(
            phraseId: realContinuity.recommendedActivity.recentResult!.phraseId,
            phraseEnglish: ' ',
            reactionType:
                realContinuity.recommendedActivity.recentResult!.reactionType,
            eventTime:
                realContinuity.recommendedActivity.recentResult!.eventTime,
            totalEvents:
                realContinuity.recommendedActivity.recentResult!.totalEvents,
          ),
        );
        practiceRepository = _ContinuityOverridePracticeRepository(
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
          localDataSource: practiceLocalDataSource,
          installationIdService: InstallationIdService(
            directoryResolver: () async => tempDir,
            idGenerator: () => 'install_mentor_test',
          ),
          continuityLoader: ({starterSpaceId, starterActivityId}) async {
            return PracticeContinuitySnapshot(
              catalog: realContinuity.catalog,
              recommendedActivity: malformedRecentActivity,
              recentActivity: malformedRecentActivity,
              nextIncompleteActivity: realContinuity.nextIncompleteActivity,
              starterActivity: realContinuity.starterActivity,
              recommendation: realContinuity.recommendation,
              cadence: realContinuity.cadence,
              warningMessage: realContinuity.warningMessage,
            );
          },
        );
        mentorRepository = _buildMentorRepository(
          localDataSource: mentorLocalDataSource,
          practiceRepository: practiceRepository,
          onboardingSnapshotStore: onboardingSnapshotStore,
        );

        final result = await mentorRepository.deriveLocalSuggestions();

        expect(result.contextFallbackUsed, isFalse);
        expect(result.primaryOrigin, LocalMentorSuggestionOrigin.starterPhrase);
        expect(result.fallbackReasonCode, 'recent_context_unmapped');
        expect(result.suggestions.first.phraseId, 'bath_time_warm_water');
        expect(
          result.redactedContextSummary,
          'starter_fallback:recent_context_unmapped:bath_time/bath_time_warm_water',
        );
      },
    );

    test('starter activity 无效且没有 recent context 时安全降级并区分 reason', () async {
      await onboardingSnapshotStore.write(
        OnboardingSnapshot(
          childDisplayName: '米米',
          ageBucket: OnboardingAgeBucket.zeroToSix,
          approxMonths: 3,
          currentStage: 'warm_routines',
          starterSpaceId: 'daily_care',
          starterActivityId: 'missing_activity',
          starterPhraseId: 'bath_time_warm_water',
          consentState: OnboardingConsentState.localOnly,
          completedAt: DateTime.utc(2026, 4, 9, 8, 0),
        ),
      );

      final result = await mentorRepository.deriveLocalSuggestions();

      expect(result.contextFallbackUsed, isTrue);
      expect(result.primaryOrigin, LocalMentorSuggestionOrigin.safeFallback);
      expect(result.fallbackReasonCode, 'starter_activity_invalid');
      expect(
        result.redactedContextSummary,
        'fallback:starter_activity_invalid',
      );
    });

    test('onboarding store 不可读时返回安全本地建议并暴露 persistence reason', () async {
      onboardingSnapshotStore = _ThrowingOnboardingSnapshotStore(
        error: const OnboardingSnapshotPersistenceException(
          '读取 onboarding snapshot 失败：disk offline',
        ),
      );
      mentorRepository = _buildMentorRepository(
        localDataSource: mentorLocalDataSource,
        practiceRepository: practiceRepository,
        onboardingSnapshotStore: onboardingSnapshotStore,
      );

      final result = await mentorRepository.deriveLocalSuggestions();

      expect(result.contextFallbackUsed, isTrue);
      expect(result.primaryOrigin, LocalMentorSuggestionOrigin.safeFallback);
      expect(result.fallbackReasonCode, 'onboarding_unavailable');
      expect(result.redactedContextSummary, 'fallback:onboarding_unavailable');
    });
  });
}

MentorRepository _buildMentorRepository({
  required MentorLocalDataSource localDataSource,
  required PracticeRepository practiceRepository,
  required OnboardingSnapshotStore onboardingSnapshotStore,
}) {
  return MentorRepository(
    localDataSource: localDataSource,
    practiceRepository: practiceRepository,
    onboardingSnapshotStore: onboardingSnapshotStore,
  );
}

PracticeRepository _buildPracticeRepository({
  required PracticeLocalDataSource localDataSource,
  required Directory directory,
}) {
  return PracticeRepository(
    assetPhraseService: AssetPhraseService(bundle: rootBundle),
    localDataSource: localDataSource,
    installationIdService: InstallationIdService(
      directoryResolver: () async => directory,
      idGenerator: () => 'install_mentor_test',
    ),
  );
}

class _ContinuityOverridePracticeRepository extends PracticeRepository {
  _ContinuityOverridePracticeRepository({
    required super.assetPhraseService,
    required super.localDataSource,
    required super.installationIdService,
    required this.continuityLoader,
  });

  final Future<PracticeContinuitySnapshot> Function({
    String? starterSpaceId,
    String? starterActivityId,
  })
  continuityLoader;

  @override
  Future<PracticeContinuitySnapshot> getContinuitySnapshot({
    String? starterSpaceId,
    String? starterActivityId,
  }) {
    return continuityLoader(
      starterSpaceId: starterSpaceId,
      starterActivityId: starterActivityId,
    );
  }
}

class _ThrowingOnboardingSnapshotStore extends OnboardingSnapshotStore {
  _ThrowingOnboardingSnapshotStore({required this.error})
    : super(directoryResolver: () async => Directory.systemTemp);

  final Object error;

  @override
  Future<OnboardingSnapshot?> read() async {
    throw error;
  }
}

PracticeCatalogActivitySummary _copyActivitySummary(
  PracticeCatalogActivitySummary source, {
  PracticeCatalogRecentResultSummary? recentResult,
}) {
  return PracticeCatalogActivitySummary(
    spaceId: source.spaceId,
    spaceTitle: source.spaceTitle,
    activityId: source.activityId,
    title: source.title,
    summary: source.summary,
    sceneTag: source.sceneTag,
    coachTip: source.coachTip,
    totalPhraseCount: source.totalPhraseCount,
    completedPhraseCount: source.completedPhraseCount,
    completedPhraseIds: source.completedPhraseIds,
    nextPhraseId: source.nextPhraseId,
    nextPhraseEnglish: source.nextPhraseEnglish,
    totalEvents: source.totalEvents,
    skippedUnknownPhraseCount: source.skippedUnknownPhraseCount,
    skippedMalformedEventCount: source.skippedMalformedEventCount,
    lastEventTime: source.lastEventTime,
    recentResult: recentResult,
    warningMessage: source.warningMessage,
  );
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
