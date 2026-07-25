import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/domain/models/auth_continuation.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/care_path_notifier.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_flow_models.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

enum _OnboardingExitNavigation { accountEntry, shell }

class OnboardingFlowNotifier extends ChangeNotifier {
  OnboardingFlowNotifier({
    required OnboardingRepository onboardingRepository,
    required PracticeRepository practiceRepository,
    required CarePathNotifier carePathNotifier,
    required AccountNotifier accountNotifier,
    required AuthContinuationCoordinator authContinuationCoordinator,
    DateTime Function()? clock,
    String Function()? localEventIdGenerator,
  }) : _onboardingRepository = onboardingRepository,
       _practiceRepository = practiceRepository,
       _carePathNotifier = carePathNotifier,
       _accountNotifier = accountNotifier,
       _authContinuationCoordinator = authContinuationCoordinator,
       _clock = clock ?? DateTime.now,
       _localEventIdGenerator = localEventIdGenerator ?? _defaultLocalEventId,
       _flowSnapshot = OnboardingFlowSnapshot.initial(
         (clock ?? DateTime.now)().toUtc(),
       ) {
    _carePathNotifier.addListener(_onCarePathChanged);
  }

  final OnboardingRepository _onboardingRepository;
  final PracticeRepository _practiceRepository;
  final CarePathNotifier _carePathNotifier;
  final AccountNotifier _accountNotifier;
  final AuthContinuationCoordinator _authContinuationCoordinator;
  final DateTime Function() _clock;
  final String Function() _localEventIdGenerator;

  OnboardingFlowSnapshot _flowSnapshot;
  List<OnboardingMomentChoice> _availableMoments =
      const <OnboardingMomentChoice>[];
  Future<void>? _initializeFuture;
  Future<void>? _reactionFuture;
  Future<bool>? _confirmedTurnPersistenceFuture;
  Future<OnboardingSnapshot?>? _completionFuture;
  Future<OnboardingSnapshot?>? _exitActionFuture;
  Future<void> _flowMutationTail = Future<void>.value();
  int _pendingFlowMutations = 0;
  bool _isBusy = false;
  bool _disposed = false;
  String? _message;
  OnboardingSnapshot? _recoveredCompletion;
  _OnboardingExitNavigation? _pendingExitNavigation;

  OnboardingFlowSnapshot get flowSnapshot => _flowSnapshot;
  OnboardingFlowStep get step => _flowSnapshot.step;
  CareTurnSnapshot? get careTurn => _carePathNotifier.snapshot;
  List<OnboardingMomentChoice> get availableMoments {
    final preferredActivityIds = _flowSnapshot.selectedSceneIds.toSet();
    return List<OnboardingMomentChoice>.unmodifiable(<OnboardingMomentChoice>[
      ..._availableMoments.where(
        (moment) => preferredActivityIds.contains(moment.activityId),
      ),
      ..._availableMoments.where(
        (moment) => !preferredActivityIds.contains(moment.activityId),
      ),
    ]);
  }

  String? get message => _message;
  bool get isBusy =>
      _isBusy || _pendingFlowMutations > 0 || _exitActionFuture != null;
  bool get isTransitioning => _pendingFlowMutations > 0;
  bool get canOpenAccountEntry =>
      _pendingExitNavigation == _OnboardingExitNavigation.accountEntry;
  bool get gardenTraceDegraded => _flowSnapshot.gardenTraceDegraded;
  bool get hasPendingStarterPhrasePersistence {
    final phraseId = _carePathNotifier.snapshot?.currentUtterance?.phraseId;
    return step == OnboardingFlowStep.careTurn &&
        _flowSnapshot.starterPhraseId?.trim().isEmpty != false &&
        phraseId?.trim().isEmpty == false;
  }

  bool get hasPendingTracePersistence =>
      step == OnboardingFlowStep.careTurn &&
      !_flowSnapshot.hasConfirmedTrace &&
      _hasConfirmedCareTrace(_carePathNotifier.snapshot);

  OnboardingSnapshot? takeRecoveredCompletion() {
    final completed = _recoveredCompletion;
    _recoveredCompletion = null;
    return completed;
  }

  bool takeAccountEntryNavigation() =>
      _takeExitNavigation(_OnboardingExitNavigation.accountEntry);

  bool takeShellNavigation() =>
      _takeExitNavigation(_OnboardingExitNavigation.shell);

