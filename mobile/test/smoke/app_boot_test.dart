import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider, Provider;
import 'package:isar/isar.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );

    // app_links 插件在 shell 路由中订阅 EventChannel，单元测试环境需要 mock
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (MethodCall methodCall) async => null,
        );
  });

  test('seed content parser rejects malformed payload', () {
    expect(
      () => SeedContentBundle.fromJsonString('{"schemaVersion":1,"spaces":[]}'),
      throwsFormatException,
    );
  });

  test('seed content validator rejects wrong audio asset key', () async {
    final bundle = SeedContentBundle(
      spaces: [
        SeedSpace(
          id: 'daily_care',
          title: '日常照护',
          description: 'desc',
          activities: [
            SeedActivity(
              id: 'bath_time',
              title: '洗澡时间',
              summary: 'summary',
              sceneTag: 'Bath time',
              coachTip: 'tip',
              phrases: [
                SeedPhrase(
                  id: 'bad',
                  step: 1,
                  english: 'Bad',
                  chinese: '坏',
                  pronunciation: 'bad',
                  difficulty: 'starter',
                  audioAsset: 'audio/bad.mp3',
                ),
              ],
            ),
          ],
        ),
      ],
    );

    expect(bundle.validateAssets(rootBundle), throwsFormatException);
  });

  testWidgets('fresh install 先进入 onboarding gate，而不是默认 guest home', (
    WidgetTester tester,
  ) async {
    final harness = (await tester.runAsync<_AppBootHarness>(() async {
      return _createHarness();
    }))!;
    addTearDown(harness.close);
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });

    await tester.pumpWidget(
      ProviderScope(
        child: BabyTalkApp(
          bootState: harness.bootState,
          repositoryFactory: (_) async => harness.repository,
          appDirectoryResolver: () async => harness.tempDir,
          audioControllerFactory: _SilentPracticeAudioController.new,
          completedSnapshotLoader: () async => null,
          practiceContinuityRefreshTimeout: const Duration(milliseconds: 1),
          gardenGrowthRefreshTimeout: const Duration(milliseconds: 1),
        ),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('boot-route-onboarding')),
    );

    expect(find.byKey(const Key('boot-route-gate-ready')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-onboarding')), findsOneWidget);
    expect(
      find.byKey(const Key('onboarding-local-only-banner')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-start-practice')), findsNothing);

    final content = harness.bootState.content!;
    final allActivities = [
      for (final space in content.spaces) ...space.activities,
    ];
    final allPhrases = [
      for (final activity in allActivities) ...activity.phrases,
    ];

    expect(content.spaces.map((space) => space.id), [
      'daily_care',
      'family_rhythm',
    ]);
    expect(allActivities.map((activity) => activity.id), [
      'bath_time',
      'diaper_change',
      'feeding_time',
      'bedtime',
    ]);
    expect(allPhrases, hasLength(9));

    for (final phrase in allPhrases) {
      final audioBytes = await rootBundle.load(phrase.audioAsset);
      expect(audioBytes.lengthInBytes, greaterThan(0));
    }
  });

  testWidgets('存在 completed snapshot 时冷启动直接进入 shell home', (
    WidgetTester tester,
  ) async {
    late OnboardingSnapshot completedSnapshot;
    final harness = (await tester.runAsync<_AppBootHarness>(() async {
      final created = await _createHarness();
      final onboardingRepository = OnboardingRepository(
        snapshotStore: OnboardingSnapshotStore(
          directoryResolver: () async => created.tempDir,
        ),
        practiceRepository: created.repository,
        starterSpaceId: created.bootState.primarySpaceId!,
        starterActivityId: created.bootState.primaryActivityId!,
      );
      completedSnapshot = await onboardingRepository.completeOnboarding(
        childDisplayName: '米米',
        ageBucket: OnboardingAgeBucket.zeroToSix,
        completedAt: DateTime.utc(2026, 4, 8, 8),
      );
      return created;
    }))!;
    addTearDown(harness.close);
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });

    await tester.pumpWidget(
      ProviderScope(
        child: BabyTalkApp(
          bootState: harness.bootState,
          repositoryFactory: (_) async => harness.repository,
          appDirectoryResolver: () async => harness.tempDir,
          audioControllerFactory: _SilentPracticeAudioController.new,
          completedSnapshotLoader: () async => completedSnapshot,
          practiceContinuityRefreshTimeout: const Duration(milliseconds: 1),
          gardenGrowthRefreshTimeout: const Duration(milliseconds: 1),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('boot-route-shell')));

    expect(find.byKey(const Key('boot-route-gate-ready')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-shell')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-onboarding')), findsNothing);
  });

  testWidgets(
    '存在 completed snapshot 与 recent activity 时冷启动会 seed continuity recommendation',
    (WidgetTester tester) async {
      late OnboardingSnapshot completedSnapshot;
      final harness = (await tester.runAsync<_AppBootHarness>(() async {
        final created = await _createHarness();
        await created.repository.recordReaction(
          spaceId: 'family_rhythm',
          activityId: 'feeding_time',
          phraseId: 'feeding_time_open_wide',
          reactionType: BabyReactionType.engaged,
          clientTimestamp: DateTime.utc(2026, 4, 8, 9, 0),
          localEventId: 'evt_boot_feed_1',
        );
        await created.repository.recordReaction(
          spaceId: 'family_rhythm',
          activityId: 'feeding_time',
          phraseId: 'feeding_time_yummy_bite',
          reactionType: BabyReactionType.imitated,
          clientTimestamp: DateTime.utc(2026, 4, 8, 9, 1),
          localEventId: 'evt_boot_feed_2',
        );
        final onboardingRepository = OnboardingRepository(
          snapshotStore: OnboardingSnapshotStore(
            directoryResolver: () async => created.tempDir,
          ),
          practiceRepository: created.repository,
          starterSpaceId: created.bootState.primarySpaceId!,
          starterActivityId: created.bootState.primaryActivityId!,
        );
        completedSnapshot = await onboardingRepository.completeOnboarding(
          childDisplayName: '米米',
          ageBucket: OnboardingAgeBucket.zeroToSix,
          completedAt: DateTime.utc(2026, 4, 8, 8),
        );
        return created;
      }))!;
      addTearDown(harness.close);
      addTearDown(() async {
        await _disposeWidgetTree(tester);
      });

      await tester.pumpWidget(
        ProviderScope(
          child: BabyTalkApp(
            bootState: harness.bootState,
            repositoryFactory: (_) async => harness.repository,
            appDirectoryResolver: () async => harness.tempDir,
            audioControllerFactory: _SilentPracticeAudioController.new,
            completedSnapshotLoader: () async => completedSnapshot,
            practiceContinuityRefreshTimeout: const Duration(milliseconds: 1),
            gardenGrowthRefreshTimeout: const Duration(milliseconds: 1),
          ),
        ),
      );
      await _pumpUntilFound(tester, find.byKey(const Key('boot-route-shell')));
      await tester.pump();

      final shellElement = tester.element(find.byKey(const Key('shell-ready')));
      final continuityNotifier = Provider.of<PracticeContinuityNotifier>(
        shellElement,
        listen: false,
      );
      expect(continuityNotifier.hasResolvedRecommendation, isTrue);
      expect(continuityNotifier.recommendedArgs?.activityId, 'feeding_time');
      expect(
        continuityNotifier.snapshot?.recommendation.reason,
        PracticeContinuityReason.recentActivity,
      );
      expect(continuityNotifier.lastRefreshReason, 'boot_seed_recent_activity');

      await tester.tap(find.byTooltip('成长'));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('shell-tab-growth-combined')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('garden-continue-practice')),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();

      expect(
        find.byKey(const Key('garden-continue-target-feeding_time')),
        findsOneWidget,
      );
      expect(find.textContaining('继续最近 activity'), findsWidgets);
    },
  );

  testWidgets('malformed account snapshot 只会退回未登录，不会破坏 shell route gate', (
    WidgetTester tester,
  ) async {
    late OnboardingSnapshot completedSnapshot;
    late AccountLocalSnapshot loadedAccountSnapshot;
    final harness = (await tester.runAsync<_AppBootHarness>(() async {
      final created = await _createHarness();
      final onboardingRepository = OnboardingRepository(
        snapshotStore: OnboardingSnapshotStore(
          directoryResolver: () async => created.tempDir,
        ),
        practiceRepository: created.repository,
        starterSpaceId: created.bootState.primarySpaceId!,
        starterActivityId: created.bootState.primaryActivityId!,
      );
      completedSnapshot = await onboardingRepository.completeOnboarding(
        childDisplayName: '米米',
        ageBucket: OnboardingAgeBucket.zeroToSix,
        completedAt: DateTime.utc(2026, 4, 8, 8),
      );
      final accountRepository = AccountRepository(
        localStore: AccountLocalStore(
          secureStorage: const _MalformedSecureStorage(),
        ),
        practiceRepository: created.repository,
      );
      loadedAccountSnapshot = await accountRepository.loadSnapshot();
      return created;
    }))!;
    addTearDown(harness.close);
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });

    expect(loadedAccountSnapshot.consentState, AccountConsentState.signedOut);
    expect(loadedAccountSnapshot.session, isNull);

    await tester.pumpWidget(
      ProviderScope(
        child: BabyTalkApp(
          bootState: harness.bootState,
          repositoryFactory: (_) async => harness.repository,
          appDirectoryResolver: () async => harness.tempDir,
          audioControllerFactory: _SilentPracticeAudioController.new,
          completedSnapshotLoader: () async => completedSnapshot,
          practiceContinuityRefreshTimeout: const Duration(milliseconds: 1),
          gardenGrowthRefreshTimeout: const Duration(milliseconds: 1),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('boot-route-shell')));

    expect(find.byKey(const Key('boot-route-gate-ready')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-shell')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-onboarding')), findsNothing);
  });

  testWidgets('snapshot 目录读取失败时暴露明确的 route gate 失败态', (
    WidgetTester tester,
  ) async {
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });
    final bootState = (await tester.runAsync<AppBootState>(() async {
      return AppBootState.load(rootBundle);
    }))!;

    await tester.pumpWidget(
      ProviderScope(
        child: BabyTalkApp(
          bootState: bootState,
          repositoryFactory: (_) async {
            throw StateError('repository factory should not be called');
          },
          appDirectoryResolver: () async => throw StateError('disk denied'),
          audioControllerFactory: _SilentPracticeAudioController.new,
        ),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('boot-route-gate-failed')),
    );

    expect(find.byKey(const Key('boot-route-gate-failed')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-gate-retry')), findsOneWidget);
    expect(find.textContaining('onboarding 本地档案读取失败'), findsOneWidget);
  });
}

