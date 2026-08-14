import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mobile/features/care_entry/data/bundled_care_entry_fallback_catalog.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';

final class BundledCareEntryRegistry implements CareEntryRegistry {
  BundledCareEntryRegistry({
    required AssetBundle bundle,
    this.manifestAssetPath = 'assets/content/care_entry_registry.json',
    CareEntryFallbackCatalog? catalog,
  }) : _bundle = bundle,
       _catalog = catalog ?? BundledCareEntryFallbackCatalog(bundle: bundle);

  static const int supportedSchemaVersion = 1;
  final AssetBundle _bundle;
  final CareEntryFallbackCatalog _catalog;
  final String manifestAssetPath;
  Future<_ValidatedManifest>? _cachedManifest;

  @override
  Future<CareEntryResolution> resolve({
    required CareEntryPlacementId placement,
    required int visibleSlots,
    required DateTime localTime,
  }) async {
    if (visibleSlots <= 0) {
      throw ArgumentError.value(visibleSlots, 'visibleSlots', '必须大于零。');
    }
    final manifest = await (_cachedManifest ??= _loadAndValidate());
    final collection = manifest.collections[placement];
    if (collection == null) {
      throw FormatException('未知 Care Entry placement: ${placement.value}');
    }
    if (collection.visibleSlots != visibleSlots) {
      throw FormatException(
        'placement ${placement.value} 必须解析 ${collection.visibleSlots} 个入口。',
      );
    }

    final selected = <_ManifestEntry>[];
    for (final id in collection.entryIds) {
      final entry = manifest.entries[id];
      if (entry != null && entry.placement == placement) {
        selected.add(entry);
      }
    }
    for (final id in collection.safeDefaultEntryIds) {
      if (selected.length >= visibleSlots) break;
      final entry = manifest.entries[id];
      if (entry != null &&
          entry.placement == placement &&
          selected.every((candidate) => candidate.id != entry.id)) {
        selected.add(entry);
      }
    }
    if (selected.length < visibleSlots) {
      throw FormatException('placement ${placement.value} 缺少足够的安全入口。');
    }

    final ordered = selected.take(visibleSlots).toList(growable: false)
      ..sort((left, right) => left.order.compareTo(right.order));
    final recommendations = ordered
        .where((entry) => entry.recommendationHours.contains(localTime.hour))
        .toList(growable: false);
    if (recommendations.length > 1) {
      throw FormatException('placement ${placement.value} 在同一时刻只能推荐一个入口。');
    }
    final recommendedId = recommendations.firstOrNull?.id;
    return CareEntryResolution(
      schemaVersion: manifest.schemaVersion,
      revision: manifest.revision,
      placement: placement,
      entries: ordered
          .map(
            (entry) => entry.resolved.copyWithRecommendation(
              entry.id == recommendedId,
            ),
          )
          .toList(growable: false),
      recommendedEntryId: recommendedId,
    );
  }

  Future<_ValidatedManifest> _loadAndValidate() async {
    final rawJson = await _bundle.loadString(manifestAssetPath);
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Care Entry manifest 顶层必须是对象。');
    }
    final schemaVersion = _requiredInt(decoded, 'schemaVersion');
    if (schemaVersion != supportedSchemaVersion) {
      throw FormatException('不支持的 Care Entry schemaVersion: $schemaVersion');
    }
    final revision = _requiredString(decoded, 'revision');
    final rawEntries = _requiredList(decoded, 'entries');
    final entries = <CareEntryId, _ManifestEntry>{};
    final ordersByPlacement = <CareEntryPlacementId, Set<int>>{};
    for (final rawEntry in rawEntries) {
      if (rawEntry is! Map<String, dynamic>) {
        throw const FormatException('Care Entry 必须是对象。');
      }
      final optional = rawEntry['optional'] == true;
      try {
        final entry = await _parseEntry(rawEntry);
        if (entries.containsKey(entry.id)) {
          throw FormatException('重复 Care Entry id: ${entry.id.value}');
        }
        final orders = ordersByPlacement.putIfAbsent(
          entry.placement,
          () => <int>{},
        );
        if (!orders.add(entry.order)) {
          throw FormatException(
            'placement ${entry.placement.value} 包含重复顺序 ${entry.order}。',
          );
        }
        entries[entry.id] = entry;
      } on Object {
        if (!optional) rethrow;
      }
    }