  Future<void> initialize() {
    if (_disposed) {
      return Future.value();
    }
    return _initializeFuture ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    _setBusy(true);
    try {
      final catalog = await _practiceRepository.getActivityCatalog();
      _availableMoments = catalog.activities
          .map(
            (activity) => OnboardingMomentChoice(
              spaceId: activity.spaceId,
              activityId: activity.activityId,
              spaceTitle: activity.spaceTitle,
              title: activity.title,
              summary: activity.summary,
            ),
          )
          .toList(growable: false);

      _flowSnapshot =
          await _onboardingRepository.readFlowSnapshot() ??
          OnboardingFlowSnapshot.initial(_now());
      _message = null;

      if (_flowSnapshot.step == OnboardingFlowStep.careTurn &&
          _flowSnapshot.hasConfirmedTrace) {
        await _saveTransition(
          _flowSnapshot.copyWith(step: OnboardingFlowStep.trace),
        );
      }

      if (_flowSnapshot.hasSelectedMoment &&
          _requiresCarePathRecovery(_flowSnapshot.step)) {
        if (_flowSnapshot.step == OnboardingFlowStep.careTurn &&
            _flowSnapshot.pendingLocalEventId != null &&
            _flowSnapshot.selectedReaction != null) {
          await _restorePendingCareTurn();
        } else {
          await _carePathNotifier.startMoment(
            spaceId: _flowSnapshot.selectedSpaceId!,
            activityId: _flowSnapshot.selectedActivityId!,
          );
          if (_flowSnapshot.step == OnboardingFlowStep.careTurn &&
              _flowSnapshot.starterPhraseId?.trim().isEmpty != false) {
            await _persistStarterPhraseFromCareTurn();
          }
        }
      }

      await recoverSignedInContinuation();
    } catch (_) {
      _message = '暂时无法恢复引导，请稍后再试。';
    } finally {
      _setBusy(false);
    }
  }

  Future<void> continueFromWelcome() => _enqueueFlowMutation(() async {
    if (step == OnboardingFlowStep.welcome) {
      await _saveTransition(
        _flowSnapshot.copyWith(step: OnboardingFlowStep.age),
      );
    }
  });

  Future<void> selectAgeBucket(OnboardingAgeBucket value) =>
      _enqueueFlowMutation(() async {
        if (step == OnboardingFlowStep.age) {
          await _saveTransition(_flowSnapshot.copyWith(ageBucket: value));
        }
      });

  Future<void> continueFromAge() => _enqueueFlowMutation(() async {
    if (step != OnboardingFlowStep.age) {
      return;
    }
    if (_flowSnapshot.ageBucket == null) {
      await _setMessage('先选一个适合宝宝的年龄范围。');
      return;
    }
    await _saveTransition(
      _flowSnapshot.copyWith(step: OnboardingFlowStep.scenePreferences),
    );
  });

  Future<void> toggleScenePreference(String activityId) => _enqueueFlowMutation(
    () async {
      if (step != OnboardingFlowStep.scenePreferences ||
          !_availableMoments.any((moment) => moment.activityId == activityId)) {
        return;
      }
      final selected = _flowSnapshot.selectedSceneIds.toList();
      if (!selected.remove(activityId)) {
        selected.add(activityId);
      }
      await _saveTransition(_flowSnapshot.copyWith(selectedSceneIds: selected));
    },
  );

  Future<void> continueFromScenePreferences() => _enqueueFlowMutation(() async {
    if (step != OnboardingFlowStep.scenePreferences) {
      return;
    }
    if (_flowSnapshot.selectedSceneIds.isEmpty) {
      await _setMessage('至少选一个常见照护时刻。');
      return;
    }
    await _saveTransition(
      _flowSnapshot.copyWith(step: OnboardingFlowStep.supportGoal),
    );
  });

  Future<void> selectSupportGoal(OnboardingSupportGoal value) =>
      _enqueueFlowMutation(() async {
        if (step == OnboardingFlowStep.supportGoal) {
          await _saveTransition(_flowSnapshot.copyWith(supportGoal: value));
        }
      });

  Future<void> continueFromSupportGoal() => _enqueueFlowMutation(() async {
    if (step != OnboardingFlowStep.supportGoal) {
      return;
    }
    if (_flowSnapshot.supportGoal == null) {
      await _setMessage('先选一个你现在更想得到的支持。');
      return;
    }
    await _saveTransition(
      _flowSnapshot.copyWith(step: OnboardingFlowStep.currentMoment),
    );
  });

