import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

part '../../../../generated/features/practice/domain/models/practice_activity_catalog.freezed.dart';

@freezed
class PracticeCatalogRecentResultSummary
    with _$PracticeCatalogRecentResultSummary {
  const factory PracticeCatalogRecentResultSummary({
    required String phraseId,
    required String phraseEnglish,
    required BabyReactionType reactionType,
    required DateTime eventTime,
    required int totalEvents,
  }) = _PracticeCatalogRecentResultSummary;
}

@freezed
class PracticeCatalogActivitySummary with _$PracticeCatalogActivitySummary {
  const PracticeCatalogActivitySummary._();

  const factory PracticeCatalogActivitySummary({
    required String spaceId,
    required String spaceTitle,
    required String activityId,
    required String title,
    required String summary,
    required String sceneTag,
    required String coachTip,
    required int totalPhraseCount,
    required int completedPhraseCount,
    required List<String> completedPhraseIds,
    required String? nextPhraseId,
    required String? nextPhraseEnglish,
    required int totalEvents,
    required int skippedUnknownPhraseCount,
    required int skippedMalformedEventCount,
    DateTime? lastEventTime,
    PracticeCatalogRecentResultSummary? recentResult,
    String? warningMessage,
  }) = _PracticeCatalogActivitySummary;

  bool get isEmpty => totalEvents == 0;

  bool get isComplete =>
      totalPhraseCount > 0 && completedPhraseCount >= totalPhraseCount;

  bool get hasRecoverableIssue =>
      skippedUnknownPhraseCount > 0 ||
      skippedMalformedEventCount > 0 ||
      (warningMessage?.trim().isNotEmpty ?? false);
}

@freezed
class PracticeCatalogSpaceSummary with _$PracticeCatalogSpaceSummary {
  const PracticeCatalogSpaceSummary._();

  const factory PracticeCatalogSpaceSummary({
    required String spaceId,
    required String title,
    required String description,
    required List<PracticeCatalogActivitySummary> activities,
    required int totalEvents,
    required int startedActivityCount,
    required int completedActivityCount,
    DateTime? lastEventTime,
  }) = _PracticeCatalogSpaceSummary;

  int get totalActivityCount => activities.length;

  bool get isEmpty => totalEvents == 0;
}

@freezed
class PracticeActivityCatalog with _$PracticeActivityCatalog {
  const PracticeActivityCatalog._();

  const factory PracticeActivityCatalog({
    required String? installationId,
    required List<PracticeCatalogSpaceSummary> spaces,
    required List<PracticeCatalogActivitySummary> activities,
    required int totalStoredEvents,
    required int validEvents,
    required int knownEvents,
    required int skippedMalformedEvents,
    required int skippedUnknownContentEvents,
    String? lastIssueMessage,
    String? catalogWarning,
  }) = _PracticeActivityCatalog;

  factory PracticeActivityCatalog.empty({String? installationId}) {
    return PracticeActivityCatalog(
      installationId: installationId,
      spaces: const <PracticeCatalogSpaceSummary>[],
      activities: const <PracticeCatalogActivitySummary>[],
      totalStoredEvents: 0,
      validEvents: 0,
      knownEvents: 0,
      skippedMalformedEvents: 0,
      skippedUnknownContentEvents: 0,
    );
  }

  bool get isEmpty => activities.isEmpty;

  bool get hasIssues =>
      skippedMalformedEvents > 0 ||
      skippedUnknownContentEvents > 0 ||
      (catalogWarning?.trim().isNotEmpty ?? false);

  PracticeCatalogActivitySummary? findActivity({
    required String spaceId,
    required String activityId,
  }) {
    for (final activity in activities) {
      if (activity.spaceId == spaceId && activity.activityId == activityId) {
        return activity;
      }
    }
    return null;
  }

  PracticeCatalogActivitySummary? get mostRecentActivity {
    PracticeCatalogActivitySummary? candidate;
    for (final activity in activities) {
      final eventTime = activity.lastEventTime;
      if (eventTime == null) {
        continue;
      }
      final candidateEventTime = candidate?.lastEventTime;
      if (candidateEventTime == null || eventTime.isAfter(candidateEventTime)) {
        candidate = activity;
      }
    }
    return candidate;
  }

  PracticeCatalogActivitySummary? get firstIncompleteActivity {
    for (final activity in activities) {
      if (!activity.isComplete) {
        return activity;
      }
    }
    return null;
  }

  int get startedActivityCount {
    return activities.where((activity) => !activity.isEmpty).length;
  }
}
