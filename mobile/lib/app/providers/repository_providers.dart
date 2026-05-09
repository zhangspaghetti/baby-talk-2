import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/data/services/household_api_service.dart';
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/mentor/data/services/mentor_api_service.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/data/services/dynamic_practice_api_service.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';
import 'package:mobile/features/share/data/repositories/share_repository.dart';
import 'package:mobile/features/share/data/services/share_api_service.dart';
import 'package:mobile/features/share/data/services/share_sheet_launcher.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/household/presentation/household_notifier.dart';
import 'package:mobile/features/mentor/presentation/mentor_notifier.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_notifier.dart';
import 'package:mobile/features/share/presentation/share_notifier.dart';

// ---------------------------------------------------------------------------
// App directory
// ---------------------------------------------------------------------------

/// Resolves the application support directory.
final appDirectoryProvider = FutureProvider<Directory>((ref) async {
  try {
    return await getApplicationSupportDirectory();
  } on MissingPluginException {
    final directory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}baby_talk_2_support',
    );
    await directory.create(recursive: true);
    return directory;
  }
});

// ---------------------------------------------------------------------------
// Shared API services (mirrors _SharedConsumerAuthDependencies)
// ---------------------------------------------------------------------------

final accountApiServiceProvider = Provider<AccountApiService>((ref) {
  final service = AccountApiService();
  ref.onDispose(service.close);
  return service;
});

final authenticatedApiClientProvider = Provider<AuthenticatedApiClient>((ref) {
  return AuthenticatedApiClient(
    apiService: ref.watch(accountApiServiceProvider),
  );
});

final dynamicPracticeApiServiceProvider = Provider<DynamicPracticeApiService>((
  ref,
) {
  final service = DynamicPracticeApiService();
  ref.onDispose(service.close);
  return service;
});

final householdApiServiceProvider = Provider<HouseholdApiService>((ref) {
  final service = HouseholdApiService(
    authenticatedApiClient: ref.watch(authenticatedApiClientProvider),
  );
  ref.onDispose(service.close);
  return service;
});

final mentorApiServiceProvider = Provider<MentorApiService>((ref) {
  final service = MentorApiService(
    authenticatedApiClient: ref.watch(authenticatedApiClientProvider),
  );
  ref.onDispose(service.close);
  return service;
});

// ---------------------------------------------------------------------------
// Asset phrase service
// ---------------------------------------------------------------------------

/// Provides the [AssetPhraseService] loaded from the root bundle.
///
/// This must be set externally (e.g. from `AppBootState`) before repositories
/// that depend on it are resolved.
final assetPhraseServiceProvider = Provider<AssetPhraseService>((ref) {
  throw UnimplementedError(
    'assetPhraseServiceProvider must be overridden at startup with '
    'the AssetPhraseService from AppBootState.',
  );
});

// ---------------------------------------------------------------------------
// Practice repository
// ---------------------------------------------------------------------------

final practiceRepositoryProvider = FutureProvider<PracticeRepository>((
  ref,
) async {
  final assetPhraseService = ref.watch(assetPhraseServiceProvider);
  final directory = await ref.watch(appDirectoryProvider.future);
  final dynamicPracticeApiService = ref.watch(
    dynamicPracticeApiServiceProvider,
  );

  final localDataSource = await PracticeLocalDataSource.open(
    directory: directory.path,
  );
  return PracticeRepository(
    assetPhraseService: assetPhraseService,
    localDataSource: localDataSource,
    dynamicPracticeApiService: dynamicPracticeApiService,
    installationIdService: InstallationIdService(
      directoryResolver: () async => directory,
    ),
  );
});

// ---------------------------------------------------------------------------
// Account repository
// ---------------------------------------------------------------------------