  Future<void> selectCurrentMoment(OnboardingMomentChoice value) =>
      _enqueueFlowMutation(() async {
        if (step != OnboardingFlowStep.currentMoment ||
            !_isCatalogMoment(value)) {
          return;
        }

        final transitionSaved = await _saveTransition(
          _flowSnapshot.copyWith(
            step: OnboardingFlowStep.careTurn,
            selectedSpaceId: value.spaceId,
            selectedActivityId: value.activityId,
            starterPhraseId: null,
            pendingLocalEventId: null,
            selectedReaction: null,
            traceEventKey: null,
            gardenTraceDegraded: false,
          ),
        );
        if (!transitionSaved) {
          return;
        }
        await _carePathNotifier.startMoment(
          spaceId: value.spaceId,
          activityId: value.activityId,
        );
        await _persistStarterPhraseFromCareTurn();
      });

  void markSaid() => _carePathNotifier.markSaid();

  Future<void> selectReaction(BabyReactionType reaction) {
    final running = _reactionFuture;
    if (running != null) {
      return running;
    }
    final future = _enqueueFlowMutation(
      () => _selectReactionInternal(reaction),
    );
    _reactionFuture = future;
    return future.whenComplete(() {
      if (identical(_reactionFuture, future)) {
        _reactionFuture = null;
      }
    });
  }

  Future<void> _selectReactionInternal(BabyReactionType reaction) async {
    var turn = _carePathNotifier.snapshot;
    if (_carePathNotifier.phase == CareTurnPhase.error &&
        _flowSnapshot.pendingLocalEventId != null &&
        _flowSnapshot.selectedReaction != null) {
      if (_flowSnapshot.selectedReaction != reaction) {
        await _setMessage('请用刚才选的回应重试，避免重复记录。');
        return;
      }
      await _restorePendingCareTurn();
      turn = _carePathNotifier.snapshot;
      if (_flowSnapshot.hasConfirmedTrace) {
        return;
      }
    }
    if (step != OnboardingFlowStep.careTurn ||
        turn == null ||
        turn.phase != CareTurnPhase.reactionPrompt) {
      await _setMessage(turn?.message ?? '请先说完这句，再记录宝宝的回应。');
      return;
    }
    if (_flowSnapshot.starterPhraseId?.trim().isEmpty != false) {
      await _setMessage('暂时无法保存引导进度，请再试一次。');
      return;
    }

    final localEventId =
        _flowSnapshot.pendingLocalEventId ?? _localEventIdGenerator();
    final pendingIdentitySaved = await _saveTransition(
      _flowSnapshot.copyWith(
        pendingLocalEventId: localEventId,
        selectedReaction: reaction,
      ),
    );
    if (!pendingIdentitySaved) {
      return;
    }
    await _carePathNotifier.selectReaction(
      reaction,
      localEventId: localEventId,
    );
    await _persistConfirmedCareTurn();
  }

  Future<void> _restorePendingCareTurn() async {
    final localEventId = _flowSnapshot.pendingLocalEventId;
    final reaction = _flowSnapshot.selectedReaction;
    final spaceId = _flowSnapshot.selectedSpaceId;
    final activityId = _flowSnapshot.selectedActivityId;
    final phraseId = _flowSnapshot.starterPhraseId;
    if (localEventId?.trim().isEmpty != false ||
        reaction == null ||
        spaceId?.trim().isEmpty != false ||
        activityId?.trim().isEmpty != false ||
        phraseId?.trim().isEmpty != false) {
      await _setMessage('这次回应暂时无法恢复，请换一个场景再试。');
      return;
    }

    final existing = await _practiceRepository.findEventByLocalEventId(
      localEventId!,
    );
    if (existing != null) {
      if (!_matchesPendingCareTurn(existing)) {
        await _setMessage('这次回应与已保存记录不一致，请换一个场景再试。');
        return;
      }
      await _carePathNotifier.restoreConfirmedReaction(existing);
      await _persistConfirmedCareTurn();
      return;
    }

    await _carePathNotifier.restorePendingReaction(
      spaceId: spaceId!,
      activityId: activityId!,
      phraseId: phraseId!,
      reactionType: reaction,
    );
  }

