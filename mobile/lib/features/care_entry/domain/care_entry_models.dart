import 'package:flutter/foundation.dart';

abstract interface class CareEntryRegistry {
  Future<CareEntryResolution> resolve({
    required CareEntryPlacementId placement,
    required int visibleSlots,
    required DateTime localTime,
  });
}

abstract interface class CareEntryFallbackCatalog {
  Future<CareFirstUtterance> resolve(
    CatalogFallbackRef fallback, {
    required AudioReview audioReview,
  });
}

@immutable
final class CareEntryPlacementId {
  const CareEntryPlacementId(this.value) : assert(value != '');

  final String value;

  @override
  bool operator ==(Object other) =>
      other is CareEntryPlacementId && other.value == value;

  @override
  int get hashCode => Object.hash(CareEntryPlacementId, value);
}

@immutable
final class CareEntryId {
  const CareEntryId(this.value) : assert(value != '');

  final String value;

  @override
  bool operator ==(Object other) =>
      other is CareEntryId && other.value == value;

  @override
  int get hashCode => Object.hash(CareEntryId, value);
}

@immutable
final class GenerationSceneId {
  const GenerationSceneId(this.value) : assert(value != '');

  final String value;

  @override
  bool operator ==(Object other) =>
      other is GenerationSceneId && other.value == value;

  @override
  int get hashCode => Object.hash(GenerationSceneId, value);
}

@immutable
final class CatalogFallbackId {
  const CatalogFallbackId(this.value) : assert(value != '');

  final String value;

  @override
  bool operator ==(Object other) =>
      other is CatalogFallbackId && other.value == value;

  @override
  int get hashCode => Object.hash(CatalogFallbackId, value);
}

enum AudioReview { reviewed }

@immutable
final class GenerationSceneRef {
  const GenerationSceneRef({
    required this.id,
    required this.schemaVersion,
    required this.sceneType,
    required this.parentTonePreference,
  });

  final GenerationSceneId id;
  final int schemaVersion;
  final String sceneType;
  final String parentTonePreference;
}

@immutable
final class CatalogFallbackRef {
  const CatalogFallbackRef({
    required this.id,
    required this.spaceId,
    required this.activityId,
    required this.phraseId,
  });

  final CatalogFallbackId id;
  final String spaceId;
  final String activityId;
  final String phraseId;
}

@immutable
final class CareFirstUtterance {
  const CareFirstUtterance({
    required this.english,
    required this.chinese,
    required this.pronunciation,
    required this.audioAsset,
    required this.audioReview,
  });

  final String english;
  final String chinese;
  final String pronunciation;
  final String audioAsset;
  final AudioReview audioReview;
}

@immutable
final class CareMomentSeed {
  const CareMomentSeed({
    required this.generationRef,
    required this.fallback,
    required this.firstUtterance,
  });

  final GenerationSceneRef generationRef;
  final CatalogFallbackRef fallback;
  final CareFirstUtterance firstUtterance;
}

@immutable
final class ResolvedCareEntry {
  const ResolvedCareEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.visualToken,
    required this.order,
    required this.seed,
    required this.isRecommended,
  });

  final CareEntryId id;
  final String title;
  final String subtitle;
  final String visualToken;
  final int order;
  final CareMomentSeed seed;
  final bool isRecommended;

  ResolvedCareEntry copyWithRecommendation(bool value) => ResolvedCareEntry(
    id: id,
    title: title,
    subtitle: subtitle,
    visualToken: visualToken,
    order: order,
    seed: seed,
    isRecommended: value,
  );
}

@immutable
final class CareEntryResolution {
  CareEntryResolution({
    required this.schemaVersion,
    required this.revision,
    required this.placement,
    required List<ResolvedCareEntry> entries,
    required this.recommendedEntryId,
  }) : entries = List<ResolvedCareEntry>.unmodifiable(entries);

  final int schemaVersion;
  final String revision;
  final CareEntryPlacementId placement;
  final List<ResolvedCareEntry> entries;
  final CareEntryId? recommendedEntryId;
}
