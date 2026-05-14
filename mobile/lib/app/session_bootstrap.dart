import 'dart:io';

import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';

/// SessionBootstrap 负责创建所有 repositories 和 API services。
///
/// 职责：
/// - 创建 PracticeRepository
/// - 创建 AccountRepository + API services
/// - 创建 HouseholdRepository
/// - 创建 MentorRepository
/// - 创建 OnboardingRepository
class SessionBootstrap {
  const SessionBootstrap({
    required this.practiceRepository,
    required this.onboardingRepository,
    required this.accountRepository,
    required this.householdRepository,
    required this.mentorRepository,
  });

  final PracticeRepository practiceRepository;
  final OnboardingRepository onboardingRepository;
  final AccountRepository accountRepository;
  final HouseholdRepository householdRepository;
  final MentorRepository mentorRepository;

  /// 从 AppBootState 创建完整的 session bootstrap。
  static Future<SessionBootstrap> create({
    required AssetPhraseService assetPhraseService,
    required String primarySpaceId,
    required String primaryActivityId,
    Future<PracticeRepository> Function(AssetPhraseService)? repositoryFactory,
    Future<AccountRepository> Function(PracticeRepository, Directory)? accountRepositoryFactory,
    Future<HouseholdRepository> Function(AccountRepository, Directory)? householdRepositoryFactory,
    Future<Directory> Function()? appDirectoryResolver,
  }) async {
    final directory = appDirectoryResolver != null
        ? await appDirectoryResolver()
        : await _defaultDirectory();

    final factory = repositoryFactory ?? _defaultRepositoryFactory;
    final practiceRepository = await factory(assetPhraseService);

    final onboardingStore = OnboardingSnapshotStore(
      directoryResolver: () async => directory,
    );
    final onboardingRepository = OnboardingRepository(
      snapshotStore: onboardingStore,
      practiceRepository: practiceRepository,
      starterSpaceId: primarySpaceId,
      starterActivityId: primaryActivityId,
    );

    final accountFactory = accountRepositoryFactory ?? _defaultAccountRepositoryFactory;
    final accountRepository = await accountFactory(practiceRepository, directory);

    final householdFactory = householdRepositoryFactory ?? _defaultHouseholdRepositoryFactory;
    final householdRepository = await householdFactory(accountRepository, directory);

    final mentorRepository = MentorRepository(
      localDataSource: await MentorLocalDataSource.open(directory: directory.path),
      practiceRepository: practiceRepository,
      onboardingSnapshotStore: onboardingStore,
      householdSnapshotLoader: householdRepository.loadSnapshot,
    );

    return SessionBootstrap(
      practiceRepository: practiceRepository,
      onboardingRepository: onboardingRepository,
      accountRepository: accountRepository,
      householdRepository: householdRepository,
      mentorRepository: mentorRepository,
    );
  }

  void close() {
    // repositories handle their own cleanup
  }
}

Future<Directory> _defaultDirectory() async {
  return Directory.systemTemp;
}

Future<PracticeRepository> _defaultRepositoryFactory(AssetPhraseService service) async {
  throw UnimplementedError('Default repository factory not configured');
}

Future<AccountRepository> _defaultAccountRepositoryFactory(
  PracticeRepository practiceRepo,
  Directory directory,
) async {
  throw UnimplementedError('Default account repository factory not configured');
}

Future<HouseholdRepository> _defaultHouseholdRepositoryFactory(
  AccountRepository accountRepo,
  Directory directory,
) async {
  throw UnimplementedError('Default household repository factory not configured');
}
