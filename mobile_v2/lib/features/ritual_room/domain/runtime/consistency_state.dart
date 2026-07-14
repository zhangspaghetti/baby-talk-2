final class ConsistencyReceipt {
  const ConsistencyReceipt({
    required this.eventId,
    required this.inputFingerprint,
    required this.appliedRevision,
  });

  final String eventId;
  final String inputFingerprint;
  final int appliedRevision;

  Map<String, Object> toJson() => {
    'eventId': eventId,
    'inputFingerprint': inputFingerprint,
    'appliedRevision': appliedRevision,
  };
}

final class ConsistencyState {
  ConsistencyState._(List<ConsistencyReceipt> receipts)
    : receipts = List.unmodifiable(receipts);

  factory ConsistencyState.empty() => ConsistencyState._(const []);

  final List<ConsistencyReceipt> receipts;

  ConsistencyReceipt? findByEventId(String eventId) {
    for (final receipt in receipts) {
      if (receipt.eventId == eventId) {
        return receipt;
      }
    }
    return null;
  }

  ConsistencyState record(ConsistencyReceipt receipt) {
    if (findByEventId(receipt.eventId) != null) {
      throw StateError('Receipt already exists for ${receipt.eventId}');
    }
    return ConsistencyState._([...receipts, receipt]);
  }

  List<Map<String, Object>> toJson() =>
      receipts.map((receipt) => receipt.toJson()).toList(growable: false);
}
