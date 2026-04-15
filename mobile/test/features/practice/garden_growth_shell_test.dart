import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/shell/presentation/app_shell_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  testWidgets('shell 在空投影时显示真实花园与成长空态，标题和 drawer 仍可用', (tester) async {
    final harness = (await tester.runAsync<_Harness>(_Harness.create))!;
    addTearDown(harness.dispose);

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
        harness.gardenGrowthViewModel.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildShell());
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));

    expect(find.byKey(const Key('shell-ready')), findsOneWidget);
    expect(find.text('米米 的首页'), findsOneWidget);

    await tester.tap(find.byTooltip('花园'));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-tab-garden')));

    expect(find.text('花园'), findsWidgets);
    expect(find.byKey(const Key('shell-tab-garden')), findsOneWidget);
    expect(find.byKey(const Key('garden-empty-state')), findsOneWidget);
    expect(find.textContaining('第一颗种子还没落下'), findsOneWidget);
    expect(find.textContaining('S04 会把空间花圃'), findsNothing);

    await tester.tap(find.byTooltip('成长'));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-tab-growth')));

    expect(find.text('成长'), findsWidgets);
    expect(find.byKey(const Key('shell-tab-growth')), findsOneWidget);
    expect(find.byKey(const Key('growth-empty-state')), findsOneWidget);
    expect(find.textContaining('最近成长会写在这里'), findsWidgets);

    await tester.tap(find.byKey(const Key('shell-drawer-trigger')));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-end-drawer')));

    expect(find.byKey(const Key('shell-end-drawer')), findsOneWidget);
    expect(find.byKey(const Key('shell-drawer-child-name')), findsOneWidget);
    expect(find.text('米米'), findsWidgets);
  });

  testWidgets('shell 花园与成长页消费同一份投影并显示花朵阶段、自动日记与里程碑', (tester) async {
    final harness = (await tester.runAsync<_Harness>(_Harness.create))!;
    addTearDown(harness.dispose);
    await tester.runAsync(() async {
      await harness.practiceRepository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.engaged,
        clientTimestamp: DateTime.utc(2026, 4, 9, 9, 0),
        localEventId: 'evt_shell_1',
      );
      await harness.practiceRepository.importServerEvents([
        InteractionEventPayload.fromWire(
          eventKey: 'install_garden_shell_test:evt_unknown_1',
          localEventId: 'evt_unknown_1',
          installationId: 'install_garden_shell_test',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_unknown',
          reactionType: 'calm',
          clientTimestamp: DateTime.utc(2026, 4, 9, 9, 1),
        ),
      ]);
    });

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
        harness.gardenGrowthViewModel.refresh(),
      ]);
    });

    await tester.pumpWidget(harness.buildShell());
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));

    await tester.tap(find.byTooltip('花园'));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-tab-garden')));

    expect(find.byKey(const Key('shell-tab-garden')), findsOneWidget);
    expect(find.byKey(const Key('garden-patch-daily_care')), findsOneWidget);
    expect(find.byKey(const Key('garden-flower-bath_time')), findsOneWidget);
    expect(
      find.byKey(const Key('garden-flower-stage-bath_time')),
      findsOneWidget,
    );
    expect(find.textContaining('日常照护'), findsWidgets);
    expect(find.textContaining('发芽'), findsWidgets);
    expect(find.byKey(const Key('garden-projection-warning')), findsOneWidget);
    expect(find.textContaining('未知内容事件'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('garden-continue-practice')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(find.byKey(const Key('garden-continue-practice')), findsOneWidget);

    await tester.tap(find.byTooltip('成长'));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-tab-growth')));

    expect(find.byKey(const Key('shell-tab-growth')), findsOneWidget);
    expect(find.byKey(const Key('growth-latest-impact')), findsOneWidget);
    expect(find.byKey(const Key('growth-projection-warning')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(
        const Key('growth-diary-install_garden_shell_test:evt_shell_1'),
      ),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();

    expect(
      find.byKey(
        const Key('growth-diary-install_garden_shell_test:evt_shell_1'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Warm water.'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('growth-space-daily_care')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(find.byKey(const Key('growth-space-daily_care')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('growth-milestone-first_opening')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('growth-milestone-first_opening')),
      findsOneWidget,
    );
  });

  testWidgets('缺少 garden provider 时 shell 仍显示安全空态，不会退回 discover placeholder', (
    tester,
  ) async {
    final harness = (await tester.runAsync<_Harness>(_Harness.create))!;
    addTearDown(harness.dispose);

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildShell(includeGardenProvider: false));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));

    await tester.tap(find.byTooltip('花园'));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-tab-garden')));
    expect(find.byKey(const Key('garden-empty-state')), findsOneWidget);
    expect(find.textContaining('S04 会把空间花圃'), findsNothing);

    await tester.tap(find.byTooltip('成长'));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-tab-growth')));
    expect(find.byKey(const Key('growth-empty-state')), findsOneWidget);
    expect(find.textContaining('S04 也会把日记'), findsNothing);
  });
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  Duration timeout = const Duration(seconds: 5),
}) async {
  final totalSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var index = 0; index < totalSteps; index++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Timed out waiting for expected widget.');
}

