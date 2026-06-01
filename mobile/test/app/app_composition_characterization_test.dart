import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider, Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/invite_reentry_coordinator.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/share_reentry_coordinator.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/data/services/household_api_service.dart';
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (MethodCall methodCall) async => null,
        );

    // Stub the audioplayers plugin channels. Some providers may lazily create
    // an AudioPlayer whose init fires after a test completes; without a stub it
    // throws MissingPluginException and fails the surrounding test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (MethodCall methodCall) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (MethodCall methodCall) async => null,
        );
  });

  testWidgets(
    'shell boot bridges selected legacy Provider repositories into Riverpod overrides',
    (WidgetTester tester) async {
      late OnboardingSnapshot completedSnapshot;
      final shareCoordinator = ShareReentryCoordinator();
      final inviteCoordinator = InviteReentryCoordinator();

      final harness = (await tester.runAsync<_AppCompositionHarness>(() async {
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
          completedAt: DateTime.utc(2026, 5, 18, 8),
        );
        return created;
      }))!;
      addTearDown(harness.close);
      addTearDown(() async {
        await _disposeWidgetTree(tester);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assetPhraseServiceProvider.overrideWithValue(
              harness.bootState.assetPhraseService!,
            ),
            appDirectoryProvider.overrideWith((ref) => harness.tempDir),
            practiceRepositoryProvider.overrideWith(
              (ref) => harness.repository,
            ),
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
                practiceRepository: practiceRepo,
                starterSpaceId: harness.bootState.primarySpaceId!,
                starterActivityId: harness.bootState.primaryActivityId!,
              );
            }),
            mentorRepositoryProvider.overrideWith(
              (ref) async => harness.mentorRepository,
            ),
            shareReentryCoordinatorProvider.overrideWith(
              (ref) => shareCoordinator,
            ),
            inviteReentryCoordinatorProvider.overrideWith(
              (ref) => inviteCoordinator,
            ),
          ],
          child: BabyTalkApp(
            bootState: harness.bootState,
            audioControllerFactory: _SilentPracticeAudioController.new,
            completedSnapshotLoader: () async => completedSnapshot,
            shareReentryCoordinator: shareCoordinator,
            inviteReentryCoordinator: inviteCoordinator,
            practiceContinuityRefreshTimeout: Duration.zero,
            gardenGrowthRefreshTimeout: Duration.zero,
          ),
        ),
      );
      await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));

      final shellContext = tester.element(find.byKey(const Key('shell-ready')));
      final container = ProviderScope.containerOf(shellContext, listen: false);

      final legacyPracticeRepository = (await tester
          .runAsync<PracticeRepository>(() {
            return container.read(practiceRepositoryProvider.future);
          }))!;
      expect(
        (await tester.runAsync<AccountRepository>(() {
          return container.read(accountRepositoryProvider.future);
        }))!,
        isA<AccountRepository>(),
      );
      expect(
        (await tester.runAsync<HouseholdRepository>(() {
          return container.read(householdRepositoryProvider.future);
        }))!,
        isA<HouseholdRepository>(),
      );

      expect(
        container.read(shareReentryCoordinatorProvider),
        same(shareCoordinator),
      );
      expect(
        container.read(inviteReentryCoordinatorProvider),
        same(inviteCoordinator),
      );
      expect(
        container.read(defaultPracticeRouteArgsProvider).activityId,
        harness.bootState.primaryActivityId,
      );
      final riverpodPracticeRepository = (await tester
          .runAsync<PracticeRepository>(() {
            return container.read(practiceRepositoryProvider.future);
          }))!;
      final riverpodOnboardingRepository = (await tester
          .runAsync<OnboardingRepository>(() {
            return container.read(onboardingRepositoryProvider.future);
          }))!;

      expect(riverpodPracticeRepository, same(legacyPracticeRepository));
      expect(riverpodOnboardingRepository, isA<OnboardingRepository>());

      final riverpodAccountRepository = (await tester
          .runAsync<AccountRepository>(() {
            return container.read(accountRepositoryProvider.future);
          }))!;
      final riverpodHouseholdRepository = (await tester
          .runAsync<HouseholdRepository>(() {
            return container.read(householdRepositoryProvider.future);
          }))!;
      expect(riverpodAccountRepository, isA<AccountRepository>());
      expect(riverpodHouseholdRepository, isA<HouseholdRepository>());
    },
  );

}

class _AppCompositionHarness {
  const _AppCompositionHarness({
    required this.bootState,
    required this.tempDir,
    required this.repository,
    required this.mentorRepository,
  });

  final AppBootState bootState;
  final Directory tempDir;
  final PracticeRepository repository;
  final MentorRepository mentorRepository;

  Future<void> close() async {
    await mentorRepository.close(deleteFromDisk: true);
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

Future<_AppCompositionHarness> _createHarness() async {
  final bootState = await AppBootState.load(rootBundle);
  final tempDir = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}app_composition_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  await tempDir.create(recursive: true);
  final localDataSource = await PracticeLocalDataSource.open(
    directory: tempDir.path,
    name: 'app_composition_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  final repository = PracticeRepository(
    assetPhraseService: bootState.assetPhraseService!,
    localDataSource: localDataSource,
    installationIdService: InstallationIdService(
      directoryResolver: () async => tempDir,
      idGenerator: () => 'install_app_composition_test',
    ),
  );
  final mentorLocalDataSource = await MentorLocalDataSource.open(
    directory: tempDir.path,
    name: 'mentor_app_composition_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  final mentorRepository = MentorRepository(
    localDataSource: mentorLocalDataSource,
    practiceRepository: repository,
    onboardingSnapshotStore: OnboardingSnapshotStore(
      directoryResolver: () async => tempDir,
    ),
  );
  return _AppCompositionHarness(
    bootState: bootState,
    tempDir: tempDir,
    repository: repository,
    mentorRepository: mentorRepository,
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
    return;
  }
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  // Settle any mixed real/fake async Isar operations kicked off by the
  // HomeScreen post-frame notifier inits (continuity/garden reads, account
  // installation-id write). Their native completions need a real event loop
  // (tester.runAsync) while their Dart continuations are microtasks parked on
  // the fake-async queue (drained by tester.pump). Alternating both repeatedly
  // lets the transactions fully commit and release the practice Isar lock, so
  // repository.close(deleteFromDisk: true) does not deadlock during teardown.
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
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
