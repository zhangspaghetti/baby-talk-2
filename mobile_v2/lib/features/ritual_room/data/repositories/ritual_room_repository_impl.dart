import '../../domain/models/active_utterance.dart';
import '../../domain/models/ritual_room_content.dart';
import '../../domain/repositories/ritual_room_repository.dart';
import '../datasources/ritual_content_api.dart';
import '../dto/ritual_room_response.dart';
import '../mappers/ritual_room_mapper.dart';

/// Delegates stable content loading and DTO-to-domain conversion.
final class RitualRoomRepositoryImpl implements RitualRoomRepository {
  RitualRoomRepositoryImpl({
    required RitualContentApi api,
    RitualRoomMapper mapper = const RitualRoomMapper(),
  }) : _api = api,
       _mapper = mapper;

  final RitualContentApi _api;
  final RitualRoomMapper _mapper;
  final Map<String, Future<RitualRoomResponse>> _responses = {};

  @override
  Future<RitualRoomContent> loadRoom(String ritualRoomId) async {
    final response = await _responseFor(ritualRoomId);
    return _mapper.toDomain(response);
  }

  @override
  Future<ActiveUtterance> resolveActiveUtterance({
    required String ritualRoomId,
    required ActiveUtteranceSlot slot,
  }) async {
    final response = await _responseFor(ritualRoomId);
    return _mapper.toActiveUtterance(response, slot);
  }

  Future<RitualRoomResponse> _responseFor(String ritualRoomId) =>
      _responses.putIfAbsent(
        ritualRoomId,
        () => _api.fetchRoom(ritualRoomId).catchError((Object error) {
          _responses.remove(ritualRoomId);
          throw error;
        }),
      );
}