    final rawCollections = _requiredList(decoded, 'collections');
    final collections = <CareEntryPlacementId, _ManifestCollection>{};
    for (final rawCollection in rawCollections) {
      if (rawCollection is! Map<String, dynamic>) {
        throw const FormatException('Care Entry collection 必须是对象。');
      }
      final placement = CareEntryPlacementId(
        _requiredOpaqueId(rawCollection, 'placement'),
      );
      final collection = _ManifestCollection(
        visibleSlots: _requiredInt(rawCollection, 'visibleSlots'),
        entryIds: _requiredIdList(rawCollection, 'entryIds', 'care.'),
        safeDefaultEntryIds: _requiredIdList(
          rawCollection,
          'safeDefaultEntryIds',
          'care.',
        ),
      );
      if (collections.containsKey(placement)) {
        throw FormatException('重复 Care Entry placement: ${placement.value}');
      }
      if (collection.visibleSlots <= 0) {
        throw FormatException('placement ${placement.value} visibleSlots 非法。');
      }
      for (final fallbackId in collection.safeDefaultEntryIds) {
        if (!entries.containsKey(fallbackId)) {
          throw FormatException(
            'placement ${placement.value} 缺少安全默认入口 ${fallbackId.value}。',
          );
        }
      }
      collections[placement] = collection;
    }
    return _ValidatedManifest(
      schemaVersion: schemaVersion,
      revision: revision,
      entries: entries,
      collections: collections,
    );
  }

  Future<_ManifestEntry> _parseEntry(Map<String, dynamic> json) async {
    final id = CareEntryId(_requiredNamespacedId(json, 'id', 'care.'));
    final placement = CareEntryPlacementId(
      _requiredOpaqueId(json, 'placement'),
    );
    final order = _requiredInt(json, 'order');
    if (order <= 0) {
      throw FormatException('Care Entry ${id.value} order 必须大于零。');
    }
    final visualToken = _requiredString(json, 'visualToken');
    if (!_visualTokenPattern.hasMatch(visualToken)) {
      throw FormatException('Care Entry ${id.value} visualToken 不受支持。');
    }

    final generationJson = _requiredMap(json, 'generation');
    final generation = GenerationSceneRef(
      id: GenerationSceneId(
        _requiredNamespacedId(generationJson, 'id', 'generation.'),
      ),
      schemaVersion: _requiredInt(generationJson, 'schemaVersion'),
      sceneType: _requiredString(generationJson, 'sceneType'),
      parentTonePreference: _requiredString(
        generationJson,
        'parentTonePreference',
      ),
    );
    if (generation.schemaVersion != 1) {
      throw FormatException(
        'Care Entry ${id.value} generation schemaVersion 不受支持。',
      );
    }

    final fallbackJson = _requiredMap(json, 'fallback');
    final fallback = CatalogFallbackRef(
      id: CatalogFallbackId(
        _requiredNamespacedId(fallbackJson, 'id', 'fallback.'),
      ),
      spaceId: _requiredString(fallbackJson, 'spaceId'),
      activityId: _requiredString(fallbackJson, 'activityId'),
      phraseId: _requiredString(fallbackJson, 'phraseId'),
    );
    if (_requiredString(fallbackJson, 'audioReview') != 'reviewed') {
      throw FormatException('Care Entry ${id.value} 首句音频未审核。');
    }
    final firstUtterance = await _catalog.resolve(
      fallback,
      audioReview: AudioReview.reviewed,
    );
    final nextSupports = _parseNextSupports(json, entryId: id);

    final hours = _optionalIntList(json, 'recommendationHours');
    if (hours.any((hour) => hour < 0 || hour > 23) ||
        hours.toSet().length != hours.length) {
      throw FormatException('Care Entry ${id.value} recommendationHours 非法。');
    }
    return _ManifestEntry(
      id: id,
      placement: placement,
      order: order,
      recommendationHours: Set<int>.unmodifiable(hours),
      resolved: ResolvedCareEntry(
        id: id,
        title: _requiredString(json, 'title'),
        subtitle: _requiredString(json, 'subtitle'),
        visualToken: visualToken,
        order: order,
        seed: CareMomentSeed(
          generationRef: generation,
          fallback: fallback,
          firstUtterance: firstUtterance,
          nextSupports: nextSupports,
        ),
        isRecommended: false,
      ),
    );
  }

  CareLocalNextSupportSet _parseNextSupports(
    Map<String, dynamic> json, {
    required CareEntryId entryId,
  }) {
    final supportJson = _requiredMap(json, 'nextSupport');
    final absent = _parseSupport(
      _requiredMap(supportJson, 'absent'),
      entryId: entryId,
    );
    final reactionsJson = _requiredMap(supportJson, 'reactions');
    final byReaction = <CareReaction, CareNextSupportUtterance>{};
    for (final reaction in CareReaction.values) {
      byReaction[reaction] = _parseSupport(
        _requiredMap(reactionsJson, reaction.wireValue),
        entryId: entryId,
      );
    }
    final ids = <CareSupportId>{
      absent.id,
      ...byReaction.values.map((support) => support.id),
    };
    if (ids.length != CareReaction.values.length + 1) {
      throw FormatException(
        'Care Entry ${entryId.value} local next support identity 重复。',
      );
    }
    return CareLocalNextSupportSet(whenAbsent: absent, byReaction: byReaction);
  }

  CareNextSupportUtterance _parseSupport(
    Map<String, dynamic> json, {
    required CareEntryId entryId,
  }) {
    final id = CareSupportId(_requiredNamespacedId(json, 'id', 'support.'));
    return CareNextSupportUtterance(
      id: id,
      english: _requiredString(json, 'english'),
      chinese: _requiredString(json, 'chinese'),
    );
  }
}

