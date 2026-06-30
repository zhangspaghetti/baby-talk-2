import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

class CarePathViewModel {
  const CarePathViewModel({
    required this.snapshot,
    required this.phase,
    required this.message,
  });

  factory CarePathViewModel.idle() {
    return const CarePathViewModel(
      snapshot: null,
      phase: CareTurnPhase.idle,
      message: null,
    );
  }

  final CareTurnSnapshot? snapshot;
  final CareTurnPhase phase;
  final String? message;

  CareMoment? get moment => snapshot?.moment;
  CareUtterance? get currentUtterance => snapshot?.currentUtterance;
  BabyReactionType? get selectedReaction => snapshot?.selectedReaction;
  CareUtterance? get nextSupportUtterance => snapshot?.nextSupportUtterance;
  String? get traceEventKey => snapshot?.traceEventKey;
  LatestPracticeImpact? get latestGardenImpact => snapshot?.latestGardenImpact;

  bool get isIdle => phase == CareTurnPhase.idle;
  bool get isLoading => phase == CareTurnPhase.loading;
  bool get isSavingTrace => phase == CareTurnPhase.savingTrace;
  bool get hasCurrentUtterance => currentUtterance != null;
  bool get hasNextSupport => nextSupportUtterance != null;
  bool get hasError => phase == CareTurnPhase.error;
  bool get isHeldWithFallback => phase == CareTurnPhase.heldWithFallback;
  bool get canSelectReaction =>
      currentUtterance != null &&
      (phase == CareTurnPhase.utteranceReady ||
          phase == CareTurnPhase.reactionPrompt);

  CarePathViewModel copyWith({
    Object? snapshot = _unset,
    CareTurnPhase? phase,
    Object? message = _unset,
  }) {
    return CarePathViewModel(
      snapshot: identical(snapshot, _unset)
          ? this.snapshot
          : snapshot as CareTurnSnapshot?,
      phase: phase ?? this.phase,
      message: identical(message, _unset) ? this.message : message as String?,
    );
  }

  factory CarePathViewModel.fromSnapshot(CareTurnSnapshot snapshot) {
    return CarePathViewModel(
      snapshot: snapshot,
      phase: snapshot.phase,
      message: snapshot.message,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CarePathViewModel &&
            other.snapshot == snapshot &&
            other.phase == phase &&
            other.message == message;
  }

  @override
  int get hashCode => Object.hash(snapshot, phase, message);
}

const Object _unset = Object();