final accountRepositoryProvider = FutureProvider<AccountRepository>((
  ref,
) async {
  final practiceRepository = await ref.watch(practiceRepositoryProvider.future);
  final accountApiService = ref.watch(accountApiServiceProvider);
  final authenticatedApiClient = ref.watch(authenticatedApiClientProvider);

  final connectivity = Connectivity();
  return AccountRepository(
    localStore: AccountLocalStore(),
    practiceRepository: practiceRepository,
    apiService: accountApiService,
    authenticatedApiClient: authenticatedApiClient,
    connectivityChecker: () async {
      try {
        final dynamic status = await connectivity.checkConnectivity();
        if (status is List<ConnectivityResult>) {
          return status.any((entry) => entry != ConnectivityResult.none);
        }
        if (status is ConnectivityResult) {
          return status != ConnectivityResult.none;
        }
        return true;
      } on MissingPluginException {
        return true;
      } catch (_) {
        return true;
      }
    },
  );
});

// ---------------------------------------------------------------------------
// Account notifier
// ---------------------------------------------------------------------------

/// Creates an [AccountNotifier] backed by the Riverpod provider graph.
///
/// Uses [ChangeNotifierProvider] (not autoDispose) because the account state
/// must persist across tab switches — the observer lifecycle (foreground
/// resume) depends on it remaining alive.
final accountNotifierProvider = ChangeNotifierProvider<AccountNotifier>((ref) {
  final repository = ref.watch(accountRepositoryProvider).requireValue;
  return AccountNotifier(repository: repository)..initialize();
});

// ---------------------------------------------------------------------------
// Household repository
// ---------------------------------------------------------------------------

final householdRepositoryProvider = FutureProvider<HouseholdRepository>((
  ref,
) async {
  final accountRepository = await ref.watch(accountRepositoryProvider.future);
  final directory = await ref.watch(appDirectoryProvider.future);
  final householdApiService = ref.watch(householdApiServiceProvider);

  return HouseholdRepository(
    localStore: HouseholdLocalStore(directoryResolver: () async => directory),
    apiService: householdApiService,
    accountSnapshotLoader: accountRepository.loadSnapshot,
    persistRefreshedSession: accountRepository.persistRefreshedSession,
  );
});

// ---------------------------------------------------------------------------
// Household notifier
// ---------------------------------------------------------------------------

/// Creates a [HouseholdNotifier] backed by the Riverpod provider graph.
final householdNotifierProvider =
    ChangeNotifierProvider.autoDispose<HouseholdNotifier>((ref) {
      final repository = ref.watch(householdRepositoryProvider).requireValue;
      return HouseholdNotifier(repository: repository)..initialize();
    });

// ---------------------------------------------------------------------------
// Onboarding repository
// ---------------------------------------------------------------------------

final onboardingRepositoryProvider = FutureProvider<OnboardingRepository>((
  ref,
) async {
  // starterSpaceId and starterActivityId must be provided via override.
  throw UnimplementedError(
    'onboardingRepositoryProvider must be overridden with '
    'starterSpaceId and starterActivityId from AppBootState.',
  );
});

// ---------------------------------------------------------------------------
// Onboarding notifier
// ---------------------------------------------------------------------------

/// Creates an [OnboardingNotifier] backed by the Riverpod provider graph.
///
/// The repository is resolved from [onboardingRepositoryProvider] which must
/// be overridden at boot with the correct starterSpaceId and starterActivityId.
final onboardingNotifierProvider =
    ChangeNotifierProvider.autoDispose<OnboardingNotifier>((ref) {
      final repository = ref.watch(onboardingRepositoryProvider).requireValue;
      return OnboardingNotifier(repository: repository)..initialize();
    });

// ---------------------------------------------------------------------------
// Mentor repository
// ---------------------------------------------------------------------------

final mentorRepositoryProvider = FutureProvider<MentorRepository>((ref) async {
  final practiceRepository = await ref.watch(practiceRepositoryProvider.future);
  final directory = await ref.watch(appDirectoryProvider.future);
  final householdRepository = await ref.watch(
    householdRepositoryProvider.future,
  );

  final onboardingStore = OnboardingSnapshotStore(
    directoryResolver: () async => directory,
  );

  return MentorRepository(
    localDataSource: await MentorLocalDataSource.open(
      directory: directory.path,
    ),
    practiceRepository: practiceRepository,
    onboardingSnapshotStore: onboardingStore,
    householdSnapshotLoader: householdRepository.loadSnapshot,
  );
});

