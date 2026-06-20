import '../models/advance_result.dart';
import '../models/input_event.dart';
import '../models/product_snapshot.dart';

/// Replaceable API-shaped boundary for reading and advancing existing sessions.
abstract interface class InteractionEnginePort {
  Future<ProductSnapshot?> getSnapshot(String interactionId);

  Future<AdvanceResult> advance({
    required String interactionId,
    required int expectedRevision,
    required InputEvent input,
  });
}
