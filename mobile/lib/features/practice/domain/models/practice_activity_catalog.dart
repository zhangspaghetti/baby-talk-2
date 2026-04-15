import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

class PracticeCatalogRecentResultSummary {
  const PracticeCatalogRecentResultSummary({
    required this.phraseId,
    required this.phraseEnglish,
    required this.reactionType,
    required this.eventTime,
    required this.totalEvents,
  });

  final String phraseId;
  final String phraseEnglish;
  final BabyReactionType reactionType;
  final DateTime eventTime;
  final int totalEvents;
}

class PracticeCatalogActivitySummary {
  const PracticeCatalogActivitySummary({
    required this.spaceId,
    required this.spaceTitle,
    required this.activityId,
    required this.title,
    required this.summary,
    required this.sceneTag,
    required this.coachTip,
    required this.totalPhraseCount,
    required this.completedPhraseCount,
    required this.completedPhraseIds,
    required this.nextPhraseId,
    required this.nextPhraseEnglish,
    required this.totalEvents,
    required this.skippedUnknownPhraseCount,
    required this.skippedMalformedEventCount,
    this.lastEventTime,
    this.recentResult,
    this.warningMessage,
  });

  final String spaceId;
  final String spaceTitle;
  final String activityId;
  final String title;
  final String summary;
  final String sceneTag;
  final String coachTip;
  final int totalPhraseCount;
  final int completedPhraseCount;
  final List<String> completedPhraseIds;
  final String? nextPhraseId;
  final String? nextPhraseEnglish;
  final int totalEvents;
  final int skippedUnknownPhraseCount;
  final int skippedMalformedEventCount;
  final DateTime? lastEventTime;
  final PracticeCatalogRecentResultSummary? recentResult;
  final String? warningMessage;

  bool get isEmpty => totalEvents == 0;

  bool get isComplete =>
      totalPhraseCount > 0 && completedPhraseCount >= totalPhraseCount;

  bool get hasRecoverableIssue =>
      skippedUnknownPhraseCount > 0 ||
      skippedMalformedEventCount > 0 ||
      (warningMessage?.trim().isNotEmpty ?? false);
}

class PracticeCatalogSpaceSummary {
  const PracticeCatalogSpaceSummary({
    required this.spaceId,
    required this.title,
    required this.description,
    required this.activities,
    required this.totalEvents,
    required this.startedActivityCount,
    required this.completedActivityCount,
    this.lastEventTime,
  });

  final String spaceId;
  final String title;
  final String description;
  final List<PracticeCatalogActivitySummary> activities;
  final int totalEvents;
  final int startedActivityCount;
  final int completedActivityCount;
  final DateTime? lastEventTime;

  int get totalActivityCount => activities.length;

  bool get isEmpty => totalEvents == 0;
}

class PracticeActivityCatalog {
  const PracticeActivityCatalog({
    required this.installationId,
    required this.spaces,
    required this.activities,
    required this.totalStoredEvents,
    required this.validEvents,
    required this.knownEvents,
    required this.skippedMalformedEvents,
    required this.skippedUnknownContentEvents,
    this.lastIssueMessage,
    this.catalogWarning,
  });

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

  final String? installationId;
  final List<PracticeCatalogSpaceSummary> spaces;
  final List<PracticeCatalogActivitySummary> activities;
  final int totalStoredEvents;
  final int validEvents;
  final int knownEvents;
  final int skippedMalformedEvents;
  final int skippedUnknownContentEvents;
  final String? lastIssueMessage;
  final String? catalogWarning;

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