// ---------------------------------------------------------------------------
// Mentor notifier
// ---------------------------------------------------------------------------

/// Creates a [MentorNotifier] backed by the Riverpod provider graph.
///
/// Watches [accountNotifierProvider] so that account state changes (e.g.
/// login/logout) flow automatically into chat availability derivation —
/// mirroring the old `ChangeNotifierProxyProvider` behavior.
final mentorNotifierProvider =
    ChangeNotifierProvider.autoDispose<MentorNotifier>((ref) {
      final mentorRepository = ref.watch(mentorRepositoryProvider).requireValue;
      final accountNotifier = ref.watch(accountNotifierProvider);
      return MentorNotifier(
        repository: mentorRepository,
        accountNotifier: accountNotifier,
      );
    });

// ---------------------------------------------------------------------------
// Garden growth repository & notifier
// ---------------------------------------------------------------------------

final gardenGrowthRepositoryProvider = Provider<GardenGrowthRepository>((ref) {
  // practiceRepositoryProvider is a FutureProvider resolved during app
  // bootstrap, so .requireValue is safe here by the time the garden tab is
  // visible.
  final practiceRepository = ref.watch(practiceRepositoryProvider).requireValue;
  final assetPhraseService = ref.watch(assetPhraseServiceProvider);
  return GardenGrowthRepository(
    practiceRepository: practiceRepository,
    assetPhraseService: assetPhraseService,
  );
});

/// Creates a [GardenGrowthNotifier] backed by the Riverpod provider graph.
///
/// The notifier is auto-disposed so that pulling the tab away from the garden
/// screen releases the resources.
final gardenGrowthNotifierProvider =
    ChangeNotifierProvider.autoDispose<GardenGrowthNotifier>((ref) {
      final repository = ref.watch(gardenGrowthRepositoryProvider);
      return GardenGrowthNotifier(repository: repository)..initialize();
    });

// ---------------------------------------------------------------------------
// Share services & repository
// ---------------------------------------------------------------------------

final shareApiServiceProvider = Provider<ShareApiService>((ref) {
  final service = ShareApiService();
  ref.onDispose(service.close);
  return service;
});

final shareSheetLauncherProvider = Provider<ShareSheetLauncher>((ref) {
  return const SharePlusSheetLauncher();
});

final shareRepositoryProvider = Provider<ShareRepository>((ref) {
  return ShareRepository(
    apiService: ref.watch(shareApiServiceProvider),
    shareSheetLauncher: ref.watch(shareSheetLauncherProvider),
  );
});

// ---------------------------------------------------------------------------
// Practice continuity notifier
// ---------------------------------------------------------------------------

/// Creates a [PracticeContinuityNotifier] backed by the Riverpod provider graph.
///
/// The notifier is auto-disposed so that pulling the tab away from the practice
/// screen releases the resources.
final practiceContinuityNotifierProvider =
    ChangeNotifierProvider.autoDispose<PracticeContinuityNotifier>((ref) {
      final practiceRepository = ref
          .watch(practiceRepositoryProvider)
          .requireValue;
      return PracticeContinuityNotifier(repository: practiceRepository)
        ..initialize();
    });

// ---------------------------------------------------------------------------
// Share notifier
// ---------------------------------------------------------------------------

/// Creates a [ShareNotifier] backed by the Riverpod provider graph.
///
/// Watches [gardenGrowthNotifierProvider] and [practiceContinuityNotifierProvider]
/// so that snapshot updates flow automatically — mirroring the old
/// `ChangeNotifierProxyProvider2` behavior.
final shareNotifierProvider = ChangeNotifierProvider.autoDispose<ShareNotifier>(
  (ref) {
    final shareRepository = ref.watch(shareRepositoryProvider);

    final gardenNotifier = ref.watch(gardenGrowthNotifierProvider);
    final continuityNotifier = ref.watch(practiceContinuityNotifierProvider);

    return ShareNotifier(
      repository: shareRepository,
      initialGrowthSnapshot: gardenNotifier.snapshot,
      initialContinuitySnapshot: continuityNotifier.hasResolvedRecommendation
          ? continuityNotifier.snapshot
          : null,
    );
  },
);
