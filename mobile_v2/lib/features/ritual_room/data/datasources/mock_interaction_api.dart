import '../../domain/engine/interaction_engine_port.dart';
import '../dto/interaction_advance_request.dart';
import '../dto/interaction_result_response.dart';
import '../dto/interaction_snapshot_response.dart';
import '../mappers/interaction_mapper.dart';
import 'interaction_api.dart';

/// In-process transport adapter over the sole interaction engine authority.
final class MockInteractionApi implements InteractionApi {
  const MockInteractionApi({
    required InteractionEnginePort engine,
    required InteractionMapper mapper,
  }) : _engine = engine,
       _mapper = mapper;

  final InteractionEnginePort _engine;
  final InteractionMapper _mapper;

  @override
  Future<InteractionSnapshotResponse> getSnapshot(String interactionId) async {
    final snapshot = await _engine.getSnapshot(interactionId);
    if (snapshot == null) {
      throw StateError('interaction_not_found');
    }
    return _mapper.snapshotFromDomain(snapshot);
  }

  @override
  Future<InteractionResultResponse> advance({
    required String interactionId,
    required InteractionAdvanceRequest request,
  }) async {
    final result = await _engine.advance(
      interactionId: interactionId,
      expectedRevision: request.expectedRevision,
      input: _mapper.inputToDomain(request.input),
    );
    return _mapper.resultFromDomain(result);
  }
}
