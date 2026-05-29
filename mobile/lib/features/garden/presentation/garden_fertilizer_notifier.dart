import 'package:flutter/foundation.dart';
import 'package:mobile/features/garden/data/repositories/garden_fertilizer_repository.dart';
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

  /// Set when [apply] pushes the flower into a higher stage; consumed by the UI
  /// to trigger a one-shot celebration (confetti). Null when nothing to show.
  FertilizerFlowerStage? _celebrationStage;
  FertilizerFlowerStage? get celebrationStage => _celebrationStage;

  /// Clears the pending celebration without notifying listeners (avoids loops
  /// when called from a listener callback).
  void consumeCelebration() => _celebrationStage = null;

  GardenFertilizerViewState _view = const GardenFertilizerViewState.loading();
  GardenFertilizerViewState get view => _view;

  Future<void> initialize() async {
    if (_stateLoaded) return;
    try {
      final repository = await _repositoryFuture;
      _repository = repository;
      _state = await repository.load();
    } catch (_) {
      _state = const FertilizerState.initial();
    } finally {
      _stateLoaded = true;
      _recompute();
    }
  }

  Future<void> claim(String eventKey) async {
    final repository = _repository;
    if (repository == null) return;
    _state = await repository.claim(eventKey);
    _recompute();
  }

  Future<void> apply() async {
    final repository = _repository;
    if (repository == null || _state.backpackCount <= 0) return;
    final previousStage = resolveFertilizerStage(_state.appliedCount).stage;
    _state = await repository.apply();
    final newStage = resolveFertilizerStage(_state.appliedCount).stage;
    if (newStage.index > previousStage.index) {
      _celebrationStage = newStage;
    }
    _recompute();
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

    final entries = _growthNotifier.snapshot.diaryEntries
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
