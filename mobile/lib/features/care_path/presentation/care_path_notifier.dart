import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/care_entry/contract/onboarding_care_turn_continuation.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/care_path_view_model.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

class CarePathNotifier extends ChangeNotifier {
  CarePathNotifier({required CarePathRepository repository})
    : _repository = repository;

  final CarePathRepository _repository;

  CarePathViewModel _viewModel = CarePathViewModel.idle();
  bool _disposed = false;
  Future<void>? _operationFuture;
  int _operationGeneration = 0;

  CarePathViewModel get viewModel => _viewModel;
  CareTurnSnapshot? get snapshot => _viewModel.snapshot;
  CareTurnPhase get phase => _viewModel.phase;
  String? get message => _viewModel.message;
  bool get isBusy =>
      _viewModel.phase == CareTurnPhase.loading ||
      _viewModel.phase == CareTurnPhase.savingTrace;

  Future<void> initialize({String? starterSpaceId, String? starterActivityId}) {
    if (!_viewModel.isIdle || _operationFuture != null) {
      return _operationFuture ?? Future.value();
    }
    return loadCurrentUtterance(
      starterSpaceId: starterSpaceId,
      starterActivityId: starterActivityId,
    );
  }

  Future<void> loadCurrentUtterance({
    String? starterSpaceId,
    String? starterActivityId,
  }) {
    return _runSnapshotOperation(
      busyPhase: CareTurnPhase.loading,
      loader: () => _repository.loadCurrentTurn(
        starterSpaceId: starterSpaceId,
        starterActivityId: starterActivityId,
      ),
    );
  }

  Future<void> startMoment({
    required String spaceId,
    required String activityId,
    bool bundledOnly = false,
  }) {
    return _runSnapshotOperation(
      busyPhase: CareTurnPhase.loading,
      replaceRunning: true,
      loader: () => _repository.startMoment(
        spaceId: spaceId,
        activityId: activityId,
        bundledOnly: bundledOnly,
      ),
    );
  }

  Future<void> startGeneratedMoment({required String generatedContentId}) {
    return _runSnapshotOperation(
      busyPhase: CareTurnPhase.loading,
      replaceRunning: true,
      loader: () => _repository.startGeneratedMoment(
        generatedContentId: generatedContentId,
      ),
    );
  }

  Future<void> startContinuation(OnboardingCareTurnHandoff handoff) {
    return _runSnapshotOperation(
      busyPhase: CareTurnPhase.loading,
      replaceRunning: true,
      loader: () => _repository.startContinuation(handoff),
    );
  }

  Future<void> selectReaction(
    BabyReactionType reactionType, {
    DateTime? clientTimestamp,
    String? localEventId,
  }) {
    final turn = _viewModel.snapshot;
    if (turn == null) {
      _viewModel = _viewModel.copyWith(
        phase: CareTurnPhase.heldWithFallback,
        message: '当前照护内容还没准备好，请稍后再试。',
      );
      notifyListeners();
      return Future.value();
    }
    if (turn.currentUtterance == null) {
      _applySnapshot(
        turn.copyWith(
          phase: CareTurnPhase.heldWithFallback,
          selectedReaction: reactionType,
          message: '当前照护内容暂时无法记录回应。',
          failureKind: CareTurnFailureKind.reactionRejected,
        ),
      );
      return Future.value();
    }
    if (turn.phase != CareTurnPhase.reactionPrompt) {
      final message = turn.phase == CareTurnPhase.utteranceReady
          ? '请先说完这句，再记录宝宝的回应。'
          : '这一句已经完成，请先继续下一句。';
      _applySnapshot(turn.copyWith(message: message));
      return Future.value();
    }
    if (!_viewModel.canSelectReaction) {
      _viewModel = _viewModel.copyWith(message: '当前 turn 暂时不能记录回应。');
      notifyListeners();
      return Future.value();
    }

    return _runSnapshotOperation(
      busyPhase: CareTurnPhase.savingTrace,
      busySnapshot: turn.copyWith(
        phase: CareTurnPhase.savingTrace,
        selectedReaction: reactionType,
        message: null,
      ),
      loader: () => _repository.recordReaction(
        turn: turn,
        reactionType: reactionType,
        clientTimestamp: clientTimestamp,
        localEventId: localEventId,
      ),
    );
  }

