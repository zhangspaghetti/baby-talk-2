import 'package:flutter/foundation.dart';

enum OnboardingCareTurnSource { localFallback, remoteGenerated }

extension OnboardingCareTurnSourceWire on OnboardingCareTurnSource {
  String get wireValue => switch (this) {
    OnboardingCareTurnSource.localFallback => 'local_fallback',
    OnboardingCareTurnSource.remoteGenerated => 'remote_generated',
  };
}

@immutable
final class OnboardingCareTurnHandoff {
  const OnboardingCareTurnHandoff({
    required this.completionId,
    required this.spaceId,
    required this.activityId,
    required this.entryTitle,
    required this.utteranceId,
    required this.english,
    required this.chinese,
    required this.source,
  });

  final String completionId;
  final String spaceId;
  final String activityId;
  final String entryTitle;
  final String utteranceId;
  final String english;
  final String chinese;
  final OnboardingCareTurnSource source;
}

@immutable
final class OnboardingContinuationReactionRecord {
  const OnboardingContinuationReactionRecord({
    required this.eventId,
    required this.completionId,
    required this.utteranceId,
    required this.reaction,
    required this.occurredAt,
  });

  final String eventId;
  final String completionId;
  final String utteranceId;
  final String reaction;
  final DateTime occurredAt;
}

abstract interface class OnboardingCareTurnContinuationPort {
  Future<OnboardingCareTurnHandoff> verify(OnboardingCareTurnHandoff handoff);

  Future<OnboardingContinuationReactionRecord> recordReaction({
    required OnboardingCareTurnHandoff handoff,
    required String reaction,
    required DateTime occurredAt,
  });
}