class _AppBootHarness {
  const _AppBootHarness({
    required this.bootState,
    required this.tempDir,
    required this.localDataSource,
    required this.repository,
  });

  final AppBootState bootState;
  final Directory tempDir;
  final PracticeLocalDataSource localDataSource;
  final PracticeRepository repository;

  Future<void> close() async {
    await repository.close(deleteFromDisk: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (await tempDir.exists()) {
      await _deleteDirectoryWithRetry(tempDir);
    }
  }
}

class _SilentPracticeAudioController implements PracticeAudioController {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get completionStream => _controller.stream;

  @override
  Future<void> playAsset(String assetPath) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

Future<_AppBootHarness> _createHarness() async {
  final bootState = await AppBootState.load(rootBundle);
  final tempDir = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}app_boot_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  await tempDir.create(recursive: true);
  final localDataSource = await PracticeLocalDataSource.open(
    directory: tempDir.path,
    name: 'app_boot_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  final repository = PracticeRepository(
    assetPhraseService: bootState.assetPhraseService!,
    localDataSource: localDataSource,
    installationIdService: InstallationIdService(
      directoryResolver: () async => tempDir,
      idGenerator: () => 'install_app_boot_test',
    ),
  );
  return _AppBootHarness(
    bootState: bootState,
    tempDir: tempDir,
    localDataSource: localDataSource,
    repository: repository,
  );
}

Future<void> _deleteDirectoryWithRetry(
  Directory directory, {
  int attempts = 20,
  Duration delay = const Duration(milliseconds: 50),
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < attempts; attempt++) {
    try {
      if (!await directory.exists()) {
        return;
      }
      await directory.delete(recursive: true);
      return;
    } on PathAccessException catch (error) {
      lastError = error;
      await Future<void>.delayed(delay);
    }
  }

  if (lastError != null) {
    // Windows + Isar close 可能在测试销毁后短暂持有文件句柄；这里做 best-effort 清理，
    // 避免把已经完成的启动 proof 伪打红。
    return;
  }
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pump();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  Duration timeout = const Duration(seconds: 12),
}) async {
  final totalSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var index = 0; index < totalSteps; index++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Timed out waiting for expected widget.');
}

/// 用于测试：模拟返回 malformed account JSON（accepted_pending_sync 但无 session）
class _MalformedSecureStorage extends FlutterSecureStorage {
  const _MalformedSecureStorage();

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return '{"consentState":"accepted_pending_sync","session":null}';
  }
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
