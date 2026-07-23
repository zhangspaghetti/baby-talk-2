import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider, Provider;
import 'package:isar/isar.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_flow_store.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/data/services/household_api_service.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'support/isar_test_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): resolveBundledIsarLibraryPath()},
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (MethodCall methodCall) async => null,
        );
  });

  testWidgets('default widget entry routes through the boot gate', (
    WidgetTester tester,
  ) async {
    final harness = (await tester.runAsync<_WidgetBootHarness>(() async {
      return _createHarness();
    }))!;
    addTearDown(harness.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPhraseServiceProvider.overrideWithValue(
            harness.bootState.assetPhraseService!,
          ),
          appDirectoryProvider.overrideWith((ref) => harness.tempDir),
          practiceRepositoryProvider.overrideWith((ref) => harness.repository),
          accountRepositoryProvider.overrideWith(
            (ref) => AccountRepository(
              localStore: AccountLocalStore(),
              practiceRepository: harness.repository,
            ),
          ),
          householdRepositoryProvider.overrideWith((ref) {
            final accountRepo = ref
                .read(accountRepositoryProvider)
                .requireValue;
            return HouseholdRepository(
              localStore: HouseholdLocalStore(
                directoryResolver: () async => harness.tempDir,
              ),
              apiService: HouseholdApiService(),
              accountSnapshotLoader: accountRepo.loadSnapshot,
              persistRefreshedSession: accountRepo.persistRefreshedSession,
            );
          }),
          onboardingRepositoryProvider.overrideWith((ref) {
            final practiceRepo = ref
                .read(practiceRepositoryProvider)
                .requireValue;
            return OnboardingRepository(
              snapshotStore: OnboardingSnapshotStore(
                directoryResolver: () async => harness.tempDir,
              ),
              flowStore: OnboardingFlowStore(
                directoryResolver: () async => harness.tempDir,
              ),
              practiceRepository: practiceRepo,
              starterSpaceId: harness.bootState.primarySpaceId!,
              starterActivityId: harness.bootState.primaryActivityId!,
            );
          }),
        ],
        child: BabyTalkApp(
          bootState: harness.bootState,
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
  });
}

class _WidgetBootHarness {
  _WidgetBootHarness({
    required this.bootState,
    required this.tempDir,
    required this.repository,
  });

  final AppBootState bootState;
  final Directory tempDir;
  final PracticeRepository repository;

  Future<void> close() async {
    await repository.close(deleteFromDisk: true);
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

Future<_WidgetBootHarness> _createHarness() async {
  final bootState = await AppBootState.load(rootBundle);
  final tempDir = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}widget_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  await tempDir.create(recursive: true);
  final localDataSource = await PracticeLocalDataSource.open(
    directory: tempDir.path,
    name: 'widget_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  final repository = PracticeRepository(
    assetPhraseService: bootState.assetPhraseService!,
    localDataSource: localDataSource,
    installationIdService: InstallationIdService(
      directoryResolver: () async => tempDir,
      idGenerator: () => 'install_widget_test',
    ),
  );
  return _WidgetBootHarness(
    bootState: bootState,
    tempDir: tempDir,
    repository: repository,
  );
}

Future<void> _deleteDirectoryWithRetry(
  Directory directory, {
  int attempts = 20,
  Duration delay = const Duration(milliseconds: 50),
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    try {
      if (!await directory.exists()) {
        return;
      }
      await directory.delete(recursive: true);
      return;
    } on PathAccessException {
      await Future<void>.delayed(delay);
    }
  }
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
