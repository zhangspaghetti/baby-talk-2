import '../../domain/models/ritual_room_content.dart';
import '../../domain/repositories/ritual_room_repository.dart';
import '../datasources/ritual_content_api.dart';
import '../mappers/ritual_room_mapper.dart';

/// Delegates stable content loading and DTO-to-domain conversion.
final class RitualRoomRepositoryImpl implements RitualRoomRepository {
  const RitualRoomRepositoryImpl({
    required RitualContentApi api,
    RitualRoomMapper mapper = const RitualRoomMapper(),
  }) : _api = api,
       _mapper = mapper;

  final RitualContentApi _api;
  final RitualRoomMapper _mapper;

  @override
  Future<RitualRoomContent> loadRoom(String ritualRoomId) async {
    final response = await _api.fetchRoom(ritualRoomId);
    return _mapper.toDomain(response);
  }
}
