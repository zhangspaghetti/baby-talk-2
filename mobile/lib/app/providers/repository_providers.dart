import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mobile/app/local_sensitive_data_clearance_registry.dart';
import 'package:mobile/app/custom_scene_recovery_coordinator.dart';
import 'package:mobile/app/router/custom_scene_care_turn_handoff.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/core/local_data_lifecycle/local_sensitive_data_clearance.dart';
import 'package:mobile/core/local_data_lifecycle/local_sensitive_data_backup_protection.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/care_entry/data/file_onboarding_care_turn_continuation_store.dart';
import 'package:mobile/features/care_entry/presentation/care_entry_providers.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/presentation/care_path_notifier.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_draft_store.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_repository_impl.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_repository.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_handoff_confirmation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/data/services/household_api_service.dart';
import 'package:mobile/features/garden/data/local/garden_fertilizer_local_data_source.dart';
import 'package:mobile/features/garden/data/remote/garden_fertilizer_api_service.dart';
import 'package:mobile/features/garden/data/remote/garden_snapshot_api_service.dart';
import 'package:mobile/features/garden/data/repositories/garden_fertilizer_repository.dart';
import 'package:mobile/features/garden/presentation/garden_fertilizer_notifier.dart';
import 'package:mobile/features/growth/data/remote/growth_insights_api_service.dart';
import 'package:mobile/features/growth/data/remote/growth_summary_api_service.dart';
import 'package:mobile/features/growth/presentation/growth_insights_notifier.dart';
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/mentor/data/services/mentor_api_service.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/generated/generated_care_moment_local_store.dart';
import 'package:mobile/features/practice/data/generated/generated_care_turn_resume_marker_store.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_api.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_memory_cache.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_repository.dart';
import 'package:mobile/features/practice/data/generated/generated_practice_content_registry.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/repositories/preset_scene_catalog_repository.dart';
import 'package:mobile/features/practice/data/remote/preset_scene_catalog_api.dart';
import 'package:mobile/features/practice/data/local/preset_scene_catalog_store.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/data/services/dynamic_practice_api_service.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:mobile/features/share/data/repositories/share_repository.dart';
import 'package:mobile/features/share/data/services/share_api_service.dart';
import 'package:mobile/features/share/data/services/share_sheet_launcher.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/household/presentation/household_notifier.dart';
import 'package:mobile/features/mentor/presentation/mentor_notifier.dart';
import 'package:mobile/features/settings/data/local/settings_local_data_source.dart';
import 'package:mobile/features/settings/data/repositories/baby_profile_repository.dart';
import 'package:mobile/features/settings/data/repositories/settings_repository.dart';
import 'package:mobile/features/settings/data/reminder_scheduler.dart';
import 'package:mobile/features/settings/presentation/settings_notifier.dart';
import 'package:mobile/features/share/presentation/share_notifier.dart';
import 'package:mobile/features/scene_generation/data/scene_generation_api.dart';
import 'package:mobile/features/scene_generation/data/scene_generation_repository_impl.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_repository.dart';
import 'package:mobile/app/share_reentry_coordinator.dart';
import 'package:mobile/app/invite_reentry_coordinator.dart';

// ---------------------------------------------------------------------------
// App directory
// ---------------------------------------------------------------------------

