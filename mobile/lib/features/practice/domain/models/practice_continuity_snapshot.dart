import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';

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

class PracticeContinuityRecommendation {
  const PracticeContinuityRecommendation({
    required this.spaceId,
    required this.activityId,
    required this.activityTitle,
    required this.reason,
    required this.reasonLabel,
    this.fallbackReason,
  });

  final String spaceId;
  final String activityId;
  final String activityTitle;
  final PracticeContinuityReason reason;
  final String reasonLabel;
  final String? fallbackReason;
}

class PracticeContinuityCadenceSummary {
  const PracticeContinuityCadenceSummary({
    required this.totalKnownEvents,
    required this.startedActivityCount,
    required this.lastEventTime,
    required this.headline,
    required this.detail,
  });

  final int totalKnownEvents;
  final int startedActivityCount;
  final DateTime? lastEventTime;
  final String headline;
  final String detail;

  bool get isEmpty => totalKnownEvents == 0;
}

class PracticeContinuitySnapshot {
  const PracticeContinuitySnapshot({
    required this.catalog,
    required this.recommendedActivity,
    required this.recentActivity,
    required this.nextIncompleteActivity,
    required this.starterActivity,
    required this.recommendation,
    required this.cadence,
    this.warningMessage,
  });

  final PracticeActivityCatalog catalog;
  final PracticeCatalogActivitySummary recommendedActivity;
  final PracticeCatalogActivitySummary? recentActivity;
  final PracticeCatalogActivitySummary? nextIncompleteActivity;
  final PracticeCatalogActivitySummary? starterActivity;
  final PracticeContinuityRecommendation recommendation;
  final PracticeContinuityCadenceSummary cadence;
  final String? warningMessage;

  String? get fallbackReason => recommendation.fallbackReason;

  bool get hasWarning => warningMessage?.trim().isNotEmpty ?? false;
}
