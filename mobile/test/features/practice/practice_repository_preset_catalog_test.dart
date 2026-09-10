import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/local/preset_scene_catalog_store.dart';
import 'package:mobile/features/practice/data/remote/preset_scene_catalog_api.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/repositories/preset_scene_catalog_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/preset_scene_definition.dart';
import '../../support/isar_test_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): resolveBundledIsarLibraryPath()},
    );
  });

  test(
    'uses published metadata and preserves remote order while merging seed fallback phrases',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'practice_preset_catalog_',
      );
      final dbName = 'practice_${DateTime.now().microsecondsSinceEpoch}';
      final localDataSource = await PracticeLocalDataSource.open(
        directory: tempDir.path,
        name: dbName,
      );
      try {
        final remoteScenes = <PresetSceneDefinition>[
          _definition('remote_only', spaceId: 'remote_space'),
          _definition(
            'bath_time',
            spaceId: 'daily_care',
            title: 'Published bath title',
            summary: 'Published bath summary',
            sceneTag: 'published-bath',
            coachTip: 'Published bath tip',
            sortOrder: 1,
          ),
          _definition('bedtime', spaceId: 'family_rhythm', sortOrder: 0),
        ];
        final store = PresetSceneCatalogStore(
          directoryResolver: () async => tempDir,
        );
        final catalogRepository = PresetSceneCatalogRepository(
          api: _RemoteApi(remoteScenes),
          store: store,
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
        );
        final repository = PracticeRepository(
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
          localDataSource: localDataSource,
          installationIdService: InstallationIdService(
            directoryResolver: () async => tempDir,
            idGenerator: () => 'install_test',
          ),
          presetSceneCatalogRepository: catalogRepository,
        );

        final catalog = await repository.getActivityCatalog();
        final remoteOnly = catalog.activities.first;
        final bath = catalog.activities[1];

        expect(catalog.activities.map((activity) => activity.activityId), [
          'remote_only',
          'bath_time',
          'bedtime',
        ]);
        expect(remoteOnly.title, 'Remote title');
        expect(remoteOnly.totalPhraseCount, 0);
        expect(bath.title, 'Published bath title');
        expect(bath.summary, 'Published bath summary');
        expect(bath.sceneTag, 'published-bath');
        expect(bath.coachTip, 'Published bath tip');
        expect(bath.totalPhraseCount, 3);
        expect(bath.nextPhraseEnglish, 'Warm water.');

        final snapshot = await repository.getActivitySnapshot(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        );
        expect(snapshot.title, 'Published bath title');
        expect(snapshot.phrases, hasLength(3));
        expect(snapshot.phrases.first.english, 'Warm water.');

        final remoteOnlySnapshot = await repository.getActivitySnapshot(
          spaceId: 'remote_space',
          activityId: 'remote_only',
        );
        expect(remoteOnlySnapshot.title, 'Remote title');
        expect(remoteOnlySnapshot.phrases, isEmpty);
      } finally {
        await localDataSource.close(deleteFromDisk: true);
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    },
  );

  test('published empty catalog does not resurrect bundled scenes', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'practice_preset_empty_',
    );
    final localDataSource = await PracticeLocalDataSource.open(
      directory: tempDir.path,
      name: 'practice_${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      final repository = PracticeRepository(
        assetPhraseService: AssetPhraseService(bundle: rootBundle),
        localDataSource: localDataSource,
        installationIdService: InstallationIdService(
          directoryResolver: () async => tempDir,
          idGenerator: () => 'install_test',
        ),
        presetSceneCatalogRepository: PresetSceneCatalogRepository(
          api: _RemoteApi(const <PresetSceneDefinition>[]),
          store: PresetSceneCatalogStore(
            directoryResolver: () async => tempDir,
          ),
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
        ),
      );

      final catalog = await repository.getActivityCatalog();

      expect(catalog.activities, isEmpty);
      expect(catalog.spaces, isEmpty);
    } finally {
      await localDataSource.close(deleteFromDisk: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}

PresetSceneDefinition _definition(
  String id, {
  required String spaceId,
  String title = 'Remote title',
  String summary = 'Remote summary',
  String sceneTag = 'Remote tag',
  String coachTip = 'Remote tip',
  int sortOrder = 1,
}) {
  return PresetSceneDefinition(
    presetSceneId: id,
    publishedVersion: 1,
    spaceId: spaceId,
    title: title,
    summary: summary,
    sceneTag: sceneTag,
    coachTip: coachTip,
    sortOrder: sortOrder,
  );
}

class _RemoteApi extends PresetSceneCatalogApi {
  _RemoteApi(this.scenes);

  final List<PresetSceneDefinition> scenes;

  @override
  Future<List<PresetSceneDefinition>> fetchPublishedScenes() async => scenes;
}
