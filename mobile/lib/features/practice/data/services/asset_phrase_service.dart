import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/domain/models/preset_scene_definition.dart';

class AssetPhraseService {
  AssetPhraseService({
    required AssetBundle bundle,
    this.assetPath = 'assets/content/seed_content.json',
  }) : _bundle = bundle;

  final AssetBundle _bundle;
  final String assetPath;

  Future<SeedContentBundle>? _cachedBundle;

  Future<SeedContentBundle> loadSeedContent() {
    return _cachedBundle ??= _loadSeedContent();
  }

  Future<SeedActivity> loadActivity({
    required String spaceId,
    required String activityId,
  }) async {
    final content = await loadSeedContent();
    return content.findActivity(spaceId: spaceId, activityId: activityId);
  }

  Future<List<PracticePhrase>> loadPracticePhrases({
    required String spaceId,
    required String activityId,
  }) async {
    final activity = await loadActivity(
      spaceId: spaceId,
      activityId: activityId,
    );
    return activity.phrases
        .map(
          (phrase) => PracticePhrase(
            spaceId: spaceId,
            activityId: activityId,
            phraseId: phrase.id,
            step: phrase.step,
            english: phrase.english,
            chinese: phrase.chinese,
            pronunciation: phrase.pronunciation,
            difficulty: phrase.difficulty,
            audioAsset: phrase.audioAsset,
          ),
        )
        .toList(growable: false);
  }

  /// Builds the offline catalog from the shipped seed content.
  ///
  /// The seed's activity order is the bundled order. No remote sorting rule is
  /// applied here; remote/cache snapshots retain their own list order.
  Future<List<PresetSceneDefinition>> loadBundledPresetScenes() async {
    final content = await loadSeedContent();
    var sortOrder = 0;
    final scenes = <PresetSceneDefinition>[];
    for (final space in content.spaces) {
      for (final activity in space.activities) {
        scenes.add(
          PresetSceneDefinition(
            presetSceneId: activity.id,
            publishedVersion: 1,
            spaceId: space.id,
            title: activity.title,
            summary: activity.summary,
            sceneTag: activity.sceneTag,
            coachTip: activity.coachTip,
            sortOrder: sortOrder++,
          ),
        );
      }
    }
    return List<PresetSceneDefinition>.unmodifiable(scenes);
  }

  Future<SeedContentBundle> _loadSeedContent() async {
    final rawJson = await _bundle.loadString(assetPath);
    final content = SeedContentBundle.fromJsonString(rawJson);
    await content.validateAssets(_bundle);
    return content;
  }
}

class SeedContentBundle {
  SeedContentBundle({required this.spaces});

  final List<SeedSpace> spaces;

  SeedActivity get primaryActivity {
    if (spaces.isEmpty || spaces.first.activities.isEmpty) {
      throw const FormatException('种子内容缺少可练习 activity。');
    }
    return spaces.first.activities.first;
  }

  static SeedContentBundle fromJsonString(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('seed_content.json 顶层必须是对象。');
    }

    final spacesJson = decoded['spaces'];
    if (spacesJson is! List || spacesJson.isEmpty) {
      throw const FormatException('seed_content.json 必须至少包含一个 space。');
    }

    return SeedContentBundle(
      spaces: spacesJson
          .map((space) => SeedSpace.fromMap(space as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  SeedSpace findSpace(String spaceId) {
    for (final space in spaces) {
      if (space.id == spaceId) {
        return space;
      }
    }
    throw FormatException('未知 spaceId: $spaceId');
  }

  SeedActivity findActivity({
    required String spaceId,
    required String activityId,
  }) {
    final space = findSpace(spaceId);
    for (final activity in space.activities) {
      if (activity.id == activityId) {
        return activity;
      }
    }
    throw FormatException('未知 activityId: $spaceId/$activityId');
  }

  Future<void> validateAssets(AssetBundle bundle) async {
    for (final space in spaces) {
      for (final activity in space.activities) {
        for (final phrase in activity.phrases) {
          if (!phrase.audioAsset.startsWith('assets/audio/')) {
            throw FormatException(
              'audioAsset 必须以 assets/audio/ 开头: ${phrase.audioAsset}',
            );
          }
          await bundle.load(phrase.audioAsset);
        }
      }
    }
  }
}

class SeedSpace {
  SeedSpace({
    required this.id,
    required this.title,
    required this.description,
    required this.activities,
  });

  final String id;
  final String title;
  final String description;
  final List<SeedActivity> activities;

  factory SeedSpace.fromMap(Map<String, dynamic> json) {
    final id = (json['id'] as String? ?? '').trim();
    final activitiesJson = json['activities'];
    if (id.isEmpty) {
      throw const FormatException('space.id 缺失。');
    }
    if (activitiesJson is! List || activitiesJson.isEmpty) {
      throw FormatException('space $id 缺少 activities。');
    }

    return SeedSpace(
      id: id,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      activities: activitiesJson
          .map(
            (activity) =>
                SeedActivity.fromMap(activity as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

class SeedActivity {
  SeedActivity({
    required this.id,
    required this.title,
    required this.summary,
    required this.sceneTag,
    required this.coachTip,
    required this.phrases,
  });

  final String id;
  final String title;
  final String summary;
  final String sceneTag;
  final String coachTip;
  final List<SeedPhrase> phrases;

  factory SeedActivity.fromMap(Map<String, dynamic> json) {
    final id = (json['id'] as String? ?? '').trim();
    final phrasesJson = json['phrases'];
    if (id.isEmpty) {
      throw const FormatException('activity.id 缺失。');
    }
    if (phrasesJson is! List || phrasesJson.isEmpty) {
      throw FormatException('activity $id 缺少 phrases。');
    }

    return SeedActivity(
      id: id,
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      sceneTag: json['sceneTag'] as String? ?? '',
      coachTip: json['coachTip'] as String? ?? '',
      phrases: phrasesJson
          .map((phrase) => SeedPhrase.fromMap(phrase as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class SeedPhrase {
  SeedPhrase({
    required this.id,
    required this.step,
    required this.english,
    required this.chinese,
    required this.pronunciation,
    required this.difficulty,
    required this.audioAsset,
  });

  final String id;
  final int step;
  final String english;
  final String chinese;
  final String pronunciation;
  final String difficulty;
  final String audioAsset;

  String get audioPlayerAsset =>
      audioAsset.startsWith('assets/') ? audioAsset.substring(7) : audioAsset;

  factory SeedPhrase.fromMap(Map<String, dynamic> json) {
    final id = (json['id'] as String? ?? '').trim();
    final audioAsset = (json['audioAsset'] as String? ?? '').trim();
    if (id.isEmpty) {
      throw const FormatException('phrase.id 缺失。');
    }
    if (audioAsset.isEmpty) {
      throw FormatException('phrase $id 缺少 audioAsset。');
    }

    return SeedPhrase(
      id: id,
      step: json['step'] as int? ?? 0,
      english: json['english'] as String? ?? '',
      chinese: json['chinese'] as String? ?? '',
      pronunciation: json['pronunciation'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      audioAsset: audioAsset,
    );
  }
}