  bool _matchesPendingCareTurn(InteractionEventPayload event) {
    return event.spaceId == _flowSnapshot.selectedSpaceId &&
        event.activityId == _flowSnapshot.selectedActivityId &&
        event.phraseId == _flowSnapshot.starterPhraseId &&
        event.reactionType == _flowSnapshot.selectedReaction;
  }

  Future<bool> _persistStarterPhraseFromCareTurn() async {
    final turn = _carePathNotifier.snapshot;
    final phraseId = turn?.currentUtterance?.phraseId;
    if (phraseId == null || phraseId.trim().isEmpty) {
      await _setMessage(turn?.message ?? '当前照护节点暂时不可用。');
      return false;
    }
    if (_flowSnapshot.starterPhraseId == phraseId) {
      return true;
    }
    return _saveTransition(_flowSnapshot.copyWith(starterPhraseId: phraseId));
  }

  Future<void> retryPersistStarterPhrase() => _enqueueFlowMutation(() async {
    if (!hasPendingStarterPhrasePersistence) {
      return;
    }
    await _persistStarterPhraseFromCareTurn();
  });

  Future<void> retryReaction() async {
    final reaction =
        _flowSnapshot.selectedReaction ??
        _carePathNotifier.snapshot?.selectedReaction;
    if (reaction == null) {
      await _setMessage('请重新选择宝宝刚才的回应。');
      return;
    }
    await selectReaction(reaction);
  }

  Future<void> chooseAnotherMoment() => _enqueueFlowMutation(() async {
    if (step != OnboardingFlowStep.careTurn) {
      return;
    }
    final saved = await _saveTransition(
      _flowSnapshot.copyWith(
        step: OnboardingFlowStep.currentMoment,
        selectedSpaceId: null,
        selectedActivityId: null,
        starterPhraseId: null,
        pendingLocalEventId: null,
        selectedReaction: null,
        traceEventKey: null,
        gardenTraceDegraded: false,
      ),
    );
    if (saved) {
      _carePathNotifier.resetToSafeEmpty();
    }
  });

  Future<void> continueFromTrace() => _enqueueFlowMutation(() async {
    if (step == OnboardingFlowStep.trace && _flowSnapshot.hasConfirmedTrace) {
      await _saveTransition(
        _flowSnapshot.copyWith(step: OnboardingFlowStep.accountInvitation),
      );
    }
  });

  Future<void> continueFromCareTurn() => _enqueueFlowMutation(() async {
    if (step == OnboardingFlowStep.careTurn &&
        _flowSnapshot.hasConfirmedTrace) {
      await _saveTransition(
        _flowSnapshot.copyWith(step: OnboardingFlowStep.trace),
      );
    }
  });

  Future<OnboardingSnapshot?> beginAccountSave() =>
      _runExclusiveExitAction(() async {
        if (step != OnboardingFlowStep.accountInvitation ||
            !_flowSnapshot.hasConfirmedTrace) {
          return null;
        }
        if (_accountNotifier.isSignedIn) {
          final completed = await _completeFromPersistedTrace();
          if (completed != null) {
            _setExitNavigation(_OnboardingExitNavigation.shell);
          }
          return completed;
        }
        try {
          await _authContinuationCoordinator.beginSaveOnboardingMemory();
        } catch (_) {
          await _setMessage('暂时无法保存账号继续状态，请再试一次。');
          return null;
        }
        _setExitNavigation(_OnboardingExitNavigation.accountEntry);
        return null;
      });

  Future<OnboardingSnapshot?> handleAccountReturn(Object? result) =>
      _runExclusiveExitAction(() async {
        if (result != AccountEntryResult.signedIn ||
            !_accountNotifier.isSignedIn) {
          return null;
        }
        final continuationResult = await _readPendingContinuation(
          unavailableMessage: '暂时无法读取账号继续状态，请再试一次。',
        );
        if (continuationResult == null) {
          return null;
        }
        if (continuationResult.status == AuthContinuationReadStatus.available &&
            continuationResult.continuation?.intent !=
                AuthContinuationIntent.saveOnboardingMemory) {
          return null;
        }
        final completed = await _completeFromPersistedTrace();
        if (completed != null) {
          _setExitNavigation(_OnboardingExitNavigation.shell);
        }
        return completed;
      });

  Future<OnboardingSnapshot?> chooseLocalOnly() =>
      _runExclusiveExitAction(() async {
        final completed = await _completeFromPersistedTrace();
        if (completed != null) {
          _setExitNavigation(_OnboardingExitNavigation.shell);
        }
        return completed;
      });

