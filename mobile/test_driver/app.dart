import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/app.dart';
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

  runApp(
    ProviderScope(
      child: BabyTalkApp(
        bootState: bootState,
        repositoryFactory: (assetPhraseService) => _openPracticeRepository(
          assetPhraseService: assetPhraseService,
          directory: tempDir,
          runId: runId,
        ),
        accountRepositoryFactory: (practiceRepository, directory) async {
          return AccountRepository(
            localStore: AccountLocalStore(storageKey: 'driver_account_$runId'),
            practiceRepository: practiceRepository,
          );
        },
        householdRepositoryFactory: (accountRepository, directory) async {
          return HouseholdRepository(
            localStore: HouseholdLocalStore(
              directoryResolver: () async => directory,
            ),
            apiService: HouseholdApiService(),
            accountSnapshotLoader: accountRepository.loadSnapshot,
            persistRefreshedSession: accountRepository.persistRefreshedSession,
          );
        },
        appDirectoryResolver: () async => tempDir,
        audioControllerFactory: _SilentPracticeAudioController.new,
      ),
    ),
  );
}

Future<PracticeRepository> _openPracticeRepository({
  required AssetPhraseService assetPhraseService,
  required Directory directory,
  required String runId,
}) async {
  final localDataSource = await PracticeLocalDataSource.open(
    directory: directory.path,
    name: 'practice_driver_$runId',
  );
  return PracticeRepository(
    assetPhraseService: assetPhraseService,
    localDataSource: localDataSource,
    installationIdService: InstallationIdService(
      directoryResolver: () async => directory,
      idGenerator: () => 'install_driver_$runId',
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
