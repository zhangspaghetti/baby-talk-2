import '../models/active_utterance.dart';

abstract interface class ActiveUtteranceSource {
  Future<ActiveUtterance> resolveActiveUtterance({
    required String ritualRoomId,
    required ActiveUtteranceSlot slot,
  });
}
