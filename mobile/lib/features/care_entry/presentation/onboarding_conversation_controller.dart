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
    this.firstUtterance,
    this.conversationId,
    this.conversationExpiresAt,
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
  final OnboardingUtterance? firstUtterance;
  final String? conversationId;
  final DateTime? conversationExpiresAt;
  final String? errorMessage;

  OnboardingUtterance? get activeUtterance => firstUtterance;
}

final class OnboardingConversationController extends ChangeNotifier {
  OnboardingConversationController({
    required CareEntryRegistry registry,
    required OnboardingConversationRepository repository,
    required OnboardingDelayScheduler scheduler,
    required OnboardingConversationClock clock,
    required OnboardingConversationIdGenerator idGenerator,
    GuestOnboardingConversationGateway? conversationGateway,
    OnboardingInstallationIdLoader? installationIdLoader,
    this.placement = const CareEntryPlacementId('onboarding.primary'),
    this.visibleSlots = 4,
  }) : _registry = registry,
       _repository = repository,
       _scheduler = scheduler,
       _clock = clock,
       _idGenerator = idGenerator,
       _conversationGateway = conversationGateway,
       _installationIdLoader = installationIdLoader;

  final CareEntryRegistry _registry;
  final OnboardingConversationRepository _repository;
  final OnboardingDelayScheduler _scheduler;
  final OnboardingConversationClock _clock;
  final OnboardingConversationIdGenerator _idGenerator;
  final GuestOnboardingConversationGateway? _conversationGateway;
  final OnboardingInstallationIdLoader? _installationIdLoader;
  final CareEntryPlacementId placement;
  final int visibleSlots;

  OnboardingConversationState _state = OnboardingConversationState.loading();
  OnboardingConversationSnapshot? _checkpoint;
  CareEntryResolution? _resolution;
  OnboardingScheduledTask? _reactionTimeout;
  OnboardingScheduledTask? _firstUtteranceTimeout;
  OnboardingScheduledTask? _nextSupportTimeout;
  Future<void>? _startSelectedOperation;
  _FirstUtteranceRace? _activeFirstUtteranceRace;
  _NextSupportRace? _activeNextSupportRace;
  OnboardingUtterance? _firstUtterance;
  CareNextSupportUtterance? _nextSupport;
  String? _conversationId;
  DateTime? _conversationExpiresAt;
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

  Future<void> startSelected() {
    final active = _startSelectedOperation;
    if (active != null) return active;
    if (_state.phase != OnboardingConversationPhase.selection) {
      return Future<void>.value();
    }
    final operation = _runStartSelected();
    _startSelectedOperation = operation;
    operation.whenComplete(() {
      if (identical(_startSelectedOperation, operation)) {
        _startSelectedOperation = null;
      }
    }).ignore();
    return operation;
  }

