import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mobile/features/practice/data/local/preset_scene_catalog_store.dart';
import 'package:mobile/features/practice/data/remote/preset_scene_catalog_api.dart';
import 'package:mobile/features/practice/data/repositories/preset_scene_catalog_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/preset_scene_definition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PresetSceneCatalogRepository', () {
    late Directory tempDir;
    late PresetSceneCatalogStore store;
    late AssetPhraseService assets;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('preset_catalog_repository_');
      store = PresetSceneCatalogStore(directoryResolver: () async => tempDir);
      assets = AssetPhraseService(bundle: rootBundle);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns remote success and persists it as last-good cache', () async {
      final remote = _RemoteApi((_) async => <PresetSceneDefinition>[
        _definition('remote_scene'),
      ]);
      final repository = _repository(remote: remote, store: store, assets: assets);

      final snapshot = await repository.loadCatalog();

      expect(snapshot.source, PresetSceneCatalogSource.remote);
      expect(snapshot.scenes.single.presetSceneId, 'remote_scene');
      expect((await store.read())!.scenes.single.presetSceneId, 'remote_scene');
    });

    test('falls back to last-good cache after remote failure', () async {
      await store.write(PresetSceneCatalogSnapshot(
        source: PresetSceneCatalogSource.remote,
        scenes: <PresetSceneDefinition>[_definition('cached_scene')],
      ));
      final repository = _repository(
        remote: _RemoteApi((_) async => throw const PresetSceneCatalogApiException.network()),
        store: store,
        assets: assets,
      );

      final snapshot = await repository.loadCatalog();

      expect(snapshot.source, PresetSceneCatalogSource.cache);
      expect(snapshot.scenes.single.presetSceneId, 'cached_scene');
    });

    test('quarantines malformed cache then falls back to all five bundled scenes', () async {
      await File('${tempDir.path}/preset_scene_catalog.json').writeAsString('malformed');
      final repository = _repository(
        remote: _RemoteApi((_) async => throw const PresetSceneCatalogApiException.network()),
        store: store,
        assets: assets,
      );

      final snapshot = await repository.loadCatalog();

      expect(snapshot.source, PresetSceneCatalogSource.bundled);
      expect(snapshot.scenes, hasLength(5));
      expect(snapshot.scenes.map((scene) => scene.presetSceneId), [
        'bath_time',
        'diaper_change',
        'post_cry_soothing',
        'feeding_time',
        'bedtime',
      ]);
      expect(
        tempDir.listSync().whereType<File>().any((file) => file.path.contains('.quarantine.')),
        isTrue,
      );
    });

    test('first-install offline returns bundled scenes', () async {
      final repository = _repository(
        remote: _RemoteApi((_) async => throw const PresetSceneCatalogApiException.network()),
        store: store,
        assets: assets,
      );

      final snapshot = await repository.loadCatalog();

      expect(snapshot.source, PresetSceneCatalogSource.bundled);
      expect(snapshot.scenes, hasLength(5));
    });

    test('remote empty is authoritative and remains empty offline', () async {
      final repository = _repository(
        remote: _RemoteApi((_) async => const <PresetSceneDefinition>[]),
        store: store,
        assets: assets,
      );

      final remoteSnapshot = await repository.loadCatalog();
      expect(remoteSnapshot.source, PresetSceneCatalogSource.remote);
      expect(remoteSnapshot.scenes, isEmpty);

      final offlineRepository = _repository(
        remote: _RemoteApi((_) async => throw const PresetSceneCatalogApiException.network()),
        store: store,
        assets: assets,
      );
      final cachedSnapshot = await offlineRepository.loadCatalog();
      expect(cachedSnapshot.source, PresetSceneCatalogSource.cache);
      expect(cachedSnapshot.scenes, isEmpty);
    });

    test('cache write failure does not discard a valid remote result', () async {
      final failingStore = _FailingStore(directoryResolver: () async => tempDir);
      final repository = _repository(
        remote: _RemoteApi((_) async => <PresetSceneDefinition>[_definition('remote_scene')]),
        store: failingStore,
        assets: assets,
      );

      final snapshot = await repository.loadCatalog();

      expect(snapshot.source, PresetSceneCatalogSource.remote);
      expect(snapshot.scenes.single.presetSceneId, 'remote_scene');
    });
  });
}

PresetSceneCatalogRepository _repository({
  required PresetSceneCatalogApi remote,
  required PresetSceneCatalogStore store,
  required AssetPhraseService assets,
}) {
  return PresetSceneCatalogRepository(
    api: remote,
    store: store,
    assetPhraseService: assets,
  );
}

PresetSceneDefinition _definition(String id) {
  return PresetSceneDefinition(
    presetSceneId: id,
    publishedVersion: 1,
    spaceId: 'remote_space',
    title: 'Remote title',
    summary: 'Remote summary',
    sceneTag: 'Remote tag',
    coachTip: 'Remote tip',
    sortOrder: 1,
  );
}

class _RemoteApi extends PresetSceneCatalogApi {
  _RemoteApi(this.loader);

  final Future<List<PresetSceneDefinition>> Function(String) loader;

  @override
  Future<List<PresetSceneDefinition>> fetchPublishedScenes() => loader('');
}

class _FailingStore extends PresetSceneCatalogStore {
  _FailingStore({required super.directoryResolver});

  @override
  Future<void> write(PresetSceneCatalogSnapshot snapshot) async {
    throw const PresetSceneCatalogStoreException();
  }
}
