enum InteractionCapability {
  reactionSelection,
  voiceObservation,
  freeText,
  futureSignal,
  strategyPreference,
  strategyControl,
}

/// Complete engine input catalog, independent from visible UI affordances.
final class EngineCapabilities {
  const EngineCapabilities(this.supported);

  final Set<InteractionCapability> supported;

  static const v1 = EngineCapabilities({
    InteractionCapability.reactionSelection,
    InteractionCapability.voiceObservation,
    InteractionCapability.freeText,
    InteractionCapability.futureSignal,
    InteractionCapability.strategyPreference,
  });

  bool supports(InteractionCapability capability) =>
      supported.contains(capability);
}

/// Presentation-only visibility policy. It never enters the engine graph.
final class InteractionCapabilityMask {
  const InteractionCapabilityMask(this.visible);

  final Set<InteractionCapability> visible;

  static const phase41 = InteractionCapabilityMask({
    InteractionCapability.reactionSelection,
  });

  bool exposes(InteractionCapability capability) =>
      visible.contains(capability);
}
