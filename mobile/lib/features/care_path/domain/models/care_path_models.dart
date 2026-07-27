import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

enum CarePathNodeState { current, nearby, doneToday, unavailable }

enum CareTurnPhase {
  idle,
  loading,
  utteranceReady,
  reactionPrompt,
  savingTrace,
  nextSupportReady,
  heldWithFallback,
  error,
}

enum CareTurnFailureKind {
  momentUnavailable,
  reactionUnknownOutcome,
  reactionRejected,
  localStateUnavailable,
}

class CareMoment {
  const CareMoment({
    required this.spaceId,
    required this.activityId,
    required this.spaceTitle,
    required this.title,
    required this.sceneTag,
    required this.careActionLabel,
    required this.coachTip,
    required this.nodeState,
  });

  final String spaceId;
  final String activityId;
  final String spaceTitle;
  final String title;
  final String sceneTag;
  final String careActionLabel;
  final String coachTip;
  final CarePathNodeState nodeState;

  CareMoment copyWith({
    String? spaceId,
    String? activityId,
    String? spaceTitle,
    String? title,
    String? sceneTag,
    String? careActionLabel,
    String? coachTip,
    CarePathNodeState? nodeState,
  }) {
    return CareMoment(
      spaceId: spaceId ?? this.spaceId,
      activityId: activityId ?? this.activityId,
      spaceTitle: spaceTitle ?? this.spaceTitle,
      title: title ?? this.title,
      sceneTag: sceneTag ?? this.sceneTag,
      careActionLabel: careActionLabel ?? this.careActionLabel,
      coachTip: coachTip ?? this.coachTip,
      nodeState: nodeState ?? this.nodeState,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CareMoment &&
            other.spaceId == spaceId &&
            other.activityId == activityId &&
            other.spaceTitle == spaceTitle &&
            other.title == title &&
            other.sceneTag == sceneTag &&
            other.careActionLabel == careActionLabel &&
            other.coachTip == coachTip &&
            other.nodeState == nodeState;
  }

  @override
  int get hashCode => Object.hash(
    spaceId,
    activityId,
    spaceTitle,
    title,
    sceneTag,
    careActionLabel,
    coachTip,
    nodeState,
  );
}

class CareUtterance {
  const CareUtterance({
    required this.phraseId,
    required this.english,
    required this.chinese,
    required this.pronunciation,
    required this.audioAsset,
    required this.whenToSay,
    required this.isFallback,
  });

  final String phraseId;
  final String english;
  final String chinese;
  final String pronunciation;
  final String? audioAsset;
  final String whenToSay;
  final bool isFallback;

  CareUtterance copyWith({
    String? phraseId,
    String? english,
    String? chinese,
    String? pronunciation,
    Object? audioAsset = _unset,
    String? whenToSay,
    bool? isFallback,
  }) {
    return CareUtterance(
      phraseId: phraseId ?? this.phraseId,
      english: english ?? this.english,
      chinese: chinese ?? this.chinese,
      pronunciation: pronunciation ?? this.pronunciation,
      audioAsset: identical(audioAsset, _unset)
          ? this.audioAsset
          : audioAsset as String?,
      whenToSay: whenToSay ?? this.whenToSay,
      isFallback: isFallback ?? this.isFallback,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CareUtterance &&
            other.phraseId == phraseId &&
            other.english == english &&
            other.chinese == chinese &&
            other.pronunciation == pronunciation &&
            other.audioAsset == audioAsset &&
            other.whenToSay == whenToSay &&
            other.isFallback == isFallback;
  }

  @override
  int get hashCode => Object.hash(
    phraseId,
    english,
    chinese,
    pronunciation,
    audioAsset,
    whenToSay,
    isFallback,
  );
}

class CareTurnSnapshot {
  const CareTurnSnapshot({
    required this.moment,
    required this.currentUtterance,
    required this.selectedReaction,
    required this.nextSupportUtterance,
    required this.phase,
    required this.traceEventKey,
    required this.latestGardenImpact,
    required this.message,
    this.failureKind,
  });

  final CareMoment moment;
  final CareUtterance? currentUtterance;
  final BabyReactionType? selectedReaction;
  final CareUtterance? nextSupportUtterance;
  final CareTurnPhase phase;
  final String? traceEventKey;
  final LatestPracticeImpact? latestGardenImpact;
  final String? message;
  final CareTurnFailureKind? failureKind;

  CareTurnSnapshot copyWith({
    CareMoment? moment,
    Object? currentUtterance = _unset,
    Object? selectedReaction = _unset,
    Object? nextSupportUtterance = _unset,
    CareTurnPhase? phase,
    Object? traceEventKey = _unset,
    Object? latestGardenImpact = _unset,
    Object? message = _unset,
    Object? failureKind = _unset,
  }) {
    return CareTurnSnapshot(
      moment: moment ?? this.moment,
      currentUtterance: identical(currentUtterance, _unset)
          ? this.currentUtterance
          : currentUtterance as CareUtterance?,
      selectedReaction: identical(selectedReaction, _unset)
          ? this.selectedReaction
          : selectedReaction as BabyReactionType?,
      nextSupportUtterance: identical(nextSupportUtterance, _unset)
          ? this.nextSupportUtterance
          : nextSupportUtterance as CareUtterance?,
      phase: phase ?? this.phase,
      traceEventKey: identical(traceEventKey, _unset)
          ? this.traceEventKey
          : traceEventKey as String?,
      latestGardenImpact: identical(latestGardenImpact, _unset)
          ? this.latestGardenImpact
          : latestGardenImpact as LatestPracticeImpact?,
      message: identical(message, _unset) ? this.message : message as String?,
      failureKind: identical(failureKind, _unset)
          ? this.failureKind
          : failureKind as CareTurnFailureKind?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CareTurnSnapshot &&
            other.moment == moment &&
            other.currentUtterance == currentUtterance &&
            other.selectedReaction == selectedReaction &&
            other.nextSupportUtterance == nextSupportUtterance &&
            other.phase == phase &&
            other.traceEventKey == traceEventKey &&
            other.latestGardenImpact == latestGardenImpact &&
            other.message == message &&
            other.failureKind == failureKind;
  }

  @override
  int get hashCode => Object.hash(
    moment,
    currentUtterance,
    selectedReaction,
    nextSupportUtterance,
    phase,
    traceEventKey,
    latestGardenImpact,
    message,
    failureKind,
  );
}

const Object _unset = Object();
