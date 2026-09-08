import 'dart:async';

import 'package:dio/dio.dart';
import 'package:mobile/features/practice/data/local/preset_scene_catalog_store.dart';
import 'package:mobile/features/practice/data/remote/preset_scene_catalog_api.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/preset_scene_definition.dart';

/// Resolves published preset metadata using remote, last-good cache, bundled
/// priority. A successful empty remote response is a valid authoritative
/// snapshot and is persisted exactly like a non-empty response.
class PresetSceneCatalogRepository {
  PresetSceneCatalogRepository({
    required PresetSceneCatalogApi api,
    required PresetSceneCatalogStore store,
    required AssetPhraseService assetPhraseService,
    this.remoteTimeout = const Duration(seconds: 3),
  }) : _api = api,
       _store = store,
       _assetPhraseService = assetPhraseService;

  final PresetSceneCatalogApi _api;
  final PresetSceneCatalogStore _store;
  final AssetPhraseService _assetPhraseService;
  final Duration remoteTimeout;
  PresetSceneCatalogSnapshot? _memorySnapshot;
  Future<PresetSceneCatalogSnapshot>? _inFlight;
  int _operationGeneration = 0;

  Future<PresetSceneCatalogSnapshot> loadCatalog() {
    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final memorySnapshot = _memorySnapshot;
    if (memorySnapshot != null) {
      return Future<PresetSceneCatalogSnapshot>.value(memorySnapshot);
    }
    return _startLoad();
  }

  /// Explicitly refreshes the catalog. A refresh requested during an existing
  /// load joins that load, avoiding competing requests and stale writes.
  Future<PresetSceneCatalogSnapshot> refreshCatalog() {
    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }
    return _startLoad();
  }

  Future<PresetSceneCatalogSnapshot> _startLoad() {
    final generation = ++_operationGeneration;
    final cancelToken = CancelToken();
    final operation = _loadCatalog(
      generation: generation,
      cancelToken: cancelToken,
    );
    _inFlight = operation;
    operation.then<void>(
      (_) => _clearInFlight(operation),
      onError: (Object error, StackTrace stackTrace) =>
          _clearInFlight(operation),
    );
    return operation;
  }

  void _clearInFlight(Future<PresetSceneCatalogSnapshot> operation) {
    if (identical(_inFlight, operation)) {
      _inFlight = null;
    }
  }

  Future<PresetSceneCatalogSnapshot> _loadCatalog({
    required int generation,
    required CancelToken cancelToken,
  }) async {
    try {
      final remoteScenes = await _api
          .fetchPublishedScenesWithCancellation(cancelToken: cancelToken)
          .timeout(remoteTimeout);
      // Validate again at repository boundary so a test/platform adapter that
      // bypasses the concrete API cannot poison the last-good cache.
      final validatedScenes = PresetSceneDefinition.parseList(
        remoteScenes.map((scene) => scene.toJsonMap()).toList(growable: false),
      );
      final remoteSnapshot = PresetSceneCatalogSnapshot(
        source: PresetSceneCatalogSource.remote,
        scenes: validatedScenes,
      );
      if (_isCurrent(generation)) {
        try {
          await _store.write(remoteSnapshot);
        } on Object {
          // A valid remote catalog remains usable when persistence is degraded.
        }
        if (_isCurrent(generation)) {
          _memorySnapshot = remoteSnapshot;
        }
      }
      return remoteSnapshot;
    } on TimeoutException {
      cancelToken.cancel('preset scene catalog remote timeout');
      return _loadFallback(generation);
    } on Object {
      return _loadFallback(generation);
    }
  }

  Future<PresetSceneCatalogSnapshot> _loadFallback(int generation) async {
    final cached = await _readCachedSnapshot();
    final snapshot =
        cached ??
        PresetSceneCatalogSnapshot(
          source: PresetSceneCatalogSource.bundled,
          scenes: await _assetPhraseService.loadBundledPresetScenes(),
        );
    if (_isCurrent(generation)) {
      _memorySnapshot = snapshot;
    }
    return snapshot;
  }

  bool _isCurrent(int generation) => generation == _operationGeneration;

  Future<PresetSceneCatalogSnapshot?> _readCachedSnapshot() async {
    try {
      final result = await _store.readResult();
      if (result.status != PresetSceneCatalogStoreReadStatus.available) {
        return null;
      }
      return result.snapshot;
    } on Object {
      return null;
    }
  }
}
