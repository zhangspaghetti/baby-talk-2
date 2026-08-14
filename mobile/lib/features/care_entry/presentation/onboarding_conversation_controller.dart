import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';

typedef OnboardingConversationClock = DateTime Function();
typedef OnboardingConversationIdGenerator = String Function();

@immutable
final class OnboardingConversationState {
  OnboardingConversationState({
    required this.phase,
    List<ResolvedCareEntry> entries = const <ResolvedCareEntry>[],
    this.selectedEntryId,
    this.activeEntry,
    this.nextSupport,
    this.selectedReaction,
    this.phraseSaidEventId,
    this.gardenTraceId,
    this.errorMessage,
  }) : entries = List<ResolvedCareEntry>.unmodifiable(entries);

  factory OnboardingConversationState.loading() =>
      OnboardingConversationState(phase: OnboardingConversationPhase.loading);

  final OnboardingConversationPhase phase;
  final List<ResolvedCareEntry> entries;
  final CareEntryId? selectedEntryId;
  final ResolvedCareEntry? activeEntry;
  final CareNextSupportUtterance? nextSupport;
  final CareReaction? selectedReaction;
  final String? phraseSaidEventId;
  final String? gardenTraceId;
  final String? errorMessage;

  CareFirstUtterance? get activeUtterance => activeEntry?.seed.firstUtterance;
}

final class OnboardingConversationController extends ChangeNotifier {
  OnboardingConversationController({
    required CareEntryRegistry registry,
    required OnboardingConversationRepository repository,
    required OnboardingDelayScheduler scheduler,
    required OnboardingConversationClock clock,
    required OnboardingConversationIdGenerator idGenerator,
    this.placement = const CareEntryPlacementId('onboarding.primary'),
    this.visibleSlots = 4,
  }) : _registry = registry,
       _repository = repository,
       _scheduler = scheduler,
       _clock = clock,
       _idGenerator = idGenerator;

  final CareEntryRegistry _registry;
  final OnboardingConversationRepository _repository;
  final OnboardingDelayScheduler _scheduler;
  final OnboardingConversationClock _clock;
  final OnboardingConversationIdGenerator _idGenerator;
  final CareEntryPlacementId placement;
  final int visibleSlots;

  OnboardingConversationState _state = OnboardingConversationState.loading();
  OnboardingConversationSnapshot? _checkpoint;
  CareEntryResolution? _resolution;
  OnboardingScheduledTask? _reactionTimeout;
  bool _disposed = false;
  int _operationEpoch = 0;
  int _reactionEpoch = 0;

  OnboardingConversationState get state => _state;

  Future<void> initialize({required DateTime localTime}) async {
    final epoch = ++_operationEpoch;
    _publish(OnboardingConversationState.loading());
    try {
      final resolution = await _registry.resolve(
        placement: placement,
        visibleSlots: visibleSlots,
        localTime: localTime,
      );
      final restored = await _repository.read();
      if (_disposed || epoch != _operationEpoch) return;
      _resolution = resolution;
      final checkpoint = restored ?? _initialCheckpoint(resolution);
      final persisted = restored == null
          ? await _repository.save(checkpoint)
          : checkpoint;
      if (_disposed || epoch != _operationEpoch) return;
      _applyCheckpoint(persisted);
      if (persisted.phase == OnboardingCheckpointPhase.reactionPrompt) {
        final reaction = persisted.selectedReaction;
        if (reaction == null) {
          _scheduleReactionTimeout();
        } else {
          final reactionEpoch = ++_reactionEpoch;
          _reactionTimeout = _scheduler.schedule(
            const Duration(milliseconds: 500),
            () => unawaited(
              _resolveNextSupport(reaction, reactionEpoch: reactionEpoch),
            ),
          );
        }
      }
    } on Object {
      if (_disposed || epoch != _operationEpoch) return;
      _publish(
        OnboardingConversationState(
          phase: OnboardingConversationPhase.failure,
          errorMessage: '暂时无法准备入口，请再试一次。',
        ),
      );
    }
  }

  Future<void> select(CareEntryId id) async {
    if (_state.phase != OnboardingConversationPhase.selection) return;
    final resolution = _requireResolution();
    if (resolution.entries.every((entry) => entry.id != id)) {
      throw ArgumentError.value(id.value, 'id', '入口不在当前解析结果中。');
    }
    if (_state.selectedEntryId == id) return;
    final previous = _requireCheckpoint();
    final checkpoint = previous.copyWith(selectedEntryId: id);
    try {
      final persisted = await _repository.save(checkpoint);
      if (_disposed) return;
      _applyCheckpoint(persisted);
    } on Object {
      if (_disposed) return;
      _publish(
        _stateFor(
          previous,
          OnboardingConversationPhase.selection,
          errorMessage: '这一刻还没保存好，请再试一次。',
        ),
      );
    }
  }

