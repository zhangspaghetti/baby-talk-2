import '../dto/interaction_advance_request.dart';
import '../dto/interaction_result_response.dart';
import '../dto/interaction_snapshot_response.dart';

/// Transport-shaped boundary for reading and advancing existing sessions.
abstract interface class InteractionApi {
  Future<InteractionSnapshotResponse> getSnapshot(String interactionId);

  Future<InteractionResultResponse> advance({
    required String interactionId,
    required InteractionAdvanceRequest request,
  });
}