  void markSaid() {
    final turn = _viewModel.snapshot;
    if (turn == null || turn.currentUtterance == null) {
      return;
    }
    if (turn.phase == CareTurnPhase.reactionPrompt) {
      if (_viewModel.message != turn.message) {
        _applySnapshot(turn.copyWith(message: turn.message));
      }
      return;
    }
    if (turn.phase != CareTurnPhase.utteranceReady) {
      return;
    }

    _applySnapshot(
      turn.copyWith(
        phase: CareTurnPhase.reactionPrompt,
        selectedReaction: null,
        nextSupportUtterance: null,
        traceEventKey: null,
        latestGardenImpact: null,
        message: null,
      ),
    );
  }

  Future<void> restorePendingReaction({
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
  }) {
    return _runSnapshotOperation(
      busyPhase: CareTurnPhase.loading,
      replaceRunning: true,
      loader: () => _repository.restorePendingReaction(
        spaceId: spaceId,
        activityId: activityId,
        phraseId: phraseId,
        reactionType: reactionType,
      ),
    );
  }

  Future<void> restoreConfirmedReaction(InteractionEventPayload event) {
    return _runSnapshotOperation(
      busyPhase: CareTurnPhase.loading,
      replaceRunning: true,
      loader: () => _repository.restoreConfirmedReaction(event),
    );
  }

  void resetToSafeEmpty() {
    _operationGeneration += 1;
    _operationFuture = null;
    _viewModel = CarePathViewModel.idle();
    notifyListeners();
  }

  Future<void> _runSnapshotOperation({
    required CareTurnPhase busyPhase,
    required Future<CareTurnSnapshot> Function() loader,
    CareTurnSnapshot? busySnapshot,
    bool replaceRunning = false,
  }) {
    if (_disposed) {
      return Future.value();
    }
    final running = _operationFuture;
    if (running != null && !replaceRunning) {
      return running;
    }

    if (busySnapshot != null) {
      _viewModel = CarePathViewModel.fromSnapshot(busySnapshot);
    } else {
      _viewModel = _viewModel.copyWith(phase: busyPhase, message: null);
    }
    notifyListeners();

    final generation = ++_operationGeneration;
    final future = _completeSnapshotOperation(loader, generation: generation);
    _operationFuture = future;
    return future.whenComplete(() {
      if (identical(_operationFuture, future)) {
        _operationFuture = null;
      }
    });
  }

  Future<void> _completeSnapshotOperation(
    Future<CareTurnSnapshot> Function() loader, {
    required int generation,
  }) async {
    try {
      final nextSnapshot = await loader();
      if (_disposed || generation != _operationGeneration) {
        return;
      }
      _applySnapshot(nextSnapshot);
    } catch (_) {
      if (_disposed || generation != _operationGeneration) {
        return;
      }
      final failedSnapshot = _viewModel.snapshot?.copyWith(
        phase: CareTurnPhase.error,
        message: '暂时无法完成这次回应，请再试一次。',
        failureKind: CareTurnFailureKind.localStateUnavailable,
      );
      _viewModel = failedSnapshot == null
          ? _viewModel.copyWith(
              phase: CareTurnPhase.error,
              message: '当前照护内容暂时无法加载。',
            )
          : CarePathViewModel.fromSnapshot(failedSnapshot);
      notifyListeners();
    }
  }

  void _applySnapshot(CareTurnSnapshot? snapshot) {
    if (snapshot == null) {
      return;
    }
    _viewModel = CarePathViewModel.fromSnapshot(snapshot);
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