/// Resolves the application support directory.
final appDirectoryProvider = FutureProvider<Directory>((ref) async {
  try {
    final directory = await getApplicationSupportDirectory();
    return const LocalSensitiveDataBackupProtection()
        .ensureDirectoryExcludedFromBackupIfRequired(directory);
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

final presetSceneCatalogApiProvider = Provider<PresetSceneCatalogApi>((ref) {
  final service = PresetSceneCatalogApi();
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

final sceneGenerationApiProvider = Provider<SceneGenerationApi>((ref) {
  final service = SceneGenerationApi(
    authenticatedApiClient: ref.watch(authenticatedApiClientProvider),
  );
  ref.onDispose(service.close);
  return service;
});

final generatedAudioApiProvider = Provider<GeneratedAudioApi>((ref) {
  final service = GeneratedAudioApi(
    authenticatedApiClient: ref.watch(authenticatedApiClientProvider),
  );
  ref.onDispose(service.close);
  return service;
});

final growthSummaryApiServiceProvider = Provider<GrowthSummaryApiService>((
  ref,
) {
  final service = GrowthSummaryApiService();
  ref.onDispose(service.close);
  return service;
});

final growthInsightsApiServiceProvider = Provider<GrowthInsightsApiService>((
  ref,
) {
  final service = GrowthInsightsApiService(
    authenticatedApiClient: ref.watch(authenticatedApiClientProvider),
    sessionLoader: () async {
      final repository = await ref.read(accountRepositoryProvider.future);
      return (await repository.loadSnapshot()).session;
    },
    persistRefreshedSession: (session) async {
      final repository = await ref.read(accountRepositoryProvider.future);
      return repository.persistRefreshedSession(session);
    },
  );
  ref.onDispose(service.close);
  return service;
});

final gardenSnapshotApiServiceProvider = Provider<GardenSnapshotApiService>((
  ref,
) {
  final service = GardenSnapshotApiService();
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

final householdLocalStoreProvider = Provider<HouseholdLocalStore>((ref) {
  return HouseholdLocalStore(
    directoryResolver: () => ref.read(appDirectoryProvider.future),
  );
});

final presetSceneCatalogStoreProvider = Provider<PresetSceneCatalogStore>((
  ref,
) {
  return PresetSceneCatalogStore(
    directoryResolver: () => ref.read(appDirectoryProvider.future),
  );
});

final presetSceneCatalogRepositoryProvider =
    Provider<PresetSceneCatalogRepository>((ref) {
      return PresetSceneCatalogRepository(
        api: ref.watch(presetSceneCatalogApiProvider),
        store: ref.watch(presetSceneCatalogStoreProvider),
        assetPhraseService: ref.watch(assetPhraseServiceProvider),
      );
    });

final generatedCareMomentLocalStoreProvider =
    Provider<GeneratedCareMomentLocalStore>((ref) {
      return GeneratedCareMomentLocalStore(
        directoryResolver: () => ref.read(appDirectoryProvider.future),
      );
    });

final generatedCareTurnResumeMarkerStoreProvider =
    Provider<GeneratedCareTurnResumeMarkerStore>((ref) {
      return GeneratedCareTurnResumeMarkerStore(
        directoryResolver: () => ref.read(appDirectoryProvider.future),
        householdScopeLoader: () async =>
            (await ref.read(householdLocalStoreProvider).read()).householdId,
      );
    });

final generatedPracticeContentRegistryProvider =
    Provider<GeneratedPracticeContentRegistry>((ref) {
      return GeneratedPracticeContentRegistry(
        store: ref.watch(generatedCareMomentLocalStoreProvider),
        resumeStore: ref.watch(generatedCareTurnResumeMarkerStoreProvider),
        accountContextLoader: () async {
          final snapshot = await AccountLocalStore().read();
          return snapshot.session?.accountId;
        },
        householdScopeLoader: () async =>
            (await ref.read(householdLocalStoreProvider).read()).householdId,
        currentAccessContextLoader: () async {
          final AccountLocalSnapshot accountSnapshot;
          try {
            accountSnapshot = await AccountLocalStore().read();
          } on Object {
            return const GeneratedPracticeAccessContext.accountReadUnavailable();
          }
          final session = accountSnapshot.session;
          if (session == null ||
              accountSnapshot.consentState == AccountConsentState.localOnly ||
              accountSnapshot.consentState == AccountConsentState.signedOut) {
            return GeneratedPracticeAccessContext.denied(
              accountContext: session?.accountId,
              reason: GeneratedPracticeAccessDeniedReason.signedOut,
            );
          }
          if (accountSnapshot.consentState == AccountConsentState.revoked) {
            return GeneratedPracticeAccessContext.denied(
              accountContext: session.accountId,
              reason: GeneratedPracticeAccessDeniedReason.consentRevoked,
            );
          }
          if (accountSnapshot.consentState == AccountConsentState.deleted) {
            return GeneratedPracticeAccessContext.denied(
              accountContext: session.accountId,
              reason: GeneratedPracticeAccessDeniedReason.accountDeleted,
            );
          }
          if (accountSnapshot.consentState !=
              AccountConsentState.acceptedPendingSync) {
            return GeneratedPracticeAccessContext.denied(
              accountContext: session.accountId,
              reason: GeneratedPracticeAccessDeniedReason.consentRequired,
            );
          }

          final HouseholdLocalSnapshot householdSnapshot;
          try {
            householdSnapshot = await ref
                .read(householdLocalStoreProvider)
                .read();
          } on Object {
            return GeneratedPracticeAccessContext.householdReadUnavailable(
              accountContext: session.accountId,
            );
          }
          final householdId = householdSnapshot.householdId;
          return GeneratedPracticeAccessContext.accepted(
            accountContext: session.accountId,
            householdScopeFingerprint: householdId == null
                ? null
                : householdScopeFingerprint(householdId),
            pendingClearHouseholdScopeFingerprint:
                householdSnapshot.pendingClearHouseholdScopeFingerprint,
          );
        },
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
    contentResolver: ref.watch(generatedPracticeContentRegistryProvider),
    presetSceneCatalogRepository: ref.watch(
      presetSceneCatalogRepositoryProvider,
    ),
    installationIdService: InstallationIdService(
      directoryResolver: () async => directory,
    ),
  );
});

final generatedAudioMemoryCacheProvider = Provider<GeneratedAudioMemoryCache>((
  ref,
) {
  return GeneratedAudioMemoryCache();
});

final generatedAudioRepositoryProvider = Provider<GeneratedAudioRepository>((
  ref,
) {
  return GeneratedAudioRepository(
    api: ref.watch(generatedAudioApiProvider),
    cache: ref.watch(generatedAudioMemoryCacheProvider),
    accountSnapshotLoader: () async {
      final repository = await ref.read(accountRepositoryProvider.future);
      return repository.loadSnapshot();
    },
    persistRefreshedSession: (session) async {
      final repository = await ref.read(accountRepositoryProvider.future);
      return repository.persistRefreshedSession(session);
    },
  );
});

// ---------------------------------------------------------------------------
// Account repository
// ---------------------------------------------------------------------------

final authContinuationStoreProvider = Provider<AuthContinuationStore>((ref) {
  return AuthContinuationStore(
    directoryResolver: () => ref.read(appDirectoryProvider.future),
  );
});

final authContinuationCoordinatorProvider =
    Provider<AuthContinuationCoordinator>((ref) {
      return AuthContinuationCoordinator(
        store: ref.watch(authContinuationStoreProvider),
      );
    });

final customSceneDraftStoreProvider = Provider<CustomSceneDraftStore>((ref) {
  return CustomSceneDraftStore(
    directoryResolver: () => ref.read(appDirectoryProvider.future),
  );
});

final customSceneDraftContinuationCoordinatorProvider =
    Provider<CustomSceneDraftContinuationCoordinator>((ref) {
      return CustomSceneDraftContinuationCoordinator(
        draftStore: ref.watch(customSceneDraftStoreProvider),
        authContinuationCoordinator: ref.watch(
          authContinuationCoordinatorProvider,
        ),
      );
    });

final customSceneHandoffConfirmationCoordinatorProvider =
    Provider<CustomSceneHandoffConfirmationCoordinator>((ref) {
      return CustomSceneHandoffConfirmationCoordinator(
        draftContinuationCoordinator: ref.watch(
          customSceneDraftContinuationCoordinatorProvider,
        ),
        accountContextLoader: ref
            .watch(generatedPracticeContentRegistryProvider)
            .loadCurrentAccountContext,
        generatedCareTurnResumeStore: ref.watch(
          generatedCareTurnResumeMarkerStoreProvider,
        ),
      );
    });

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

final babyProfileRepositoryProvider = Provider<BabyProfileRepository>((ref) {
  return BabyProfileRepository(
    apiService: ref.watch(accountApiServiceProvider),
    authenticatedApiClient: ref.watch(authenticatedApiClientProvider),
    accountSnapshotLoader: () async {
      final repository = await ref.read(accountRepositoryProvider.future);
      return repository.loadSnapshot();
    },
    persistRefreshedSession: (session) async {
      final repository = await ref.read(accountRepositoryProvider.future);
      return repository.persistRefreshedSession(session);
    },
  );
});

// ---------------------------------------------------------------------------
// Custom scene repository
// ---------------------------------------------------------------------------

final customSceneRepositoryProvider = FutureProvider<CustomSceneRepository>((
  ref,
) async {
  return CustomSceneRepositoryImpl(
    sceneGenerationRepository: await ref.watch(
      sceneGenerationRepositoryProvider.future,
    ),
  );
});

final sceneGenerationRepositoryProvider =
    FutureProvider<SceneGenerationRepository>((ref) async {
      final accountRepository = await ref.watch(
        accountRepositoryProvider.future,
      );
      final practiceRepository = await ref.watch(
        practiceRepositoryProvider.future,
      );
      final settingsRepository = await ref.watch(
        settingsRepositoryProvider.future,
      );
      return SceneGenerationRepositoryImpl(
        api: ref.watch(sceneGenerationApiProvider),
        accountSnapshotLoader: accountRepository.loadSnapshot,
        persistRefreshedSession: accountRepository.persistRefreshedSession,
        localeLoader: () async {
          final preferredLanguage = (await settingsRepository.readSettings())
              .preferredLanguage
              .trim();
          return switch (preferredLanguage) {
            'zh' || 'zh-CN' || 'en' || 'bilingual' => 'zh-CN',
            _ => 'zh-CN',
          };
        },
        installationIdLoader: practiceRepository.ensureInstallationId,
      );
    });

final customSceneSubmissionControllerProvider =
    FutureProvider<CustomSceneSubmissionController>((ref) async {
      final controller = CustomSceneSubmissionController(
        repository: await ref.watch(customSceneRepositoryProvider.future),
        draftStore: ref.watch(customSceneDraftStoreProvider),
        draftContinuationCoordinator: ref.watch(
          customSceneDraftContinuationCoordinatorProvider,
        ),
        approvedContentRegistrar: ref.watch(
          generatedPracticeContentRegistryProvider,
        ),
        accountContextLoader: ref
            .watch(generatedPracticeContentRegistryProvider)
            .loadCurrentAccountContext,
      );
      ref.onDispose(controller.dispose);
      return controller;
    }, dependencies: [customSceneRepositoryProvider]);

final customSceneRecoveryCoordinatorProvider =
    FutureProvider<CustomSceneRecoveryCoordinator>((ref) async {
      final coordinator = CustomSceneRecoveryCoordinator(
        controller: await ref.watch(
          customSceneSubmissionControllerProvider.future,
        ),
        handoffSink: const AppCustomSceneCareTurnHandoffSink(),
      );
      ref.onDispose(coordinator.dispose);
      return coordinator;
    }, dependencies: [customSceneSubmissionControllerProvider]);

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
  return AccountNotifier(
    repository: repository,
    challengeRepository: createAccountChallengeRepository(repository),
    acceptConsent: ({required consentVersion}) =>
        repository.acceptConsent(version: consentVersion),
    onAccountSessionEnded: () => const PlatformReminderScheduler().cancel(),
    localDataClearanceRunner:
        ({
          required trigger,
          required correlationId,
          required requestedAt,
        }) async {
          final orchestrator = await ref.read(
            localSensitiveDataClearanceOrchestratorProvider.future,
          );
          return orchestrator.clear(
            LocalSensitiveDataClearanceRequest(
              trigger: trigger,
              authorization: switch (trigger) {
                LocalSensitiveDataClearanceTrigger.deviceEraseConfirmed =>
                  CaregiverConfirmedAuthorization(
                    confirmedAt: requestedAt,
                    confirmationText: '清除本机数据',
                  ),
                LocalSensitiveDataClearanceTrigger.logoutSessionOnly =>
                  const ReportOnlyAuthorization(reason: 'session logout'),
                LocalSensitiveDataClearanceTrigger.consentWithdrawalConfirmed ||
                LocalSensitiveDataClearanceTrigger.accountDeletionConfirmed ||
                LocalSensitiveDataClearanceTrigger.staffPlusVerificationOnly =>
                  ref.read(accountDestructiveClearanceAuthorizationProvider),
              },
              correlationId: correlationId,
              requestedAt: requestedAt,
            ),
          );
        },
  )..initialize();
});

// ---------------------------------------------------------------------------
// Household repository
// ---------------------------------------------------------------------------

final householdRepositoryProvider = FutureProvider<HouseholdRepository>((
  ref,
) async {
  final accountRepository = await ref.watch(accountRepositoryProvider.future);
  final householdApiService = ref.watch(householdApiServiceProvider);

  return HouseholdRepository(
    localStore: ref.watch(householdLocalStoreProvider),
    apiService: householdApiService,
    accountSnapshotLoader: accountRepository.loadSnapshot,
    accountSnapshotReadResultLoader: accountRepository.loadSnapshotWithStatus,
    persistRefreshedSession: accountRepository.persistRefreshedSession,
    clearGeneratedContentForHouseholdScope: ref
        .watch(generatedPracticeContentRegistryProvider)
        .clearForHouseholdScope,
    clearGeneratedContentForHouseholdScopeFingerprint: ref
        .watch(generatedPracticeContentRegistryProvider)
        .clearForHouseholdScopeFingerprint,
  );
});

// ---------------------------------------------------------------------------
// Household notifier
// ---------------------------------------------------------------------------

/// Creates a [HouseholdNotifier] backed by the Riverpod provider graph.
final householdNotifierProvider = ChangeNotifierProvider<HouseholdNotifier>((
  ref,
) {
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

  final repository = MentorRepository(
    localDataSource: await MentorLocalDataSource.open(
      directory: directory.path,
    ),
    practiceRepository: practiceRepository,
    onboardingSnapshotStore: onboardingStore,
    householdSnapshotLoader: householdRepository.loadSnapshot,
  );
  ref.onDispose(repository.close);
  return repository;
});

// ---------------------------------------------------------------------------
// Local sensitive data lifecycle clearance
// ---------------------------------------------------------------------------

final accountDestructiveClearanceAuthorizationProvider =
    Provider<StaffPlusDestructiveAuthorization>((ref) {
      return StaffPlusDestructiveAuthorization(
        decisionId: 'HDR-R4-003',
        approvedBy: 'human-red-decision',
        approvedAt: DateTime.utc(2026, 5, 20),
        confirmationText:
            'Approved account deletion/device erasure local sensitive data clearance.',
      );
    });

final localSensitiveDataClearanceOrchestratorProvider =
    FutureProvider<LocalSensitiveDataClearanceOrchestrator>((ref) async {
      final accountRepository = await ref.watch(
        accountRepositoryProvider.future,
      );
      final onboardingRepository = await ref.watch(
        onboardingRepositoryProvider.future,
      );
      final householdRepository = await ref.watch(
        householdRepositoryProvider.future,
      );
      final practiceRepository = await ref.watch(
        practiceRepositoryProvider.future,
      );
      final mentorRepository = await ref.watch(mentorRepositoryProvider.future);
      final authContinuationCoordinator = ref.watch(
        authContinuationCoordinatorProvider,
      );
      final customSceneDraftContinuationCoordinator = ref.watch(
        customSceneDraftContinuationCoordinatorProvider,
      );
      final generatedPracticeContentRegistry = ref.watch(
        generatedPracticeContentRegistryProvider,
      );
      final presetSceneCatalogStore = ref.watch(
        presetSceneCatalogStoreProvider,
      );
      final presetSceneCatalogRepository = ref.watch(
        presetSceneCatalogRepositoryProvider,
      );
      final generatedAudioMemoryCache = ref.watch(
        generatedAudioMemoryCacheProvider,
      );
      final settingsRepository = await ref.watch(
        settingsRepositoryProvider.future,
      );
      final onboardingCareTurnContinuationStore = ref.watch(
        onboardingCareTurnContinuationStoreProvider,
      );

      return createLocalSensitiveDataClearanceOrchestrator(
        accountRepository: accountRepository,
        onboardingRepository: onboardingRepository,
        householdRepository: householdRepository,
        practiceRepository: practiceRepository,
        mentorRepository: mentorRepository,
        authContinuationCoordinator: authContinuationCoordinator,
        customSceneDraftContinuationCoordinator:
            customSceneDraftContinuationCoordinator,
        generatedPracticeContentRegistry: generatedPracticeContentRegistry,
        presetSceneCatalogStore: presetSceneCatalogStore,
        presetSceneCatalogRepository: presetSceneCatalogRepository,
        generatedAudioMemoryCache: generatedAudioMemoryCache,
        settingsLocalDataSource: settingsRepository.localDataSource,
        onboardingCareTurnContinuationClearance:
            onboardingCareTurnContinuationStore.clearForLifecycle,
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
/// Non-autoDispose because mentor state must persist across tab switches
/// and modal sheet open/close cycles.
final mentorNotifierProvider = ChangeNotifierProvider<MentorNotifier>((ref) {
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
/// Non-autoDispose because garden state is read by multiple tabs (garden,
/// growth, share) and must persist across tab switches.
final gardenGrowthNotifierProvider =
    ChangeNotifierProvider<GardenGrowthNotifier>((ref) {
      final repository = ref.watch(gardenGrowthRepositoryProvider);
      return GardenGrowthNotifier(repository: repository)..initialize();
    });

// ---------------------------------------------------------------------------
// Care path facade repository & notifier
// ---------------------------------------------------------------------------

final onboardingCareTurnContinuationStoreProvider =
    Provider<FileOnboardingCareTurnContinuationStore>(
      (ref) {
        final appDirectory = ref.watch(appDirectoryProvider).requireValue;
        return FileOnboardingCareTurnContinuationStore(
          conversationRepository: ref.watch(
            onboardingConversationRepositoryProvider,
          ),
          directoryResolver: () async => appDirectory,
        );
      },
      dependencies: [
        onboardingConversationRepositoryProvider,
        appDirectoryProvider,
      ],
    );

final carePathRepositoryProvider = Provider<CarePathRepository>(
  (ref) {
    final practiceRepository = ref
        .watch(practiceRepositoryProvider)
        .requireValue;
    return CarePathRepository(
      practiceRepository: practiceRepository,
      gardenGrowthRepository: ref.watch(gardenGrowthRepositoryProvider),
      onboardingContinuationPort: ref.watch(
        onboardingCareTurnContinuationStoreProvider,
      ),
    );
  },
  dependencies: [
    practiceRepositoryProvider,
    gardenGrowthRepositoryProvider,
    onboardingCareTurnContinuationStoreProvider,
  ],
);

final carePathNotifierProvider = ChangeNotifierProvider<CarePathNotifier>((
  ref,
) {
  return CarePathNotifier(repository: ref.watch(carePathRepositoryProvider))
    ..initialize();
}, dependencies: [carePathRepositoryProvider]);

/// Garden V2 fertilizer API service (remote data source for fertilizer state).
final gardenFertilizerApiServiceProvider = Provider<GardenFertilizerApiService>(
  (ref) {
    final service = GardenFertilizerApiService(
      authenticatedApiClient: ref.watch(authenticatedApiClientProvider),
    );
    ref.onDispose(service.close);
    return service;
  },
);

/// Garden V2 fertilizer repository (own Isar instance, lazily opened).
final gardenFertilizerRepositoryProvider =
    FutureProvider<GardenFertilizerRepository>((ref) async {
      final directory = await ref.watch(appDirectoryProvider.future);
      final accountRepository = await ref.watch(
        accountRepositoryProvider.future,
      );
      final localDataSource = await GardenFertilizerLocalDataSource.open(
        directory: directory.path,
      );
      return GardenFertilizerRepository(
        localDataSource: localDataSource,
        remoteDataSource: ref.watch(gardenFertilizerApiServiceProvider),
        accountSnapshotLoader: accountRepository.loadSnapshot,
        persistRefreshedSession: accountRepository.persistRefreshedSession,
      );
    });

/// Garden V2 fertilizer notifier composing the persisted fertilizer state with
/// the garden growth snapshot (practice traces).
final gardenFertilizerNotifierProvider =
    ChangeNotifierProvider<GardenFertilizerNotifier>((ref) {
      final growthNotifier = ref.watch(gardenGrowthNotifierProvider);
      return GardenFertilizerNotifier(
        repositoryFuture: ref.watch(gardenFertilizerRepositoryProvider.future),
        growthNotifier: growthNotifier,
      )..initialize();
      // Declared so this provider is re-created within the nested ProviderScope
      // in app.dart where gardenGrowthNotifierProvider is overridden.
    }, dependencies: [gardenGrowthNotifierProvider]);

/// Growth V2 insights notifier: fetches aggregated streak / per-period
/// stats / trend buckets from the remote API with local cache fallback.
final growthInsightsNotifierProvider =
    ChangeNotifierProvider<GrowthInsightsNotifier>((ref) {
      final account = ref.read(accountNotifierProvider);
      final notifier = GrowthInsightsNotifier(
        apiService: ref.watch(growthInsightsApiServiceProvider),
        accountContext: account.stableAccountContext,
      );
      ref.listen<AccountNotifier>(accountNotifierProvider, (_, next) {
        notifier.bindAccountContext(next.stableAccountContext);
        unawaited(notifier.initialize());
      });
      return notifier..initialize();
    }, dependencies: [accountNotifierProvider]);

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
/// Non-autoDispose because continuity state is read by garden, growth, and
/// share tabs and must persist across tab switches.
final practiceContinuityNotifierProvider =
    ChangeNotifierProvider<PracticeContinuityNotifier>((ref) {
      final practiceRepository = ref
          .watch(practiceRepositoryProvider)
          .requireValue;
      return PracticeContinuityNotifier(repository: practiceRepository)
        ..initialize();
    });

@immutable
class PracticeSessionProviderArgs {
  const PracticeSessionProviderArgs({
    required this.routeArgs,
    this.audioControllerFactory,
  });

  final PracticeRouteArgs routeArgs;
  final PracticeAudioController Function()? audioControllerFactory;

  @override
  bool operator ==(Object other) {
    return other is PracticeSessionProviderArgs &&
        routeArgs.normalizedSpaceId == other.routeArgs.normalizedSpaceId &&
        routeArgs.normalizedActivityId ==
            other.routeArgs.normalizedActivityId &&
        routeArgs.normalizedShareToken ==
            other.routeArgs.normalizedShareToken &&
        routeArgs.entrySource == other.routeArgs.entrySource &&
        identical(audioControllerFactory, other.audioControllerFactory);
  }

  @override
  int get hashCode => Object.hash(
    routeArgs.normalizedSpaceId,
    routeArgs.normalizedActivityId,
    routeArgs.normalizedShareToken,
    routeArgs.entrySource,
    audioControllerFactory,
  );
}

/// Creates a per-route [PracticeSessionNotifier] backed by the Riverpod graph.
final practiceSessionNotifierProvider = ChangeNotifierProvider.autoDispose
    .family<PracticeSessionNotifier, PracticeSessionProviderArgs>((ref, args) {
      final repository = ref.watch(practiceRepositoryProvider).requireValue;
      final accountNotifier = ref.read(accountNotifierProvider);
      final routeArgs = args.routeArgs;
      return PracticeSessionNotifier(
        repository: repository,
        spaceId: routeArgs.spaceId,
        activityId: routeArgs.activityId,
        accessTokenLoader: () => accountNotifier.snapshot.session?.accessToken,
        audioController: args.audioControllerFactory?.call(),
      )..initialize();
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
      growthSnapshotLoader: () => gardenNotifier.snapshot,
      continuitySnapshotLoader: () =>
          continuityNotifier.hasResolvedRecommendation
          ? continuityNotifier.snapshot
          : null,
    );
  },
  // Declared so this provider can be re-created within nested ProviderScopes
  // that override the garden/continuity notifiers (e.g. the boot scope which
  // seeds the continuity notifier with a boot continuity snapshot).
  dependencies: [
    gardenGrowthNotifierProvider,
    practiceContinuityNotifierProvider,
  ],
);

// ---------------------------------------------------------------------------
// Reentry coordinators
// ---------------------------------------------------------------------------

/// Manages share deep-link reentry state. Non-autoDispose because it must
/// survive across route transitions and tab switches.
final shareReentryCoordinatorProvider =
    ChangeNotifierProvider<ShareReentryCoordinator>(
      (ref) => ShareReentryCoordinator(),
    );

/// Manages invite deep-link reentry state. Non-autoDispose because it must
/// survive across route transitions and tab switches.
final inviteReentryCoordinatorProvider =
    ChangeNotifierProvider<InviteReentryCoordinator>(
      (ref) => InviteReentryCoordinator(),
    );

// ---------------------------------------------------------------------------
// Default practice route args (from boot state)
// ---------------------------------------------------------------------------

/// Provides the default [PracticeRouteArgs] resolved from boot state.
///
/// Must be overridden at startup with the primarySpaceId and primaryActivityId
/// from [AppBootState].
final defaultPracticeRouteArgsProvider = Provider<PracticeRouteArgs>((ref) {
  throw UnimplementedError(
    'defaultPracticeRouteArgsProvider must be overridden at startup with '
    'primarySpaceId and primaryActivityId from AppBootState.',
  );
});

// ---------------------------------------------------------------------------
// Settings repository
// ---------------------------------------------------------------------------

final settingsRepositoryProvider = FutureProvider<SettingsRepository>((
  ref,
) async {
  final directory = await ref.watch(appDirectoryProvider.future);
  final localDataSource = await SettingsLocalDataSource.open(
    directory: directory.path,
  );
  return SettingsRepository(localDataSource: localDataSource);
});

// ---------------------------------------------------------------------------
// Settings notifier
// ---------------------------------------------------------------------------

/// Creates a [SettingsNotifier] backed by the Riverpod provider graph.
///
/// Non-autoDispose because settings state is read by multiple screens (shell,
/// home, practice) and must persist across tab switches.
final settingsNotifierProvider = ChangeNotifierProvider<SettingsNotifier>((
  ref,
) {
  final repository = ref.watch(settingsRepositoryProvider).requireValue;
  final accountNotifier = ref.watch(accountNotifierProvider);
  final babyProfileRepository = ref.watch(babyProfileRepositoryProvider);
  return SettingsNotifier(
    repository: repository,
    reminderScheduler: const PlatformReminderScheduler(),
    babyProfileRepository: babyProfileRepository,
    accountStateListenable: accountNotifier,
  )..initialize();
});
