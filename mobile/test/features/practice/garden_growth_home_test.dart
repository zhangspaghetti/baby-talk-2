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
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  testWidgets('首页在零事件时显示花园入口空态与成长摘要空态', (tester) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
        harness.gardenGrowthViewModel.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-garden-mini-entry')), findsOneWidget);
    expect(find.byKey(const Key('home-growth-summary')), findsOneWidget);
    expect(find.textContaining('你的花园会从第一句开口开始'), findsOneWidget);
    expect(find.textContaining('最近成长会写在这里'), findsOneWidget);
  });

  testWidgets('首页消费同一份投影并显示最近成长摘要与降级提示', (tester) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await harness.practiceRepository.recordReaction(
      spaceId: 'daily_care',
      activityId: 'bath_time',
      phraseId: 'bath_time_warm_water',
      reactionType: BabyReactionType.engaged,
      clientTimestamp: DateTime.utc(2026, 4, 9, 9, 0),
      localEventId: 'evt_home_1',
    );
    await harness.practiceRepository.importServerEvents([
      InteractionEventPayload.fromWire(
        eventKey: 'install_garden_home_test:evt_unknown_1',
        localEventId: 'evt_unknown_1',
        installationId: 'install_garden_home_test',
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_unknown',
        reactionType: 'calm',
        clientTimestamp: DateTime.utc(2026, 4, 9, 9, 1),
      ),
    ]);

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
        harness.gardenGrowthViewModel.refresh(),
      ]);
    });

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-garden-mini-entry')), findsOneWidget);
    expect(find.textContaining('日常照护'), findsWidgets);
    expect(find.byKey(const Key('home-growth-summary')), findsOneWidget);
    expect(find.textContaining('Warm water.'), findsWidgets);
    expect(
      find.byKey(const Key('home-growth-summary-warning')),
      findsOneWidget,
    );
    expect(find.textContaining('未知内容事件'), findsOneWidget);
  });
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
    final tempDir = await Directory.systemTemp.createTemp('garden_home_test_');
    final localDataSource = await PracticeLocalDataSource.open(
      directory: tempDir.path,
      name: 'garden_home_${DateTime.now().microsecondsSinceEpoch}',
    );
    final practiceRepository = PracticeRepository(
      assetPhraseService: AssetPhraseService(bundle: rootBundle),
      localDataSource: localDataSource,
      installationIdService: InstallationIdService(
        directoryResolver: () async => tempDir,
        idGenerator: () => 'install_garden_home_test',
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

  Widget buildApp() {
    return MultiProvider(
      providers: [
        Provider<PracticeRepository>.value(value: practiceRepository),
        Provider<PracticeRouteArgs>.value(
          value: const PracticeRouteArgs(
            spaceId: 'daily_care',
            activityId: 'bath_time',
          ),
        ),
        ChangeNotifierProvider<AccountViewModel>.value(value: accountViewModel),
        ChangeNotifierProvider<PracticeSessionViewModel>.value(
          value: practiceSessionViewModel,
        ),
        ChangeNotifierProvider<GardenGrowthViewModel>.value(
          value: gardenGrowthViewModel,
        ),
      ],
      child: MaterialApp(theme: AppTheme.build(), home: const HomeScreen()),
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
