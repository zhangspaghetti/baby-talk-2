import '../../domain/models/advance_result.dart';
import '../../domain/models/input_event.dart';
import '../../domain/models/product_snapshot.dart';
import '../../domain/repositories/interaction_repository.dart';
import '../datasources/interaction_api.dart';
import '../dto/interaction_advance_request.dart';
import '../mappers/interaction_mapper.dart';

/// Conversion-only interaction repository with no product-state ownership.
final class InteractionRepositoryImpl implements InteractionRepository {
  const InteractionRepositoryImpl({
    required InteractionApi api,
    required InteractionMapper mapper,
  }) : _api = api,
       _mapper = mapper;

  final InteractionApi _api;
  final InteractionMapper _mapper;

  @override
  Future<ProductSnapshot> getSnapshot(String interactionId) async {
    final response = await _api.getSnapshot(interactionId);
    return _mapper.snapshotToDomain(response);
  }

  @override
  Future<AdvanceResult> advance({
    required String interactionId,
    required int expectedRevision,
    required InputEvent input,
  }) async {
    final response = await _api.advance(
      interactionId: interactionId,
      request: InteractionAdvanceRequest(
        expectedRevision: expectedRevision,
        input: _mapper.inputFromDomain(input),
      ),
    );
    return _mapper.resultToDomain(response);
  }
}
