/// Presentation-safe identity for the one utterance currently shown.
final class ActiveUtterance {
  const ActiveUtterance({
    required this.displayId,
    required this.primary,
    required this.zhSupport,
    required this.actionCue,
    required this.audioAssetId,
    this.contextLabel,
    this.gentleSupport,
  });

  final String displayId;
  final String primary;
  final String zhSupport;
  final String actionCue;
  final String audioAssetId;
  final String? contextLabel;
  final String? gentleSupport;
}

enum ActiveUtteranceSlot { ready, notReadyYet }
