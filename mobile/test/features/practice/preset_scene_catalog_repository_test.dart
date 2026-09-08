import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
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
      tempDir = await Directory.systemTemp.createTemp(
        'preset_catalog_repository_',
      );
      store = PresetSceneCatalogStore(directoryResolver: () async => tempDir);
      assets = AssetPhraseService(bundle: rootBundle);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns remote success and persists it as last-good cache', () async {
      final remote = _RemoteApi(
        (_) async => <PresetSceneDefinition>[_definition('remote_scene')],
      );
      final repository = _repository(
        remote: remote,
        store: store,
        assets: assets,
      );

      final snapshot = await repository.loadCatalog();

      expect(snapshot.source, PresetSceneCatalogSource.remote);
      expect(snapshot.scenes.single.presetSceneId, 'remote_scene');
      expect((await store.read())!.scenes.single.presetSceneId, 'remote_scene');
    });

    test('falls back to last-good cache after remote failure', () async {
      await store.write(
        PresetSceneCatalogSnapshot(
          source: PresetSceneCatalogSource.remote,
          scenes: <PresetSceneDefinition>[_definition('cached_scene')],
        ),
      );
      final repository = _repository(
        remote: _RemoteApi(
          (_) async => throw const PresetSceneCatalogApiException.network(),
        ),
        store: store,
        assets: assets,
      );

      final snapshot = await repository.loadCatalog();

      expect(snapshot.source, PresetSceneCatalogSource.cache);
      expect(snapshot.scenes.single.presetSceneId, 'cached_scene');
    });

    test(
      'quarantines malformed cache then falls back to all five bundled scenes',
      () async {
        await File(
          '${tempDir.path}/preset_scene_catalog.json',
        ).writeAsString('malformed');
        final repository = _repository(
          remote: _RemoteApi(
            (_) async => throw const PresetSceneCatalogApiException.network(),
          ),
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
          tempDir.listSync().whereType<File>().any(
            (file) => file.path.contains('.quarantine.'),
          ),
          isTrue,
        );
      },
    );

    test('first-install offline returns bundled scenes', () async {
      final repository = _repository(
        remote: _RemoteApi(
          (_) async => throw const PresetSceneCatalogApiException.network(),
        ),
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
        remote: _RemoteApi(
          (_) async => throw const PresetSceneCatalogApiException.network(),
        ),
        store: store,
        assets: assets,
      );
      final cachedSnapshot = await offlineRepository.loadCatalog();
      expect(cachedSnapshot.source, PresetSceneCatalogSource.cache);
      expect(cachedSnapshot.scenes, isEmpty);
    });

    test(
      'cache write failure does not discard a valid remote result',
      () async {
        final failingStore = _FailingStore(
          directoryResolver: () async => tempDir,
        );
        final repository = _repository(
          remote: _RemoteApi(
            (_) async => <PresetSceneDefinition>[_definition('remote_scene')],
          ),
          store: failingStore,
          assets: assets,
        );

        final snapshot = await repository.loadCatalog();

        expect(snapshot.source, PresetSceneCatalogSource.remote);
        expect(snapshot.scenes.single.presetSceneId, 'remote_scene');
      },
    );

    test(
      'cache write failure preserves the previous last-good snapshot',
      () async {
        await store.write(
          PresetSceneCatalogSnapshot(
            source: PresetSceneCatalogSource.remote,
            scenes: <PresetSceneDefinition>[_definition('old_scene')],
          ),
        );
        final failingStore = _FailOnceStore(
          directoryResolver: () async => tempDir,
        );
        final repository = _repository(
          remote: _RemoteApi(
            (_) async => <PresetSceneDefinition>[_definition('new_scene')],
          ),
          store: failingStore,
          assets: assets,
        );

        final snapshot = await repository.loadCatalog();

        expect(snapshot.source, PresetSceneCatalogSource.remote);
        expect(snapshot.scenes.single.presetSceneId, 'new_scene');
        expect((await store.read())!.scenes.single.presetSceneId, 'old_scene');
      },
    );

    test(
      'single-flights initial load, reuses memory, and refreshes explicitly',
      () async {
        final api = _QueuedRemoteApi();
        final first = Completer<List<PresetSceneDefinition>>();
        api.enqueue(first.future);
        final repository = _repository(
          remote: api,
          store: store,
          assets: assets,
          remoteTimeout: const Duration(seconds: 1),
        );

        final firstLoad = repository.loadCatalog();
        final joinedLoad = repository.loadCatalog();
        expect(api.calls, 1);
        first.complete(<PresetSceneDefinition>[_definition('first_scene')]);
        expect((await firstLoad).scenes.single.presetSceneId, 'first_scene');
        expect((await joinedLoad).scenes.single.presetSceneId, 'first_scene');
        expect(
          (await repository.loadCatalog()).scenes.single.presetSceneId,
          'first_scene',
        );
        expect(api.calls, 1);

        final refreshed = Completer<List<PresetSceneDefinition>>();
        api.enqueue(refreshed.future);
        final refresh = repository.refreshCatalog();
        expect(api.calls, 2);
        refreshed.complete(<PresetSceneDefinition>[
          _definition('second_scene'),
        ]);
        expect((await refresh).scenes.single.presetSceneId, 'second_scene');
        expect(
          (await repository.loadCatalog()).scenes.single.presetSceneId,
          'second_scene',
        );
        expect(api.calls, 2);
      },
    );

    test(
      'refresh joins an in-flight initial load instead of issuing a second request',
      () async {
        final api = _QueuedRemoteApi();
        final pending = Completer<List<PresetSceneDefinition>>();
        api.enqueue(pending.future);
        final repository = _repository(
          remote: api,
          store: store,
          assets: assets,
          remoteTimeout: const Duration(seconds: 1),
        );

        final initial = repository.loadCatalog();
        final refresh = repository.refreshCatalog();
        expect(api.calls, 1);
        pending.complete(<PresetSceneDefinition>[_definition('joined_scene')]);

        expect((await initial).scenes.single.presetSceneId, 'joined_scene');
        expect((await refresh).scenes.single.presetSceneId, 'joined_scene');
        expect(api.calls, 1);
      },
    );

    test(
      'times out a never-completing remote attempt before the boot gate and ignores late response',
      () async {
        final api = PresetSceneCatalogApi(
          dio: Dio(BaseOptions(baseUrl: 'http://catalog.test'))
            ..httpClientAdapter = _NeverCompletingDioAdapter(),
        );
        final repository = _repository(
          remote: api,
          store: store,
          assets: assets,
          remoteTimeout: const Duration(milliseconds: 50),
        );
        final stopwatch = Stopwatch()..start();

        final snapshot = await repository.loadCatalog();
        stopwatch.stop();

        expect(snapshot.source, PresetSceneCatalogSource.bundled);
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
        expect(await store.read(), isNull);
      },
    );

    test(
      'late response from timed-out attempt cannot overwrite a newer empty refresh',
      () async {
        final api = _QueuedRemoteApi();
        final stale = Completer<List<PresetSceneDefinition>>();
        api.enqueue(stale.future);
        final repository = _repository(
          remote: api,
          store: store,
          assets: assets,
          remoteTimeout: const Duration(milliseconds: 40),
        );

        final fallback = await repository.loadCatalog();
        expect(fallback.source, PresetSceneCatalogSource.bundled);
        final refreshResult = Completer<List<PresetSceneDefinition>>();
        api.enqueue(refreshResult.future);
        final refresh = repository.refreshCatalog();
        refreshResult.complete(const <PresetSceneDefinition>[]);
        expect((await refresh).source, PresetSceneCatalogSource.remote);
        expect((await refresh).scenes, isEmpty);

        stale.complete(<PresetSceneDefinition>[_definition('stale_scene')]);
        await Future<void>.delayed(Duration.zero);
        expect((await store.read())!.scenes, isEmpty);
        expect((await repository.loadCatalog()).scenes, isEmpty);
      },
    );
  });
}