  Future<void> startSelected() async {
    if (_state.phase != OnboardingConversationPhase.selection) return;
    final selectedId = _state.selectedEntryId;
    if (selectedId == null) {
      throw StateError('没有可启动的 Care Entry。');
    }
    final previous = _requireCheckpoint();
    final checkpoint = previous.copyWith(
      phase: OnboardingCheckpointPhase.firstUtterance,
      activeEntryId: selectedId,
    );
    try {
      final persisted = await _repository.save(checkpoint);
      if (_disposed) return;
      _applyCheckpoint(persisted);
    } on Object {
      if (_disposed) return;
      _publish(
        _stateFor(
          previous,
          OnboardingConversationPhase.selection,
          errorMessage: '这一刻还没保存好，请再试一次。',
        ),
      );
    }
  }

  Future<void> markPhraseSaid() async {
    if (_state.phase != OnboardingConversationPhase.firstUtterance) return;
    final checkpoint = _requireCheckpoint();
    _publish(
      _stateFor(checkpoint, OnboardingConversationPhase.savingPhraseSaid),
    );
    try {
      final persisted = await _repository.recordPhraseSaid(
        checkpoint: checkpoint,
        eventId: _idGenerator(),
        occurredAt: _clock().toUtc(),
      );
      if (_disposed) return;
      _applyCheckpoint(persisted);
      _scheduleReactionTimeout();
    } on Object {
      if (_disposed) return;
      _publish(
        _stateFor(
          checkpoint,
          OnboardingConversationPhase.firstUtterance,
          errorMessage: '刚才这句还没记好，请再试一次。',
        ),
      );
    }
  }

  Future<void> selectReaction(
    CareReaction reaction, {
    String? otherText,
  }) async {
    if (_state.phase != OnboardingConversationPhase.reactionPrompt) return;
    final normalizedOtherText = otherText?.trim();
    final hasOtherText = normalizedOtherText?.isNotEmpty == true;
    if (hasOtherText && reaction != CareReaction.other) {
      throw ArgumentError.value(
        otherText,
        'otherText',
        '只有 other reaction 可以携带文字。',
      );
    }
    if (normalizedOtherText != null && normalizedOtherText.length > 200) {
      throw ArgumentError.value(otherText, 'otherText', '最多 200 个字符。');
    }
    final reactionEpoch = ++_reactionEpoch;
    _reactionTimeout?.cancel();
    var persistenceSucceeded = false;
    var delayElapsed = false;
    _reactionTimeout = _scheduler.schedule(
      const Duration(milliseconds: 500),
      () {
        delayElapsed = true;
        if (persistenceSucceeded) {
          unawaited(
            _resolveNextSupport(reaction, reactionEpoch: reactionEpoch),
          );
        }
      },
    );
    final checkpoint = _requireCheckpoint().copyWith(
      selectedReaction: reaction,
    );
    try {
      final persisted = await _repository.save(checkpoint);
      if (_disposed || reactionEpoch != _reactionEpoch) return;
      _applyCheckpoint(persisted);
      persistenceSucceeded = true;
      if (delayElapsed) {
        await _resolveNextSupport(reaction, reactionEpoch: reactionEpoch);
      }
    } on Object {
      if (_disposed || reactionEpoch != _reactionEpoch) return;
      _reactionTimeout?.cancel();
      _publish(
        _stateFor(
          _requireCheckpoint(),
          OnboardingConversationPhase.reactionPrompt,
          errorMessage: '宝宝反应还没记好，请再试一次。',
        ),
      );
    }
  }

  Future<void> continueWithoutReaction() {
    if (_state.phase != OnboardingConversationPhase.reactionPrompt) {
      return Future<void>.value();
    }
    _reactionTimeout?.cancel();
    final reactionEpoch = ++_reactionEpoch;
    return _resolveNextSupport(null, reactionEpoch: reactionEpoch);
  }

  Future<void> complete() async {
    if (_state.phase == OnboardingConversationPhase.completed ||
        _state.phase == OnboardingConversationPhase.completing) {
      return;
    }
    final checkpoint = _requireCheckpoint();
    if (checkpoint.phraseSaidEventId == null) {
      throw StateError('PhraseSaid 尚未持久化，不能完成 Care Turn。');
    }
    _reactionEpoch += 1;
    _reactionTimeout?.cancel();
    _publish(_stateFor(checkpoint, OnboardingConversationPhase.completing));
    try {
      final persisted = await _repository.complete(
        checkpoint: checkpoint,
        completionId: _idGenerator(),
        completedAt: _clock().toUtc(),
      );
      if (_disposed) return;
      _applyCheckpoint(persisted);
    } on Object {
      if (_disposed) return;
      _publish(
        _stateFor(
          checkpoint,
          _viewPhase(checkpoint.phase),
          errorMessage: '这一刻还没保存好，请再试一次。',
        ),
      );
    }
  }