  Future<OnboardingSnapshot?> recoverSignedInContinuation() async {
    if (!_flowSnapshot.hasConfirmedTrace || !_accountNotifier.isSignedIn) {
      return null;
    }
    final continuationResult = await _readPendingContinuation(
      unavailableMessage: '暂时无法恢复账号继续状态，请稍后再试。',
    );
    if (continuationResult?.status != AuthContinuationReadStatus.available ||
        continuationResult?.continuation?.intent !=
            AuthContinuationIntent.saveOnboardingMemory) {
      return null;
    }
    final completed = await _completeFromPersistedTrace();
    if (!_disposed) {
      _recoveredCompletion = completed;
      notifyListeners();
    }
    return completed;
  }

  Future<AuthContinuationReadResult?> _readPendingContinuation({
    required String unavailableMessage,
  }) async {
    try {
      final result = await _authContinuationCoordinator.readPendingResult();
      switch (result.status) {
        case AuthContinuationReadStatus.available:
        case AuthContinuationReadStatus.notFound:
        case AuthContinuationReadStatus.expired:
          return result;
        case AuthContinuationReadStatus.corrupt:
        case AuthContinuationReadStatus.ioFailure:
          await _setMessage(unavailableMessage);
          return null;
      }
    } catch (_) {
      await _setMessage(unavailableMessage);
      return null;
    }
  }

  Future<OnboardingSnapshot?> _runExclusiveExitAction(
    Future<OnboardingSnapshot?> Function() action,
  ) {
    final running = _exitActionFuture;
    if (running != null) {
      return running;
    }
    final completer = Completer<OnboardingSnapshot?>();
    final future = completer.future;
    _exitActionFuture = future;
    _setBusy(true);
    unawaited(_completeExclusiveExitAction(completer, action, future));
    return future;
  }

  Future<void> _completeExclusiveExitAction(
    Completer<OnboardingSnapshot?> completer,
    Future<OnboardingSnapshot?> Function() action,
    Future<OnboardingSnapshot?> future,
  ) async {
    try {
      completer.complete(await action());
    } catch (_) {
      await _setMessage('暂时无法完成引导，请再试一次。');
      completer.complete(null);
    } finally {
      if (identical(_exitActionFuture, future)) {
        _exitActionFuture = null;
      }
      _setBusy(false);
    }
  }

  bool _takeExitNavigation(_OnboardingExitNavigation value) {
    if (_pendingExitNavigation != value) {
      return false;
    }
    _pendingExitNavigation = null;
    if (!_disposed) {
      notifyListeners();
    }
    return true;
  }

  void _setExitNavigation(_OnboardingExitNavigation value) {
    if (_disposed) {
      return;
    }
    _pendingExitNavigation = value;
    _message = null;
    notifyListeners();
  }

  Future<OnboardingSnapshot?> _completeFromPersistedTrace() async {
    final running = _completionFuture;
    if (running != null) {
      return running;
    }
    final future = _completeFromPersistedTraceInternal();
    _completionFuture = future;
    return future.whenComplete(() {
      if (identical(_completionFuture, future)) {
        _completionFuture = null;
      }
    });
  }

