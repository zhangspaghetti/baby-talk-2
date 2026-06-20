import '../models/ritual_room_content.dart';

/// Loads stable Ritual Room content without exposing transport structures.
abstract interface class RitualRoomRepository {
  Future<RitualRoomContent> loadRoom(String ritualRoomId);
}
