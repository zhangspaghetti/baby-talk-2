import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';

final class BundledCareEntryFallbackCatalog
    implements CareEntryFallbackCatalog {
  BundledCareEntryFallbackCatalog({
    required AssetBundle bundle,
    this.catalogAssetPath = 'assets/content/seed_content.json',
  }) : _bundle = bundle;

  final AssetBundle _bundle;
  final String catalogAssetPath;
  Future<Map<_CatalogPhraseKey, _CatalogPhrase>>? _cachedIndex;

  @override
  Future<CareFirstUtterance> resolve(
    CatalogFallbackRef fallback, {
    required AudioReview audioReview,
  }) async {
    final index = await (_cachedIndex ??= _loadIndex());
    final phrase =
        index[_CatalogPhraseKey(
          fallback.spaceId,
          fallback.activityId,
          fallback.phraseId,
        )];
    if (phrase == null) {
      throw FormatException(
        'Care Entry fallback phrase 不存在: '
        '${fallback.spaceId}/${fallback.activityId}/${fallback.phraseId}',
      );
    }
    await _bundle.load(phrase.audioAsset);
    return CareFirstUtterance(
      english: phrase.english,
      chinese: phrase.chinese,
      pronunciation: phrase.pronunciation,
      audioAsset: phrase.audioAsset,
      audioReview: audioReview,
    );
  }

  Future<Map<_CatalogPhraseKey, _CatalogPhrase>> _loadIndex() async {
    final decoded = jsonDecode(await _bundle.loadString(catalogAssetPath));
    if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
      throw const FormatException('seed content schemaVersion 不受支持。');
    }
    final spaces = decoded['spaces'];
    if (spaces is! List || spaces.isEmpty) {
      throw const FormatException('seed content 缺少 spaces。');
    }
    final index = <_CatalogPhraseKey, _CatalogPhrase>{};
    for (final rawSpace in spaces) {
      final space = _requiredMap(rawSpace, 'space');
      final spaceId = _requiredString(space, 'id');
      for (final rawActivity in _requiredList(space, 'activities')) {
        final activity = _requiredMap(rawActivity, 'activity');
        final activityId = _requiredString(activity, 'id');
        for (final rawPhrase in _requiredList(activity, 'phrases')) {
          final phrase = _requiredMap(rawPhrase, 'phrase');
          final phraseId = _requiredString(phrase, 'id');
          final audioAsset = _requiredString(phrase, 'audioAsset');
          if (!audioAsset.startsWith('assets/audio/')) {
            throw FormatException(
              'Care Entry fallback audioAsset 非法: $audioAsset',
            );
          }
          final key = _CatalogPhraseKey(spaceId, activityId, phraseId);
          if (index.containsKey(key)) {
            throw FormatException(
              '重复 Care Entry fallback phrase: '
              '$spaceId/$activityId/$phraseId',
            );
          }
          index[key] = _CatalogPhrase(
            english: _requiredString(phrase, 'english'),
            chinese: _requiredString(phrase, 'chinese'),
            pronunciation: _requiredString(phrase, 'pronunciation'),
            audioAsset: audioAsset,
          );
        }
      }
    }
    return Map<_CatalogPhraseKey, _CatalogPhrase>.unmodifiable(index);
  }
}

final class _CatalogPhraseKey {
  const _CatalogPhraseKey(this.spaceId, this.activityId, this.phraseId);

  final String spaceId;
  final String activityId;
  final String phraseId;

  @override
  bool operator ==(Object other) =>
      other is _CatalogPhraseKey &&
      other.spaceId == spaceId &&
      other.activityId == activityId &&
      other.phraseId == phraseId;

  @override
  int get hashCode => Object.hash(spaceId, activityId, phraseId);
}

final class _CatalogPhrase {
  const _CatalogPhrase({
    required this.english,
    required this.chinese,
    required this.pronunciation,
    required this.audioAsset,
  });

  final String english;
  final String chinese;
  final String pronunciation;
  final String audioAsset;
}

Map<String, dynamic> _requiredMap(Object? value, String label) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$label 必须是对象。');
  }
  return value;
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.isEmpty) {
    throw FormatException('字段 `$key` 必须是非空列表。');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('字段 `$key` 必须是非空字符串。');
  }
  return value.trim();
}
