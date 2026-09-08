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
  }) : _api = api,
       _store = store,
       _assetPhraseService = assetPhraseService;

  final PresetSceneCatalogApi _api;
  final PresetSceneCatalogStore _store;
  final AssetPhraseService _assetPhraseService;

  Future<PresetSceneCatalogSnapshot> loadCatalog() async {
    try {
      final remoteScenes = await _api.fetchPublishedScenes();
      // Validate again at repository boundary so a test/platform adapter that
      // bypasses the concrete API cannot poison the last-good cache.
      final validatedScenes = PresetSceneDefinition.parseList(
        remoteScenes.map((scene) => scene.toJsonMap()).toList(growable: false),
      );
      final remoteSnapshot = PresetSceneCatalogSnapshot(
        source: PresetSceneCatalogSource.remote,
        scenes: validatedScenes,
      );
      try {
        await _store.write(remoteSnapshot);
      } on Object {
        // A valid remote catalog remains usable when persistence is degraded.
      }
      return remoteSnapshot;
    } on Object {
      final cached = await _readCachedSnapshot();
      if (cached != null) {
        return cached;
      }
      final bundledScenes = await _assetPhraseService.loadBundledPresetScenes();
      return PresetSceneCatalogSnapshot(
        source: PresetSceneCatalogSource.bundled,
        scenes: bundledScenes,
      );
    }
  }

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
