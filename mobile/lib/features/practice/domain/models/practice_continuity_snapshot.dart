import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';

part '../../../../generated/features/practice/domain/models/practice_continuity_snapshot.freezed.dart';

enum PracticeContinuityReason {
  recentActivity,
  nextIncomplete,
  starterFallback,
  safeCatalogFallback,
}

extension PracticeContinuityReasonLabels on PracticeContinuityReason {
  String get wireValue {
    switch (this) {
      case PracticeContinuityReason.recentActivity:
        return 'recent_activity';
      case PracticeContinuityReason.nextIncomplete:
        return 'next_incomplete';
      case PracticeContinuityReason.starterFallback:
        return 'starter_fallback';
      case PracticeContinuityReason.safeCatalogFallback:
        return 'safe_catalog_fallback';
    }
  }

  String get label {
    switch (this) {
      case PracticeContinuityReason.recentActivity:
        return '继续最近 activity';
      case PracticeContinuityReason.nextIncomplete:
        return '接上未完成 activity';
      case PracticeContinuityReason.starterFallback:
        return '回到 starter activity';
      case PracticeContinuityReason.safeCatalogFallback:
        return '使用目录安全回退';
    }
  }
}

@freezed
class PracticeContinuityRecommendation with _$PracticeContinuityRecommendation {
  const factory PracticeContinuityRecommendation({
    required String spaceId,
    required String activityId,
    required String activityTitle,
    required PracticeContinuityReason reason,
    required String reasonLabel,
    String? generatedContentId,
    String? fallbackReason,
  }) = _PracticeContinuityRecommendation;
}

@freezed
class PracticeContinuityCadenceSummary with _$PracticeContinuityCadenceSummary {
  const PracticeContinuityCadenceSummary._();

  const factory PracticeContinuityCadenceSummary({
    required int totalKnownEvents,
    required int startedActivityCount,
    required DateTime? lastEventTime,
    required String headline,
    required String detail,
  }) = _PracticeContinuityCadenceSummary;

  bool get isEmpty => totalKnownEvents == 0;
}

@freezed
class PracticeContinuitySnapshot with _$PracticeContinuitySnapshot {
  const PracticeContinuitySnapshot._();

  const factory PracticeContinuitySnapshot({
    required PracticeActivityCatalog catalog,
    required PracticeCatalogActivitySummary recommendedActivity,
    required PracticeCatalogActivitySummary? recentActivity,
    required PracticeCatalogActivitySummary? nextIncompleteActivity,
    required PracticeCatalogActivitySummary? starterActivity,
    required PracticeContinuityRecommendation recommendation,
    required PracticeContinuityCadenceSummary cadence,
    String? warningMessage,
  }) = _PracticeContinuitySnapshot;

  String? get fallbackReason => recommendation.fallbackReason;

  bool get hasWarning => warningMessage?.trim().isNotEmpty ?? false;
}
