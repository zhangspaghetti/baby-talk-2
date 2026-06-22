import 'dart:collection';

/// Approved illustration metadata supplied by the stable content boundary.
final class RitualIllustration {
  const RitualIllustration({required this.assetPath, required this.status});

  final String assetPath;
  final String status;
}

/// Playback metadata for the current stable room content.
final class RitualAudioContent {
  const RitualAudioContent({
    required this.available,
    required this.label,
    required this.assetReference,
  });

  final bool available;
  final String label;
  final String? assetReference;
}

/// Neutral context choice that does not judge the child.
final class RitualReactionChoice {
  const RitualReactionChoice({required this.id, required this.label});

  final String id;
  final String label;
}

/// Prior-phase evidence carried as data without granting transition authority.
final class RitualGovernanceEvidence {
  const RitualGovernanceEvidence({
    required this.contextSeedId,
    required this.joinabilityHypothesis,
    required this.governorDecision,
    required this.productionGardenStatus,
  });

  final String contextSeedId;
  final String joinabilityHypothesis;
  final String governorDecision;
  final String productionGardenStatus;
}

/// Immutable stable content for one Ritual Room.
final class RitualRoomContent {
  RitualRoomContent({
    required this.ritualRoomId,
    required this.roomName,
    required this.routineAnchor,
    required this.anchorPhrase,
    required this.chineseHelper,
    required this.illustration,
    required this.actionCue,
    required this.audio,
    required this.reactionPrompt,
    required List<RitualReactionChoice> reactionChoices,
    required this.pendingCopy,
    required this.reassurance,
    required this.quietExit,
    required this.governanceEvidence,
  }) : reactionChoices = UnmodifiableListView(
         List<RitualReactionChoice>.of(reactionChoices),
       );

  final String ritualRoomId;
  final String roomName;
  final String routineAnchor;
  final String anchorPhrase;
  final String chineseHelper;
  final RitualIllustration illustration;
  final String actionCue;
  final RitualAudioContent audio;
  final String reactionPrompt;
  final List<RitualReactionChoice> reactionChoices;
  final String pendingCopy;
  final String reassurance;
  final String quietExit;
  final RitualGovernanceEvidence governanceEvidence;
}
