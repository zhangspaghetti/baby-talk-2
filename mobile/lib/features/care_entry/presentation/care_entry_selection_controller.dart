import 'package:flutter/foundation.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';

enum CareEntrySelectionPhase { loading, selection, firstUtterance, failure }

@immutable
final class CareEntrySelectionState {
  CareEntrySelectionState({
    required this.phase,
    List<ResolvedCareEntry> entries = const <ResolvedCareEntry>[],
    this.selectedEntryId,
    this.activeEntry,
    this.errorMessage,
  }) : entries = List<ResolvedCareEntry>.unmodifiable(entries);

  factory CareEntrySelectionState.loading() =>
      CareEntrySelectionState(phase: CareEntrySelectionPhase.loading);

  final CareEntrySelectionPhase phase;
  final List<ResolvedCareEntry> entries;
  final CareEntryId? selectedEntryId;
  final ResolvedCareEntry? activeEntry;
  final String? errorMessage;

  CareFirstUtterance? get activeUtterance => activeEntry?.seed.firstUtterance;
}

final class CareEntrySelectionController extends ChangeNotifier {
  CareEntrySelectionController({
    required CareEntryRegistry registry,
    this.placement = const CareEntryPlacementId('onboarding.primary'),
    this.visibleSlots = 4,
  }) : _registry = registry;

  final CareEntryRegistry _registry;
  final CareEntryPlacementId placement;
  final int visibleSlots;
  CareEntrySelectionState _state = CareEntrySelectionState.loading();
  bool _disposed = false;
  int _loadEpoch = 0;

  CareEntrySelectionState get state => _state;

  Future<void> initialize({required DateTime localTime}) async {
    final epoch = ++_loadEpoch;
    _publish(CareEntrySelectionState.loading());
    try {
      final resolution = await _registry.resolve(
        placement: placement,
        visibleSlots: visibleSlots,
        localTime: localTime,
      );
      if (_disposed || epoch != _loadEpoch) return;
      if (resolution.entries.length != visibleSlots) {
        throw StateError('Care Entry registry 未返回 $visibleSlots 个入口。');
      }
      final recommendedId = resolution.recommendedEntryId;
      final defaultId =
          recommendedId != null &&
              resolution.entries.any((entry) => entry.id == recommendedId)
          ? recommendedId
          : resolution.entries.first.id;
      _publish(
        CareEntrySelectionState(
          phase: CareEntrySelectionPhase.selection,
          entries: resolution.entries,
          selectedEntryId: defaultId,
        ),
      );
    } on Object {
      if (_disposed || epoch != _loadEpoch) return;
      _publish(
        CareEntrySelectionState(
          phase: CareEntrySelectionPhase.failure,
          errorMessage: '暂时无法准备入口，请再试一次。',
        ),
      );
    }
  }

  void select(CareEntryId id) {
    if (_state.phase != CareEntrySelectionPhase.selection) return;
    if (_state.entries.every((entry) => entry.id != id)) {
      throw ArgumentError.value(id.value, 'id', '入口不在当前解析结果中。');
    }
    if (_state.selectedEntryId == id) return;
    _publish(
      CareEntrySelectionState(
        phase: CareEntrySelectionPhase.selection,
        entries: _state.entries,
        selectedEntryId: id,
      ),
    );
  }

  void startSelected() {
    if (_state.phase != CareEntrySelectionPhase.selection) return;
    final selectedId = _state.selectedEntryId;
    if (selectedId == null) {
      throw StateError('没有可启动的 Care Entry。');
    }
    final selected = _state.entries.singleWhere(
      (entry) => entry.id == selectedId,
    );
    _publish(
      CareEntrySelectionState(
        phase: CareEntrySelectionPhase.firstUtterance,
        entries: _state.entries,
        selectedEntryId: selectedId,
        activeEntry: selected,
      ),
    );
  }

  void _publish(CareEntrySelectionState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadEpoch += 1;
    super.dispose();
  }
}