final class _ValidatedManifest {
  const _ValidatedManifest({
    required this.schemaVersion,
    required this.revision,
    required this.entries,
    required this.collections,
  });

  final int schemaVersion;
  final String revision;
  final Map<CareEntryId, _ManifestEntry> entries;
  final Map<CareEntryPlacementId, _ManifestCollection> collections;
}

final class _ManifestCollection {
  const _ManifestCollection({
    required this.visibleSlots,
    required this.entryIds,
    required this.safeDefaultEntryIds,
  });

  final int visibleSlots;
  final List<CareEntryId> entryIds;
  final List<CareEntryId> safeDefaultEntryIds;
}

final class _ManifestEntry {
  const _ManifestEntry({
    required this.id,
    required this.placement,
    required this.order,
    required this.recommendationHours,
    required this.resolved,
  });

  final CareEntryId id;
  final CareEntryPlacementId placement;
  final int order;
  final Set<int> recommendationHours;
  final ResolvedCareEntry resolved;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('字段 `$key` 必须是非空字符串。');
  }
  return value.trim();
}

String _requiredNamespacedId(
  Map<String, dynamic> json,
  String key,
  String prefix,
) {
  final value = _requiredString(json, key);
  if (!value.startsWith(prefix) || value.length == prefix.length) {
    throw FormatException('字段 `$key` 必须使用 $prefix 命名空间。');
  }
  return value;
}

final RegExp _opaqueIdPattern = RegExp(
  r'^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$',
);
final RegExp _visualTokenPattern = RegExp(
  r'^route\.[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)*$',
);

String _requiredOpaqueId(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  if (!_opaqueIdPattern.hasMatch(value)) {
    throw FormatException('字段 `$key` 必须是 namespaced opaque ID。');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('字段 `$key` 必须是整数。');
  }
  return value;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('字段 `$key` 必须是对象。');
  }
  return value;
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('字段 `$key` 必须是列表。');
  }
  return value;
}

List<CareEntryId> _requiredIdList(
  Map<String, dynamic> json,
  String key,
  String prefix,
) {
  final values = _requiredList(json, key);
  if (values.any((value) => value is! String)) {
    throw FormatException('字段 `$key` 必须是字符串列表。');
  }
  final result = values
      .cast<String>()
      .map(
        (value) => CareEntryId(
          _requiredNamespacedId(<String, dynamic>{key: value}, key, prefix),
        ),
      )
      .toList(growable: false);
  if (result.toSet().length != result.length) {
    throw FormatException('字段 `$key` 不能包含重复值。');
  }
  return result;
}

List<int> _optionalIntList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const <int>[];
  if (value is! List || value.any((item) => item is! int)) {
    throw FormatException('字段 `$key` 必须是整数列表。');
  }
  return List<int>.unmodifiable(value.cast<int>());
}
