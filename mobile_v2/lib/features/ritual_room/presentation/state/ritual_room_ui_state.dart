import '../../domain/models/advance_result.dart';
import '../../domain/models/product_snapshot.dart';
import '../../domain/models/ritual_room_content.dart';

sealed class RitualRoomUiState {
  const RitualRoomUiState();

  ProductSnapshot? get snapshot;
}

final class RitualRoomIdle extends RitualRoomUiState {
  const RitualRoomIdle();

  @override
  ProductSnapshot? get snapshot => null;
}

final class RitualRoomLoading extends RitualRoomUiState {
  const RitualRoomLoading();

  @override
  ProductSnapshot? get snapshot => null;
}

final class RitualRoomReady extends RitualRoomUiState {
  const RitualRoomReady({required this.room, required this.snapshot});

  final RitualRoomContent room;

  @override
  final ProductSnapshot snapshot;
}

final class RitualRoomSubmitting extends RitualRoomUiState {
  const RitualRoomSubmitting({
    required this.room,
    required this.snapshot,
    required this.selectedReaction,
  });

  final RitualRoomContent room;

  @override
  final ProductSnapshot snapshot;

  final String? selectedReaction;
}

final class RitualRoomUnknownOutcome extends RitualRoomUiState {
  const RitualRoomUnknownOutcome({
    required this.room,
    required this.snapshot,
    required this.selectedReaction,
    required this.isRetrying,
  });

  final RitualRoomContent room;

  @override
  final ProductSnapshot snapshot;

  final String? selectedReaction;
  final bool isRetrying;
}

final class RitualRoomProblem {
  const RitualRoomProblem(this.code, {this.cause});

  final AdvanceErrorCode? code;
  final Object? cause;
}

final class RitualRoomRecoverableFailure extends RitualRoomUiState {
  const RitualRoomRecoverableFailure({
    required this.room,
    required this.snapshot,
    required this.problem,
  });

  final RitualRoomContent room;

  @override
  final ProductSnapshot snapshot;

  final RitualRoomProblem problem;
}

final class RitualRoomLoadFailure extends RitualRoomUiState {
  const RitualRoomLoadFailure(this.cause);

  final Object cause;

  @override
  ProductSnapshot? get snapshot => null;
}
