import '../dto/ritual_room_response.dart';

/// Backend-shaped boundary for stable Ritual Room content.
abstract interface class RitualContentApi {
  Future<RitualRoomResponse> fetchRoom(String ritualRoomId);
}