  Future<void> _runStartSelected() async {
    final selectedId = _state.selectedEntryId;
    if (selectedId == null) {
      throw StateError('没有可启动的 Care Entry。');
    }
    final previous = _requireCheckpoint();
    var checkpoint = previous.copyWith(
      phase: OnboardingCheckpointPhase.firstUtterance,
      activeEntryId: selectedId,
    );
    final activeEntry = _requireResolution().entries.firstWhere(
      (entry) => entry.id == selectedId,
    );
    final local = OnboardingUtterance.local(
      utteranceId: activeEntry.seed.fallback.phraseId,
      utterance: activeEntry.seed.firstUtterance,
    );
    final gateway = _conversationGateway;
    final installationIdLoader = _installationIdLoader;
    if (gateway != null && installationIdLoader != null) {
      checkpoint = checkpoint.copyWith(
        conversationRequestEventId:
            previous.conversationRequestEventId ??
            'onboarding-${_idGenerator()}',
      );
      _publish(
        _stateFor(
          checkpoint,
          OnboardingConversationPhase.resolvingFirstUtterance,
          firstUtterance: null,
        ),
      );
      try {
        checkpoint = await _repository.save(checkpoint);
      } on Object {
        if (_disposed) return;
        _publish(
          _stateFor(
            previous,
            OnboardingConversationPhase.selection,
            errorMessage: '这一刻还没保存好，请再试一次。',
          ),
        );
        return;
      }
      if (_disposed) return;
      _checkpoint = checkpoint;
      final epoch = ++_operationEpoch;
      final race = _FirstUtteranceRace();
      _activeFirstUtteranceRace = race;
      _firstUtteranceTimeout?.cancel();
      _firstUtteranceTimeout = _scheduler.schedule(
        const Duration(seconds: 4),
        () => unawaited(
          _selectFirstUtterance(checkpoint, local, epoch: epoch, race: race),
        ),
      );
      unawaited(
        _requestRemoteFirstUtterance(
          gateway,
          installationIdLoader,
          activeEntry,
          checkpoint,
          local,
          epoch: epoch,
          race: race,
        ),
      );
      try {
        await race.done;
      } finally {
        if (identical(_activeFirstUtteranceRace, race)) {
          _activeFirstUtteranceRace = null;
        }
      }
      return;
    }
    try {
      _firstUtterance = local;
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

  Future<void> _requestRemoteFirstUtterance(
    GuestOnboardingConversationGateway gateway,
    OnboardingInstallationIdLoader installationIdLoader,
    ResolvedCareEntry activeEntry,
    OnboardingConversationSnapshot checkpoint,
    OnboardingUtterance local, {
    required int epoch,
    required _FirstUtteranceRace race,
  }) async {
    try {
      final installationId = await installationIdLoader();
      if (_disposed || epoch != _operationEpoch || race.isClaimed) return;
      final remote = await gateway.create(
        CreateGuestOnboardingConversation(
          installationId: installationId,
          localEventId: checkpoint.conversationRequestEventId!,
          careEntryId: activeEntry.id,
          registryRevision: _requireResolution().revision,
          generationScene: activeEntry.seed.generationRef,
          locale: 'zh-CN',
          timeBand: _timeBand(_clock()),
        ),
      );
      await _selectFirstUtterance(
        checkpoint,
        remote.utterance,
        conversationId: remote.conversationId,
        conversationExpiresAt: remote.expiresAt,
        epoch: epoch,
        race: race,
      );
    } on Object {
      await _selectFirstUtterance(checkpoint, local, epoch: epoch, race: race);
    }
  }

  Future<void> _selectFirstUtterance(
    OnboardingConversationSnapshot checkpoint,
    OnboardingUtterance utterance, {
    required int epoch,
    required _FirstUtteranceRace race,
    String? conversationId,
    DateTime? conversationExpiresAt,
  }) async {
    if (_disposed || epoch != _operationEpoch || !race.tryClaim()) return;
    _firstUtteranceTimeout?.cancel();
    _firstUtterance = utterance;
    _conversationId = conversationId;
    _conversationExpiresAt = conversationExpiresAt;
    _applyCheckpoint(checkpoint);
    race.complete();
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
    final privateReactionText = hasOtherText ? normalizedOtherText : null;
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
    final previous = _requireCheckpoint();
    _publish(_stateFor(previous, OnboardingConversationPhase.savingReaction));
    var persistenceSucceeded = false;
    var delayElapsed = false;
    _reactionTimeout = _scheduler.schedule(
      const Duration(milliseconds: 500),
      () {
        delayElapsed = true;
        if (persistenceSucceeded) {
          unawaited(
            _resolveNextSupport(
              reaction,
              otherText: privateReactionText,
              reactionEpoch: reactionEpoch,
            ),
          );
        }
      },
    );
    final checkpoint = previous.copyWith(selectedReaction: reaction);
    try {
      final persisted = await _repository.save(checkpoint);
      if (_disposed || reactionEpoch != _reactionEpoch) return;
      _checkpoint = persisted;
      _publish(
        _stateFor(persisted, OnboardingConversationPhase.savingReaction),
      );
      persistenceSucceeded = true;
      if (delayElapsed) {
        await _resolveNextSupport(
          reaction,
          otherText: privateReactionText,
          reactionEpoch: reactionEpoch,
        );
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
    if (checkpoint.phase == OnboardingCheckpointPhase.selection) {
      _firstUtterance = null;
      _nextSupport = null;
      _conversationId = null;
      _conversationExpiresAt = null;
    } else {
      _nextSupport = _supportFromCheckpoint(checkpoint);
    }
    _publish(_stateFor(checkpoint, _viewPhase(checkpoint.phase)));
  }

  OnboardingConversationState _stateFor(
    OnboardingConversationSnapshot checkpoint,
    OnboardingConversationPhase phase, {
    String? errorMessage,
    Object? firstUtterance = _unsetState,
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
      nextSupport =
          _supportFromCheckpoint(checkpoint) ??
          _nextSupport ??
          candidates.firstWhere((candidate) => candidate.id == nextSupportId);
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
      firstUtterance: identical(firstUtterance, _unsetState)
          ? _resolvedFirstUtterance(checkpoint, activeEntry)
          : firstUtterance as OnboardingUtterance?,
      conversationId: _conversationId,
      conversationExpiresAt: _conversationExpiresAt,
      errorMessage: errorMessage,
    );
  }

  void _scheduleReactionTimeout() {
    _reactionTimeout?.cancel();
    _firstUtteranceTimeout?.cancel();
    final reactionEpoch = ++_reactionEpoch;
    _reactionTimeout = _scheduler.schedule(
      const Duration(seconds: 4),
      () => unawaited(_resolveNextSupport(null, reactionEpoch: reactionEpoch)),
    );
  }

  Future<void> _resolveNextSupport(
    CareReaction? reaction, {
    String? otherText,
    required int reactionEpoch,
  }) async {
    if (reactionEpoch != _reactionEpoch ||
        (_state.phase != OnboardingConversationPhase.reactionPrompt &&
            _state.phase != OnboardingConversationPhase.savingReaction)) {
      return;
    }
    final activeEntry = _state.activeEntry;
    if (activeEntry == null) return;
    final localSupport = activeEntry.seed.nextSupports.resolve(reaction);
    _publish(
      _stateFor(
        _requireCheckpoint(),
        OnboardingConversationPhase.resolvingNextSupport,
      ),
    );
    final fallback = _requireCheckpoint().copyWith(
      phase: OnboardingCheckpointPhase.nextSupportReady,
      selectedReaction: reaction,
      nextSupportId: localSupport.id,
      nextSupportEnglish: localSupport.english,
      nextSupportChinese: localSupport.chinese,
      nextSupportSource: OnboardingUtteranceSource.localFallback,
    );
    OnboardingConversationSnapshot? persistedFallback;
    try {
      persistedFallback = await _repository.saveNextSupport(
        fallback,
        commitIfCurrent: () =>
            !_disposed &&
            reactionEpoch == _reactionEpoch &&
            _state.phase == OnboardingConversationPhase.resolvingNextSupport,
      );
    } on Object {
      persistedFallback = null;
    }
    if (_disposed || reactionEpoch != _reactionEpoch) return;
    if (!_sameNextSupport(persistedFallback, fallback)) {
      _publish(
        _stateFor(
          _requireCheckpoint(),
          OnboardingConversationPhase.reactionPrompt,
          errorMessage: '下一句还没准备好，请再试一次。',
        ),
      );
      return;
    }
    final readyFallback = persistedFallback!;
    _checkpoint = readyFallback;
    final gateway = _conversationGateway;
    final conversationId = _conversationId;
    final previousUtterance = _firstUtterance;
    if (gateway != null &&
        conversationId != null &&
        previousUtterance != null) {
      final race = _NextSupportRace();
      _activeNextSupportRace?.complete();
      _activeNextSupportRace = race;
      _nextSupportTimeout?.cancel();
      _nextSupportTimeout = _scheduler.schedule(
        const Duration(seconds: 6),
        () => _publishPreparedFallback(
          readyFallback,
          localSupport,
          reactionEpoch: reactionEpoch,
          race: race,
        ),
      );
      unawaited(
        _requestRemoteNextSupport(
          gateway,
          activeEntry,
          conversationId,
          previousUtterance,
          readyFallback,
          localSupport,
          reaction,
          otherText: otherText,
          reactionEpoch: reactionEpoch,
          race: race,
        ),
      );
      try {
        await race.done;
      } finally {
        if (identical(_activeNextSupportRace, race)) {
          _activeNextSupportRace = null;
        }
      }
      return;
    }
    final localRace = _NextSupportRace();
    _publishPreparedFallback(
      readyFallback,
      localSupport,
      reactionEpoch: reactionEpoch,
      race: localRace,
    );
  }

  Future<void> _requestRemoteNextSupport(
    GuestOnboardingConversationGateway gateway,
    ResolvedCareEntry activeEntry,
    String conversationId,
    OnboardingUtterance previousUtterance,
    OnboardingConversationSnapshot persistedFallback,
    CareNextSupportUtterance localSupport,
    CareReaction? reaction, {
    String? otherText,
    required int reactionEpoch,
    required _NextSupportRace race,
  }) async {
    try {
      final phraseSaidEventId = _requireCheckpoint().phraseSaidEventId;
      if (phraseSaidEventId == null) return;
      final remote = await gateway.nextSupport(
        NextGuestOnboardingTurn(
          conversationId: conversationId,
          localEventId:
              '$phraseSaidEventId.next.${reaction?.wireValue ?? 'none'}',
          previousUtteranceId: previousUtterance.utteranceId,
          generationScene: activeEntry.seed.generationRef,
          reaction: reaction,
          reactionText: otherText,
        ),
      );
      final selected = await _selectNextSupport(
        CareNextSupportUtterance(
          id: CareSupportId(remote.utterance.utteranceId),
          english: remote.utterance.english,
          chinese: remote.utterance.chinese,
        ),
        reaction,
        reactionEpoch: reactionEpoch,
        race: race,
      );
      if (!selected && !race.isClaimed) {
        _publishPreparedFallback(
          persistedFallback,
          localSupport,
          reactionEpoch: reactionEpoch,
          race: race,
        );
      }
    } on Object {
      _publishPreparedFallback(
        persistedFallback,
        localSupport,
        reactionEpoch: reactionEpoch,
        race: race,
      );
    }
  }

  Future<bool> _selectNextSupport(
    CareNextSupportUtterance support,
    CareReaction? reaction, {
    required int reactionEpoch,
    required _NextSupportRace race,
  }) async {
    if (_disposed ||
        reactionEpoch != _reactionEpoch ||
        _state.phase != OnboardingConversationPhase.resolvingNextSupport) {
      return false;
    }
    final checkpoint = _requireCheckpoint();
    final next = checkpoint.copyWith(
      phase: OnboardingCheckpointPhase.nextSupportReady,
      selectedReaction: reaction,
      nextSupportId: support.id,
      nextSupportEnglish: support.english,
      nextSupportChinese: support.chinese,
      nextSupportSource: OnboardingUtteranceSource.remoteGenerated,
    );
    final token = Object();
    if (!race.beginRemote(token)) return false;
    try {
      final persisted = await _repository.saveNextSupport(
        next,
        commitIfCurrent: () => race.claimRemoteCommit(token),
      );
      if (_disposed || reactionEpoch != _reactionEpoch) return false;
      final committedSnapshot = persisted;
      if (committedSnapshot != null &&
          _sameNextSupport(committedSnapshot, next) &&
          race.finishRemote(token, committedSnapshot)) {
        _nextSupportTimeout?.cancel();
        _nextSupport = support;
        _applyCheckpoint(committedSnapshot);
        race.complete();
        return true;
      }
      race.abandonRemote(token);
      return false;
    } on Object {
      race.abandonRemote(token);
      return false;
    }
  }

  void _publishPreparedFallback(
    OnboardingConversationSnapshot checkpoint,
    CareNextSupportUtterance support, {
    required int reactionEpoch,
    required _NextSupportRace race,
  }) {
    if (_disposed ||
        reactionEpoch != _reactionEpoch ||
        _state.phase != OnboardingConversationPhase.resolvingNextSupport ||
        !race.claimFallback(checkpoint)) {
      return;
    }
    _nextSupportTimeout?.cancel();
    _nextSupport = support;
    _applyCheckpoint(checkpoint);
    race.complete();
  }

  bool _sameNextSupport(
    OnboardingConversationSnapshot? left,
    OnboardingConversationSnapshot right,
  ) =>
      left?.nextSupportId == right.nextSupportId &&
      left?.nextSupportEnglish == right.nextSupportEnglish &&
      left?.nextSupportChinese == right.nextSupportChinese &&
      left?.nextSupportSource == right.nextSupportSource;

  CareNextSupportUtterance? _supportFromCheckpoint(
    OnboardingConversationSnapshot checkpoint,
  ) {
    final id = checkpoint.nextSupportId;
    final english = checkpoint.nextSupportEnglish;
    final chinese = checkpoint.nextSupportChinese;
    if (id == null || english == null || chinese == null) return null;
    return CareNextSupportUtterance(id: id, english: english, chinese: chinese);
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

  OnboardingUtterance? _resolvedFirstUtterance(
    OnboardingConversationSnapshot checkpoint,
    ResolvedCareEntry? entry,
  ) {
    if (checkpoint.phase == OnboardingCheckpointPhase.selection ||
        entry == null) {
      return null;
    }
    return _firstUtterance ??
        OnboardingUtterance.local(
          utteranceId: entry.seed.fallback.phraseId,
          utterance: entry.seed.firstUtterance,
        );
  }

  @override
  void dispose() {
    _disposed = true;
    _operationEpoch += 1;
    _reactionEpoch += 1;
    _reactionTimeout?.cancel();
    _firstUtteranceTimeout?.cancel();
    _nextSupportTimeout?.cancel();
    _activeFirstUtteranceRace?.complete();
    _activeFirstUtteranceRace = null;
    _activeNextSupportRace?.complete();
    _activeNextSupportRace = null;
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

String _timeBand(DateTime localTime) => switch (localTime.hour) {
  >= 5 && < 12 => 'morning',
  >= 12 && < 18 => 'afternoon',
  >= 18 && < 23 => 'evening',
  _ => 'night',
};

const Object _unsetState = Object();

final class _FirstUtteranceRace {
  final Completer<void> _done = Completer<void>();
  bool _claimed = false;

  bool get isClaimed => _claimed;
  Future<void> get done => _done.future;

  bool tryClaim() {
    if (_claimed) return false;
    _claimed = true;
    return true;
  }

  void complete() {
    if (!_done.isCompleted) _done.complete();
  }
}

final class _NextSupportRace {
  final Completer<void> _done = Completer<void>();
  Object? _provisionalRemote;
  Object? _winnerToken;
  OnboardingConversationSnapshot? _winner;

  bool get isClaimed => _winner != null;
  Future<void> get done => _done.future;

  bool beginRemote(Object token) {
    if (_winnerToken != null || _provisionalRemote != null) return false;
    _provisionalRemote = token;
    return true;
  }

  bool claimFallback(OnboardingConversationSnapshot snapshot) {
    if (_winnerToken != null) return false;
    _winnerToken = _fallbackWinnerToken;
    _winner = snapshot;
    return true;
  }

  bool claimRemoteCommit(Object token) {
    if (_winnerToken != null || !identical(_provisionalRemote, token)) {
      return false;
    }
    _winnerToken = token;
    _provisionalRemote = null;
    return true;
  }

  bool finishRemote(Object token, OnboardingConversationSnapshot snapshot) {
    if (!identical(_winnerToken, token) || _winner != null) return false;
    _winner = snapshot;
    return true;
  }

  void abandonRemote(Object token) {
    if (identical(_provisionalRemote, token)) _provisionalRemote = null;
    if (identical(_winnerToken, token) && _winner == null) {
      _winnerToken = null;
    }
  }

  void complete() {
    if (!_done.isCompleted) _done.complete();
  }
}

const Object _fallbackWinnerToken = Object();
