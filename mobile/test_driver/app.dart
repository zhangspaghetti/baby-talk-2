import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/data/services/household_api_service.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';

Future<void> main() async {
  enableFlutterDriverExtension();
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  final runId = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
  final tempDir = await Directory.systemTemp.createTemp(
    'baby_talk_driver_$runId',
  );
  final bootState = await AppBootState.load(rootBundle);

  final localDataSource = await PracticeLocalDataSource.open(
    directory: tempDir.path,
    name: 'practice_driver_$runId',
  );
  final practiceRepository = PracticeRepository(
    assetPhraseService: bootState.assetPhraseService!,
    localDataSource: localDataSource,
    installationIdService: InstallationIdService(
      directoryResolver: () async => tempDir,
      idGenerator: () => 'install_driver_$runId',
    ),
  );
  final accountRepository = AccountRepository(
    localStore: AccountLocalStore(storageKey: 'driver_account_$runId'),
    practiceRepository: practiceRepository,
  );
  final householdRepository = HouseholdRepository(
    localStore: HouseholdLocalStore(
      directoryResolver: () async => tempDir,
    ),
    apiService: HouseholdApiService(),
    accountSnapshotLoader: accountRepository.loadSnapshot,
    persistRefreshedSession: accountRepository.persistRefreshedSession,
  );

  runApp(
    ProviderScope(
      overrides: [
        assetPhraseServiceProvider.overrideWithValue(
          bootState.assetPhraseService!,
        ),
        appDirectoryProvider.overrideWith((ref) => tempDir),
        practiceRepositoryProvider.overrideWith(
          (ref) => practiceRepository,
        ),
        accountRepositoryProvider.overrideWith(
          (ref) => accountRepository,
        ),
        householdRepositoryProvider.overrideWith(
          (ref) => householdRepository,
        ),
      ],
      child: BabyTalkApp(
        bootState: bootState,
        audioControllerFactory: _SilentPracticeAudioController.new,
      ),
    ),
  );
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
