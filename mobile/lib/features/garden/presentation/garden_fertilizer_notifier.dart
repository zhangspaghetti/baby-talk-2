import 'package:flutter/foundation.dart';
import 'package:mobile/features/garden/data/repositories/garden_fertilizer_repository.dart';
import 'package:mobile/features/garden/data/remote/garden_fertilizer_api_service.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_flower_stage.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_state.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';

/// Composes the persisted fertilizer state with the garden growth snapshot
/// (practice traces) into a [GardenFertilizerViewState] for the UI.
class GardenFertilizerNotifier extends ChangeNotifier {
  GardenFertilizerNotifier({
    required Future<GardenFertilizerRepository> repositoryFuture,
    required GardenGrowthNotifier growthNotifier,
  }) : _repositoryFuture = repositoryFuture,
       _growthNotifier = growthNotifier {
    _growthNotifier.addListener(_onGrowthChanged);
  }

  final Future<GardenFertilizerRepository> _repositoryFuture;
  final GardenGrowthNotifier _growthNotifier;

  GardenFertilizerRepository? _repository;
  FertilizerState _state = const FertilizerState.initial();
  bool _stateLoaded = false;
  bool _disposed = false;
  String? _errorMessage;
  Future<void> Function()? _retryOperation;

  /// Set when [apply] pushes the flower into a higher stage; consumed by the UI
  /// to trigger a one-shot celebration (confetti). Null when nothing to show.
  FertilizerFlowerStage? _celebrationStage;
  FertilizerFlowerStage? get celebrationStage => _celebrationStage;

  /// Clears the pending celebration without notifying listeners (avoids loops
  /// when called from a listener callback).
  void consumeCelebration() => _celebrationStage = null;

  GardenFertilizerViewState _view = const GardenFertilizerViewState.loading();
  GardenFertilizerViewState get view => _view;

  Future<void> initialize() => _initialize(force: false);

  Future<void> _initialize({required bool force}) async {
    if (_stateLoaded && !force) return;
    try {
      final repository = await _repositoryFuture;
      _repository = repository;
      _state = await repository.load();
      _clearFailure();
    } on Object catch (error) {
      _state = const FertilizerState.initial();
      _recordFailure(error, retry: () => _initialize(force: true));
    } finally {
      _stateLoaded = true;
      _recompute();
    }
  }

  Future<void> claim(String eventKey) async {
    final repository = _repository;
    if (repository == null) return;
    final requestId = repository.createRequestId();
    await _claim(eventKey, requestId: requestId);
  }

  Future<void> _claim(String eventKey, {required String requestId}) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      _state = await repository.claim(eventKey, requestId: requestId);
    } on Object catch (error) {
      _recordFailure(
        error,
        retry: () => _claim(eventKey, requestId: requestId),
      );
      _recompute();
      return;
    }
    _clearFailure();
    _recompute();
  }

  Future<void> apply() async {
    final repository = _repository;
    if (repository == null || _state.backpackCount <= 0) return;
    final requestId = repository.createRequestId();
    await _apply(requestId: requestId);
  }

  Future<void> _apply({required String requestId}) async {
    final repository = _repository;
    if (repository == null || _state.backpackCount <= 0) return;
    final previousStage = resolveFertilizerStage(_state.appliedCount).stage;
    try {
      _state = await repository.apply(requestId: requestId);
    } on Object catch (error) {
      _recordFailure(error, retry: () => _apply(requestId: requestId));
      _recompute();
      return;
    }
    _clearFailure();
    final newStage = resolveFertilizerStage(_state.appliedCount).stage;
    if (newStage.index > previousStage.index) {
      _celebrationStage = newStage;
    }
    _recompute();
  }

  Future<void> retryLastOperation() async {
    final retry = _retryOperation;
    if (retry == null) return;
    await retry();
  }

  void _recordFailure(Object error, {required Future<void> Function() retry}) {
    _errorMessage = _visibleFailureMessage(error);
    _retryOperation = retry;
  }

  void _clearFailure() {
    _errorMessage = null;
    _retryOperation = null;
  }

  void _onGrowthChanged() => _recompute();

  void _recompute() {
    if (_disposed) return;

    final growthLoading =
        _growthNotifier.status == GardenGrowthLoadStatus.idle ||
        _growthNotifier.status == GardenGrowthLoadStatus.loading;

    if (!_stateLoaded || growthLoading) {
      _view = const GardenFertilizerViewState.loading();
      notifyListeners();
      return;
    }

    final entries =
        _growthNotifier.snapshot.diaryEntries
            .where((e) => e.kind == GrowthDiaryEntryKind.practice)
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    final pending = <FertilizerPack>[];
    final claimed = <FertilizerPack>[];
    for (final entry in entries) {
      final isClaimed = _state.claimedEventKeys.contains(entry.entryId);
      final pack = FertilizerPack(
        eventKey: entry.entryId,
        title: entry.title,
        detail: entry.body,
        occurredAt: entry.occurredAt,
        claimed: isClaimed,
      );
      (isClaimed ? claimed : pending).add(pack);
    }

    _view = GardenFertilizerViewState(
      isLoading: false,
      pendingPacks: List.unmodifiable(pending),
      claimedPacks: List.unmodifiable(claimed),
      backpackCount: _state.backpackCount,
      stageInfo: resolveFertilizerStage(_state.appliedCount),
      errorMessage: _errorMessage,
      canRetry: _retryOperation != null,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _growthNotifier.removeListener(_onGrowthChanged);
    super.dispose();
  }
}

String _visibleFailureMessage(Object error) {
  if (error is GardenFertilizerApiException) {
    switch (error.kind) {
      case GardenFertilizerApiFailureKind.network:
        return '网络不可用，请检查网络后重试。';
      case GardenFertilizerApiFailureKind.timeout:
        return '请求超时，请检查网络后重试。';
      case GardenFertilizerApiFailureKind.http:
        return error.statusCode == 401 ? error.message : '花园状态暂时无法更新，请稍后重试。';
      case GardenFertilizerApiFailureKind.malformed:
        return '花园状态暂时无法更新，请稍后重试。';
    }
  }
  if (error is GardenFertilizerRepositoryException) return error.message;
  return '花园状态暂时无法更新，请稍后重试。';
}
