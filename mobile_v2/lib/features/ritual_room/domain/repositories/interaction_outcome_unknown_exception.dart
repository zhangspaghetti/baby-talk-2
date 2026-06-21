enum InteractionOutcomeUnknownReason {
  timeoutAfterDispatch,
  responseLostAfterDispatch,
  connectionClosedAfterDispatch,
}

/// Indicates that dispatch may have succeeded but no authoritative result arrived.
final class InteractionOutcomeUnknownException implements Exception {
  const InteractionOutcomeUnknownException({required this.reason, this.cause});

  final InteractionOutcomeUnknownReason reason;
  final Object? cause;
}
