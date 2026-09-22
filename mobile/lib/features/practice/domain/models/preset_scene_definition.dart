enum PresetSceneCatalogSource { remote, cache, bundled }

/// Published, public metadata for one preset practice scene.
///
/// The generation brief intentionally does not belong to this model. It is
/// server-only data and must never cross the mobile catalog boundary.
class PresetSceneDefinition {
  factory PresetSceneDefinition({
    required String presetSceneId,
    required int publishedVersion,
    required String spaceId,
    required String title,
    required String summary,
    required String sceneTag,
    required String coachTip,
    required int sortOrder,
  }) {
    return PresetSceneDefinition._(
      presetSceneId: _requireSafeIdentifier(presetSceneId, 'presetSceneId'),
      publishedVersion: _requirePositiveVersion(publishedVersion),
      spaceId: _requireSafeIdentifier(spaceId, 'spaceId'),
      title: _requireNonEmptyText(title, 'title'),
      summary: _requireNonEmptyText(summary, 'summary'),
      sceneTag: _requireNonEmptyText(sceneTag, 'sceneTag'),
      coachTip: _requireNonEmptyText(coachTip, 'coachTip'),
      sortOrder: _requireSortOrder(sortOrder),
    );
  }

  const PresetSceneDefinition._({
    required this.presetSceneId,
    required this.publishedVersion,
    required this.spaceId,
    required this.title,
    required this.summary,
    required this.sceneTag,
    required this.coachTip,
    required this.sortOrder,
  });

  final String presetSceneId;
  final int publishedVersion;
  final String spaceId;
  final String title;
  final String summary;
  final String sceneTag;
  final String coachTip;
  final int sortOrder;

  factory PresetSceneDefinition.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, _jsonKeys);
    return PresetSceneDefinition(
      presetSceneId: _readSafeSceneId(json, 'presetSceneId'),
      publishedVersion: _readPositiveInt(json, 'publishedVersion'),
      spaceId: _readSafeSceneId(json, 'spaceId'),
      title: _readNonEmptyString(json, 'title'),
      summary: _readNonEmptyString(json, 'summary'),
      sceneTag: _readNonEmptyString(json, 'sceneTag'),
      coachTip: _readNonEmptyString(json, 'coachTip'),
      sortOrder: _readSortOrder(json, 'sortOrder'),
    );
  }

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'presetSceneId': presetSceneId,
      'publishedVersion': publishedVersion,
      'spaceId': spaceId,
      'title': title,
      'summary': summary,
      'sceneTag': sceneTag,
      'coachTip': coachTip,
      'sortOrder': sortOrder,
    };
  }

  Map<String, Object?> toJson() => toJsonMap();

  /// Parses a public API/cache scene list and enforces collection invariants.
  ///
  /// Both preset identity and route identity are checked. Route identity is
  /// `(spaceId, presetSceneId)` because that is the identity used by practice
  /// navigation and local interaction events.
  static List<PresetSceneDefinition> parseList(Object? raw) {
    if (raw is! List) {
      throw const FormatException('preset scene catalog must be a JSON array');
    }

    final scenes = <PresetSceneDefinition>[];
    final ids = <String>{};
    final routeIdentities = <String>{};
    for (final item in raw) {
      if (item is! Map) {
        throw const FormatException('preset scene item must be a JSON object');
      }
      if (item.keys.any((key) => key is! String)) {
        throw const FormatException(
          'preset scene item contains an invalid key',
        );
      }
      final scene = PresetSceneDefinition.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (!ids.add(scene.presetSceneId)) {
        throw const FormatException('preset scene identity is duplicated');
      }
      final routeIdentity = '${scene.spaceId}\u0000${scene.presetSceneId}';
      if (!routeIdentities.add(routeIdentity)) {
        throw const FormatException(
          'preset scene route identity is duplicated',
        );
      }
      scenes.add(scene);
    }
    return List<PresetSceneDefinition>.unmodifiable(scenes);
  }

  static const Set<String> _jsonKeys = <String>{
    'presetSceneId',
    'publishedVersion',
    'spaceId',
    'title',
    'summary',
    'sceneTag',
    'coachTip',
    'sortOrder',
  };
}

class PresetSceneCatalogSnapshot {
  PresetSceneCatalogSnapshot({
    required this.source,
    required Iterable<PresetSceneDefinition> scenes,
  }) : scenes = List<PresetSceneDefinition>.unmodifiable(scenes);

  final PresetSceneCatalogSource source;
  final List<PresetSceneDefinition> scenes;

  bool get isEmpty => scenes.isEmpty;
}

void _requireExactKeys(Map<String, dynamic> json, Set<String> expected) {
  final actual = json.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw const FormatException('preset scene fields are invalid');
  }
}

String _readSafeSceneId(Map<String, dynamic> json, String key) {
  final value = _readNonEmptyString(json, key);
  if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,95}$').hasMatch(value)) {
    throw const FormatException('preset scene ID is invalid');
  }
  return value;
}

String _readNonEmptyString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('preset scene string field is invalid');
  }
  return value.trim();
}

int _readPositiveInt(Map<String, dynamic> json, String key) {
  final value = _readInt(json, key);
  if (value <= 0) {
    throw const FormatException('preset scene version is invalid');
  }
  return value;
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw const FormatException('preset scene integer field is invalid');
  }
  return value;
}

String _requireSafeIdentifier(String value, String field) {
  final normalized = value.trim();
  if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,95}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, '必须是安全的小写标识符。');
  }
  return normalized;
}

int _requirePositiveVersion(int value) {
  if (value <= 0) {
    throw ArgumentError.value(value, 'publishedVersion', '必须是正整数。');
  }
  return value;
}

String _requireNonEmptyText(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, '不能为空。');
  }
  return normalized;
}

int _requireSortOrder(int value) {
  if (value < 0) {
    throw ArgumentError.value(value, 'sortOrder', '不能小于 0。');
  }
  return value;
}

int _readSortOrder(Map<String, dynamic> json, String key) {
  final value = _readInt(json, key);
  if (value < 0) {
    throw const FormatException('preset scene sort order is invalid');
  }
  return value;
}
