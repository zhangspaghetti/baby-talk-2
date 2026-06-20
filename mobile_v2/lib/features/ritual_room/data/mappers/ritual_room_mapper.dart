import '../../domain/models/ritual_room_content.dart';
import '../dto/ritual_room_response.dart';

/// Validates transport identity and maps stable content into domain values.
final class RitualRoomMapper {
  const RitualRoomMapper();

  static const approvedIllustrationPath =
      'assets/illustrations/rituals/shoes_on/shoes_on_approved_v1.png';

  RitualRoomContent toDomain(RitualRoomResponse response) {
    if (response.ritualRoomId.trim().isEmpty) {
      throw const FormatException('ritual_room_id is required');
    }
    if (response.illustration.status != 'approved') {
      throw const FormatException('illustration must be approved');
    }
    if (response.illustration.assetPath != approvedIllustrationPath) {
      throw const FormatException('illustration path is not canonical');
    }

    return RitualRoomContent(
      ritualRoomId: response.ritualRoomId,
      roomName: response.roomName,
      routineAnchor: response.routineAnchor,
      anchorPhrase: response.anchorPhrase,
      chineseHelper: response.chineseHelper,
      illustration: RitualIllustration(
        assetPath: response.illustration.assetPath,
        status: response.illustration.status,
      ),
      bootstrapUtterance: RitualBootstrapUtterance(
        primary: response.bootstrapUtterance.primary,
        zhHelper: response.bootstrapUtterance.zhHelper,
      ),
      actionCue: response.actionCue,
      audio: RitualAudioContent(
        available: response.audio.available,
        label: response.audio.label,
        assetReference: response.audio.assetReference,
      ),
      reactionPrompt: response.reactionPrompt,
      reactionChoices: response.reactionChoices
          .map(
            (choice) =>
                RitualReactionChoice(id: choice.id, label: choice.label),
          )
          .toList(growable: false),
      pendingCopy: response.pendingCopy,
      reassurance: response.reassurance,
      quietExit: response.quietExit,
      governanceEvidence: RitualGovernanceEvidence(
        contextSeedId: response.governanceEvidence.contextSeedId,
        joinabilityHypothesis:
            response.governanceEvidence.joinabilityHypothesis,
        governorDecision: response.governanceEvidence.governorDecision,
        productionGardenStatus:
            response.governanceEvidence.productionGardenStatus,
      ),
    );
  }
}
