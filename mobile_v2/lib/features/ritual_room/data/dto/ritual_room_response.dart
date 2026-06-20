/// Transport representation of one stable Ritual Room payload.
final class RitualRoomResponse {
  const RitualRoomResponse({
    required this.ritualRoomId,
    required this.roomName,
    required this.routineAnchor,
    required this.anchorPhrase,
    required this.chineseHelper,
    required this.illustration,
    required this.bootstrapUtterance,
    required this.actionCue,
    required this.audio,
    required this.reactionPrompt,
    required this.reactionChoices,
    required this.pendingCopy,
    required this.reassurance,
    required this.quietExit,
    required this.governanceEvidence,
  });

  factory RitualRoomResponse.fromJson(Map<String, Object?> json) =>
      RitualRoomResponse(
        ritualRoomId: _requiredString(json, 'ritual_room_id'),
        roomName: _requiredString(json, 'room_name'),
        routineAnchor: _requiredString(json, 'routine_anchor'),
        anchorPhrase: _requiredString(json, 'anchor_phrase'),
        chineseHelper: _requiredString(json, 'chinese_helper'),
        illustration: RitualIllustrationResponse.fromJson(
          _requiredMap(json, 'illustration'),
        ),
        bootstrapUtterance: RitualBootstrapUtteranceResponse.fromJson(
          _requiredMap(json, 'bootstrap_utterance'),
        ),
        actionCue: _requiredString(json, 'action_cue'),
        audio: RitualAudioResponse.fromJson(_requiredMap(json, 'audio')),
        reactionPrompt: _requiredString(json, 'reaction_prompt'),
        reactionChoices: _requiredList(json, 'reaction_choices')
            .map(
              (value) => RitualReactionChoiceResponse.fromJson(
                _objectMap(value, 'reaction_choices item'),
              ),
            )
            .toList(growable: false),
        pendingCopy: _requiredString(json, 'pending_copy'),
        reassurance: _requiredString(json, 'reassurance'),
        quietExit: _requiredString(json, 'quiet_exit'),
        governanceEvidence: RitualGovernanceEvidenceResponse.fromJson(
          _requiredMap(json, 'governance_evidence'),
        ),
      );

  final String ritualRoomId;
  final String roomName;
  final String routineAnchor;
  final String anchorPhrase;
  final String chineseHelper;
  final RitualIllustrationResponse illustration;
  final RitualBootstrapUtteranceResponse bootstrapUtterance;
  final String actionCue;
  final RitualAudioResponse audio;
  final String reactionPrompt;
  final List<RitualReactionChoiceResponse> reactionChoices;
  final String pendingCopy;
  final String reassurance;
  final String quietExit;
  final RitualGovernanceEvidenceResponse governanceEvidence;

  Map<String, Object?> toJson() => {
    'ritual_room_id': ritualRoomId,
    'room_name': roomName,
    'routine_anchor': routineAnchor,
    'anchor_phrase': anchorPhrase,
    'chinese_helper': chineseHelper,
    'illustration': illustration.toJson(),
    'bootstrap_utterance': bootstrapUtterance.toJson(),
    'action_cue': actionCue,
    'audio': audio.toJson(),
    'reaction_prompt': reactionPrompt,
    'reaction_choices': reactionChoices
        .map((choice) => choice.toJson())
        .toList(growable: false),
    'pending_copy': pendingCopy,
    'reassurance': reassurance,
    'quiet_exit': quietExit,
    'governance_evidence': governanceEvidence.toJson(),
  };
}

final class RitualIllustrationResponse {
  const RitualIllustrationResponse({
    required this.assetPath,
    required this.status,
  });

  factory RitualIllustrationResponse.fromJson(Map<String, Object?> json) =>
      RitualIllustrationResponse(
        assetPath: _requiredString(json, 'asset_path'),
        status: _requiredString(json, 'status'),
      );

  final String assetPath;
  final String status;

  Map<String, Object?> toJson() => {'asset_path': assetPath, 'status': status};
}

final class RitualBootstrapUtteranceResponse {
  const RitualBootstrapUtteranceResponse({
    required this.primary,
    required this.zhHelper,
  });

  factory RitualBootstrapUtteranceResponse.fromJson(
    Map<String, Object?> json,
  ) => RitualBootstrapUtteranceResponse(
    primary: _requiredString(json, 'primary'),
    zhHelper: _requiredString(json, 'zh_helper'),
  );

  final String primary;
  final String zhHelper;

  Map<String, Object?> toJson() => {'primary': primary, 'zh_helper': zhHelper};
}

final class RitualAudioResponse {
  const RitualAudioResponse({
    required this.available,
    required this.label,
    required this.assetReference,
  });

  factory RitualAudioResponse.fromJson(Map<String, Object?> json) =>
      RitualAudioResponse(
        available: _requiredBool(json, 'available'),
        label: _requiredString(json, 'label'),
        assetReference: _optionalString(json, 'asset_reference'),
      );

  final bool available;
  final String label;
  final String? assetReference;

  Map<String, Object?> toJson() => {
    'available': available,
    'label': label,
    'asset_reference': assetReference,
  };
}

final class RitualReactionChoiceResponse {
  const RitualReactionChoiceResponse({required this.id, required this.label});

  factory RitualReactionChoiceResponse.fromJson(Map<String, Object?> json) =>
      RitualReactionChoiceResponse(
        id: _requiredString(json, 'id'),
        label: _requiredString(json, 'label'),
      );

  final String id;
  final String label;

  Map<String, Object?> toJson() => {'id': id, 'label': label};
}

final class RitualGovernanceEvidenceResponse {
  const RitualGovernanceEvidenceResponse({
    required this.contextSeedId,
    required this.joinabilityHypothesis,
    required this.governorDecision,
    required this.productionGardenStatus,
  });

  factory RitualGovernanceEvidenceResponse.fromJson(
    Map<String, Object?> json,
  ) => RitualGovernanceEvidenceResponse(
    contextSeedId: _requiredString(json, 'context_seed_id'),
    joinabilityHypothesis: _requiredString(json, 'joinability_hypothesis'),
    governorDecision: _requiredString(json, 'governor_decision'),
    productionGardenStatus: _requiredString(json, 'production_garden_status'),
  );

  final String contextSeedId;
  final String joinabilityHypothesis;
  final String governorDecision;
  final String productionGardenStatus;

  Map<String, Object?> toJson() => {
    'context_seed_id': contextSeedId,
    'joinability_hypothesis': joinabilityHypothesis,
    'governor_decision': governorDecision,
    'production_garden_status': productionGardenStatus,
  };
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be null or a non-empty string');
  }
  return value;
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('$key must be a boolean');
  }
  return value;
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) =>
    _objectMap(json[key], key);

Map<String, Object?> _objectMap(Object? value, String key) {
  if (value is! Map) {
    throw FormatException('$key must be an object');
  }
  return value.map((mapKey, mapValue) => MapEntry(mapKey.toString(), mapValue));
}

List<Object?> _requiredList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List || value.isEmpty) {
    throw FormatException('$key must be a non-empty list');
  }
  return List<Object?>.of(value);
}