  Future<OnboardingSnapshot?> _completeFromPersistedTraceInternal() async {
    final ageBucket = _flowSnapshot.ageBucket;
    final supportGoal = _flowSnapshot.supportGoal;
    final spaceId = _flowSnapshot.selectedSpaceId;
    final activityId = _flowSnapshot.selectedActivityId;
    final phraseId = _flowSnapshot.starterPhraseId;
    final traceEventKey = _flowSnapshot.traceEventKey;
    if (ageBucket == null ||
        supportGoal == null ||
        spaceId?.trim().isEmpty != false ||
        activityId?.trim().isEmpty != false ||
        phraseId?.trim().isEmpty != false ||
        traceEventKey?.trim().isEmpty != false) {
      await _setMessage('暂时无法完成引导，请再试一次。');
      return null;
    }

    _setBusy(true);
    try {
      OnboardingSnapshot completed;
      try {
        completed = await _onboardingRepository.completeOnboarding(
          childDisplayName: '宝宝',
          ageBucket: ageBucket,
          selectedSceneIds: _flowSnapshot.selectedSceneIds,
          supportGoal: supportGoal,
          starterSpaceId: spaceId!,
          starterActivityId: activityId!,
          starterPhraseId: phraseId!,
          firstTraceEventKey: traceEventKey!,
          completedAt: _now(),
        );
      } catch (_) {
        await _setMessage('暂时无法完成引导，请再试一次。');
        return null;
      }
      await _clearCompletionResidue();
      return completed;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _clearCompletionResidue() async {
    try {
      await _onboardingRepository.clearFlowSnapshot();
    } catch (_) {}
    try {
      await _authContinuationCoordinator.clear();
    } catch (_) {}
  }

  Future<void> retryPersistConfirmedCareTurn() async {
    await _persistConfirmedCareTurn();
  }

  Future<bool> _persistConfirmedCareTurn() {
    final turn = _carePathNotifier.snapshot;
    if (turn == null ||
        step != OnboardingFlowStep.careTurn ||
        !_hasConfirmedCareTrace(turn)) {
      return Future<bool>.value(false);
    }
    if (_flowSnapshot.hasConfirmedTrace) {
      return Future<bool>.value(true);
    }
    final running = _confirmedTurnPersistenceFuture;
    if (running != null) {
      return running;
    }
    final future = _saveTransition(
      _flowSnapshot.copyWith(
        pendingLocalEventId: null,
        selectedReaction: turn.selectedReaction,
        traceEventKey: turn.traceEventKey,
        gardenTraceDegraded: turn.latestGardenImpact == null,
      ),
    );
    _confirmedTurnPersistenceFuture = future;
    return future.whenComplete(() {
      if (identical(_confirmedTurnPersistenceFuture, future)) {
        _confirmedTurnPersistenceFuture = null;
      }
    });
  }

  bool _hasConfirmedCareTrace(CareTurnSnapshot? turn) {
    if (turn == null || turn.traceEventKey?.trim().isEmpty != false) {
      return false;
    }
    return turn.phase == CareTurnPhase.nextSupportReady ||
        turn.phase == CareTurnPhase.heldWithFallback;
  }

  bool _requiresCarePathRecovery(OnboardingFlowStep value) {
    return value == OnboardingFlowStep.careTurn ||
        value == OnboardingFlowStep.trace ||
        value == OnboardingFlowStep.accountInvitation;
  }

  bool _isCatalogMoment(OnboardingMomentChoice value) {
    return _availableMoments.any(
      (moment) =>
          moment.spaceId == value.spaceId &&
          moment.activityId == value.activityId,
    );
  }

  Future<bool> _saveTransition(OnboardingFlowSnapshot next) async {
    final persisted = next.copyWith(updatedAt: _now());
    try {
      await _onboardingRepository.saveFlowSnapshot(persisted);
    } catch (_) {
      await _setMessage('暂时无法保存引导进度，请再试一次。');
      return false;
    }
    if (_disposed) {
      return false;
    }
    _flowSnapshot = persisted;
    _message = null;
    notifyListeners();
    return true;
  }

  Future<void> _enqueueFlowMutation(Future<void> Function() mutation) {
    if (_disposed) {
      return Future<void>.value();
    }
    final startsImmediately = _pendingFlowMutations == 0;
    _pendingFlowMutations += 1;
    notifyListeners();
    final running = startsImmediately
        ? _runFlowMutation(mutation)
        : _flowMutationTail.then((_) => _runFlowMutation(mutation));
    _flowMutationTail = running;
    return running.whenComplete(() {
      _pendingFlowMutations -= 1;
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  Future<void> _runFlowMutation(Future<void> Function() mutation) async {
    try {
      await mutation();
    } catch (_) {
      await _setMessage('暂时无法保存引导进度，请再试一次。');
    }
  }

  Future<void> _setMessage(String value) async {
    if (_disposed) {
      return;
    }
    _message = value;
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_disposed || _isBusy == value) {
      return;
    }
    _isBusy = value;
    notifyListeners();
  }

  void _onCarePathChanged() {
    unawaited(_persistConfirmedCareTurn());
  }

  DateTime _now() => _clock().toUtc();

  static String _defaultLocalEventId() {
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    final suffix = Random.secure()
        .nextInt(0x100000000)
        .toRadixString(16)
        .padLeft(8, '0');
    return 'evt_onboarding_${micros}_$suffix';
  }

  @override
  void dispose() {
    _disposed = true;
    _carePathNotifier.removeListener(_onCarePathChanged);
    super.dispose();
  }
}