class _Harness {
  _Harness({
    required this.tempDir,
    required this.localDataSource,
    required this.practiceRepository,
    required this.accountViewModel,
    required this.practiceSessionViewModel,
    required this.gardenGrowthViewModel,
  });

  final Directory tempDir;
  final PracticeLocalDataSource localDataSource;
  final PracticeRepository practiceRepository;
  final AccountViewModel accountViewModel;
  final PracticeSessionViewModel practiceSessionViewModel;
  final GardenGrowthViewModel gardenGrowthViewModel;

  static Future<_Harness> create() async {
    final tempDir = await Directory.systemTemp.createTemp('garden_shell_test_');
    final localDataSource = await PracticeLocalDataSource.open(
      directory: tempDir.path,
      name: 'garden_shell_${DateTime.now().microsecondsSinceEpoch}',
    );
    final practiceRepository = PracticeRepository(
      assetPhraseService: AssetPhraseService(bundle: rootBundle),
      localDataSource: localDataSource,
      installationIdService: InstallationIdService(
        directoryResolver: () async => tempDir,
        idGenerator: () => 'install_garden_shell_test',
      ),
    );
    final accountViewModel = AccountViewModel(
      repository: _StaticAccountRepository(),
    );
    final practiceSessionViewModel = PracticeSessionViewModel(
      repository: practiceRepository,
      spaceId: 'daily_care',
      activityId: 'bath_time',
      audioController: _SilentPracticeAudioController(),
    );
    final gardenGrowthViewModel = GardenGrowthViewModel(
      repository: GardenGrowthRepository(
        practiceRepository: practiceRepository,
        assetPhraseService: AssetPhraseService(bundle: rootBundle),
      ),
    );

    return _Harness(
      tempDir: tempDir,
      localDataSource: localDataSource,
      practiceRepository: practiceRepository,
      accountViewModel: accountViewModel,
      practiceSessionViewModel: practiceSessionViewModel,
      gardenGrowthViewModel: gardenGrowthViewModel,
    );
  }

  Widget buildShell({bool includeGardenProvider = true}) {
    final providers = [
      Provider<PracticeRepository>.value(value: practiceRepository),
      ChangeNotifierProvider<AccountViewModel>.value(value: accountViewModel),
      ChangeNotifierProvider<PracticeSessionViewModel>.value(
        value: practiceSessionViewModel,
      ),
      if (includeGardenProvider)
        ChangeNotifierProvider<GardenGrowthViewModel>.value(
          value: gardenGrowthViewModel,
        ),
    ];

    return MultiProvider(
      providers: providers,
      child: MaterialApp(
        theme: AppTheme.build(),
        home: AppShellScreen(
          onboardingSnapshot: OnboardingSnapshot(
            childDisplayName: '米米',
            ageBucket: OnboardingAgeBucket.twelveToEighteen,
            approxMonths: 15,
            currentStage: 'gesture_plus_words',
            starterSpaceId: 'daily_care',
            starterActivityId: 'bath_time',
            starterPhraseId: 'bath_time_warm_water',
            consentState: OnboardingConsentState.localOnly,
            completedAt: DateTime.utc(2026, 4, 8, 8),
          ),
        ),
      ),
    );
  }

  Future<void> dispose() async {
    await practiceRepository.close(deleteFromDisk: true);
    accountViewModel.dispose();
    practiceSessionViewModel.dispose();
    gardenGrowthViewModel.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

class _StaticAccountRepository implements AccountRepository {
  @override
  final String consentVersion = 'pipl-v1';

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> savePlaceholderSession({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async {
    return seedSnapshot ?? AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> close() async {
    return AccountLocalSnapshot.signedOut;
  }
}

class _SilentPracticeAudioController implements PracticeAudioController {
  @override
  Stream<void> get completionStream => const Stream<void>.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playAsset(String assetPath) async {}

  @override
  Future<void> stop() async {}
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