  OnboardingConversationSnapshot _initialCheckpoint(
    CareEntryResolution resolution,
  ) {
    if (resolution.entries.length != visibleSlots) {
      throw StateError('Care Entry registry 未返回 $visibleSlots 个入口。');
    }
    final recommendedId = resolution.recommendedEntryId;
    final selectedId =
        recommendedId != null &&
            resolution.entries.any((entry) => entry.id == recommendedId)
        ? recommendedId
        : resolution.entries.first.id;
    return OnboardingConversationSnapshot(
      registryRevision: resolution.revision,
      phase: OnboardingCheckpointPhase.selection,
      selectedEntryId: selectedId,
    );
  }

  void _applyCheckpoint(OnboardingConversationSnapshot checkpoint) {
    _checkpoint = checkpoint;
    _publish(_stateFor(checkpoint, _viewPhase(checkpoint.phase)));
  }

  OnboardingConversationState _stateFor(
    OnboardingConversationSnapshot checkpoint,
    OnboardingConversationPhase phase, {
    String? errorMessage,
  }) {
    final resolution = _requireResolution();
    final activeId = checkpoint.activeEntryId;
    final activeEntry = activeId == null
        ? null
        : resolution.entries.firstWhere((entry) => entry.id == activeId);
    CareNextSupportUtterance? nextSupport;
    final nextSupportId = checkpoint.nextSupportId;
    if (activeEntry != null && nextSupportId != null) {
      final candidates = <CareNextSupportUtterance>[
        activeEntry.seed.nextSupports.whenAbsent,
        ...activeEntry.seed.nextSupports.byReaction.values,
      ];
      nextSupport = candidates.firstWhere(
        (candidate) => candidate.id == nextSupportId,
      );
    }
    return OnboardingConversationState(
      phase: phase,
      entries: resolution.entries,
      selectedEntryId: checkpoint.selectedEntryId,
      activeEntry: activeEntry,
      nextSupport: nextSupport,
      selectedReaction: checkpoint.selectedReaction,
      phraseSaidEventId: checkpoint.phraseSaidEventId,
      gardenTraceId: checkpoint.gardenTraceId,
      errorMessage: errorMessage,
    );
  }

  void _scheduleReactionTimeout() {
    _reactionTimeout?.cancel();
    final reactionEpoch = ++_reactionEpoch;
    _reactionTimeout = _scheduler.schedule(
      const Duration(seconds: 4),
      () => unawaited(_resolveNextSupport(null, reactionEpoch: reactionEpoch)),
    );
  }

  Future<void> _resolveNextSupport(
    CareReaction? reaction, {
    required int reactionEpoch,
  }) async {
    if (reactionEpoch != _reactionEpoch ||
        _state.phase != OnboardingConversationPhase.reactionPrompt) {
      return;
    }
    final checkpoint = _requireCheckpoint();
    final activeEntry = _state.activeEntry;
    if (activeEntry == null) return;
    final support = activeEntry.seed.nextSupports.resolve(reaction);
    final next = checkpoint.copyWith(
      phase: OnboardingCheckpointPhase.nextSupportReady,
      selectedReaction: reaction,
      nextSupportId: support.id,
    );
    try {
      final persisted = await _repository.save(next);
      if (_disposed || reactionEpoch != _reactionEpoch) return;
      _applyCheckpoint(persisted);
    } on Object {
      if (_disposed || reactionEpoch != _reactionEpoch) return;
      _publish(
        _stateFor(
          checkpoint,
          OnboardingConversationPhase.reactionPrompt,
          errorMessage: '下一句还没准备好，请再试一次。',
        ),
      );
    }
  }

  CareEntryResolution _requireResolution() =>
      _resolution ?? (throw StateError('Care Entry registry 尚未准备。'));

  OnboardingConversationSnapshot _requireCheckpoint() =>
      _checkpoint ?? (throw StateError('Onboarding checkpoint 尚未准备。'));

  void _publish(OnboardingConversationState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _operationEpoch += 1;
    _reactionEpoch += 1;
    _reactionTimeout?.cancel();
    super.dispose();
  }
}

OnboardingConversationPhase _viewPhase(
  OnboardingCheckpointPhase phase,
) => switch (phase) {
  OnboardingCheckpointPhase.selection => OnboardingConversationPhase.selection,
  OnboardingCheckpointPhase.firstUtterance =>
    OnboardingConversationPhase.firstUtterance,
  OnboardingCheckpointPhase.reactionPrompt =>
    OnboardingConversationPhase.reactionPrompt,
  OnboardingCheckpointPhase.nextSupportReady =>
    OnboardingConversationPhase.nextSupportReady,
  OnboardingCheckpointPhase.completed => OnboardingConversationPhase.completed,
};

final class TimerOnboardingDelayScheduler implements OnboardingDelayScheduler {
  const TimerOnboardingDelayScheduler();

  @override
  OnboardingScheduledTask schedule(Duration delay, void Function() action) =>
      _TimerScheduledTask(Timer(delay, action));
}

final class _TimerScheduledTask implements OnboardingScheduledTask {
  const _TimerScheduledTask(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}
