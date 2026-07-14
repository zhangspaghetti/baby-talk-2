import '../models/advance_result.dart';
import '../models/input_event.dart';
import '../models/product_snapshot.dart';

/// Presentation-facing access to existing interaction sessions.
abstract interface class InteractionRepository {
  Future<ProductSnapshot> getSnapshot(String interactionId);

  Future<AdvanceResult> advance({
    required String interactionId,
    required int expectedRevision,
    required InputEvent input,
  });
}