PresetSceneCatalogRepository _repository({
  required PresetSceneCatalogApi remote,
  required PresetSceneCatalogStore store,
  required AssetPhraseService assets,
  Duration remoteTimeout = const Duration(seconds: 3),
}) {
  return PresetSceneCatalogRepository(
    api: remote,
    store: store,
    assetPhraseService: assets,
    remoteTimeout: remoteTimeout,
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

class _QueuedRemoteApi extends PresetSceneCatalogApi {
  final List<Future<List<PresetSceneDefinition>>> _responses = [];
  int calls = 0;

  void enqueue(Future<List<PresetSceneDefinition>> response) {
    _responses.add(response);
  }

  @override
  Future<List<PresetSceneDefinition>> fetchPublishedScenes() {
    calls += 1;
    if (_responses.isEmpty) {
      throw StateError('test response queue is empty');
    }
    return _responses.removeAt(0);
  }
}

class _NeverCompletingDioAdapter implements HttpClientAdapter {
  final Completer<ResponseBody> _response = Completer<ResponseBody>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _response.future;

  @override
  void close({bool force = false}) {}
}

class _FailOnceStore extends PresetSceneCatalogStore {
  _FailOnceStore({required super.directoryResolver});

  bool shouldFail = true;

  @override
  Future<void> write(PresetSceneCatalogSnapshot snapshot) {
    if (shouldFail) {
      shouldFail = false;
      return Future<void>.error(const PresetSceneCatalogStoreException());
    }
    return super.write(snapshot);
  }
}

class _FailingStore extends PresetSceneCatalogStore {
  _FailingStore({required super.directoryResolver});

  @override
  Future<void> write(PresetSceneCatalogSnapshot snapshot) async {
    throw const PresetSceneCatalogStoreException();
  }
}
