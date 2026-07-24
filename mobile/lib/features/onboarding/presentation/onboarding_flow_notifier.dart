import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
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
  Future<void>? _confirmedTurnPersistenceFuture;
  bool _isBusy = false;
  bool _disposed = false;
  String? _message;

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
  bool get isBusy => _isBusy;
  bool get gardenTraceDegraded => _flowSnapshot.gardenTraceDegraded;

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
        await _carePathNotifier.startMoment(
          spaceId: _flowSnapshot.selectedSpaceId!,
          activityId: _flowSnapshot.selectedActivityId!,
        );
        if (_flowSnapshot.step == OnboardingFlowStep.careTurn &&
            _flowSnapshot.pendingLocalEventId != null &&
            _flowSnapshot.selectedReaction != null) {
          _carePathNotifier.markSaid();
        }
      }

      await recoverSignedInContinuation();
    } catch (error) {
      _message = 'onboarding 状态读取失败：$error';
    } finally {
      _setBusy(false);
    }
  }

  Future<void> continueFromWelcome() {
    if (step != OnboardingFlowStep.welcome) {
      return Future.value();
    }
    return _saveTransition(
      _flowSnapshot.copyWith(step: OnboardingFlowStep.age),
    );
  }

  Future<void> selectAgeBucket(OnboardingAgeBucket value) {
    if (step != OnboardingFlowStep.age) {
      return Future.value();
    }
    return _saveTransition(_flowSnapshot.copyWith(ageBucket: value));
  }

  Future<void> continueFromAge() {
    if (step != OnboardingFlowStep.age) {
      return Future.value();
    }
    if (_flowSnapshot.ageBucket == null) {
      return _setMessage('先选一个适合宝宝的年龄范围。');
    }
    return _saveTransition(
      _flowSnapshot.copyWith(step: OnboardingFlowStep.scenePreferences),
    );
  }

  Future<void> toggleScenePreference(String activityId) {
    if (step != OnboardingFlowStep.scenePreferences ||
        !_availableMoments.any((moment) => moment.activityId == activityId)) {
      return Future.value();
    }
    final selected = _flowSnapshot.selectedSceneIds.toList();
    if (!selected.remove(activityId)) {
      selected.add(activityId);
    }
    return _saveTransition(_flowSnapshot.copyWith(selectedSceneIds: selected));
  }

  Future<void> continueFromScenePreferences() {
    if (step != OnboardingFlowStep.scenePreferences) {
      return Future.value();
    }
    if (_flowSnapshot.selectedSceneIds.isEmpty) {
      return _setMessage('至少选一个常见照护时刻。');
    }
    return _saveTransition(
      _flowSnapshot.copyWith(step: OnboardingFlowStep.supportGoal),
    );
  }

  Future<void> selectSupportGoal(OnboardingSupportGoal value) {
    if (step != OnboardingFlowStep.supportGoal) {
      return Future.value();
    }
    return _saveTransition(_flowSnapshot.copyWith(supportGoal: value));
  }

  Future<void> continueFromSupportGoal() {
    if (step != OnboardingFlowStep.supportGoal) {
      return Future.value();
    }
    if (_flowSnapshot.supportGoal == null) {
      return _setMessage('先选一个你现在更想得到的支持。');
    }
    return _saveTransition(
      _flowSnapshot.copyWith(step: OnboardingFlowStep.currentMoment),
    );
  }

  Future<void> selectCurrentMoment(OnboardingMomentChoice value) async {
    if (step != OnboardingFlowStep.currentMoment || !_isCatalogMoment(value)) {
      return;
    }

    await _saveTransition(
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
    await _carePathNotifier.startMoment(
      spaceId: value.spaceId,
      activityId: value.activityId,
    );
    final turn = _carePathNotifier.snapshot;
    final phraseId = turn?.currentUtterance?.phraseId;
    if (phraseId == null || phraseId.trim().isEmpty) {
      await _setMessage(turn?.message ?? '当前照护节点暂时不可用。');
      return;
    }
    await _saveTransition(_flowSnapshot.copyWith(starterPhraseId: phraseId));
  }

  void markSaid() => _carePathNotifier.markSaid();

  Future<void> selectReaction(BabyReactionType reaction) {
    final running = _reactionFuture;
    if (running != null) {
      return running;
    }
    final future = _selectReactionInternal(reaction);
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
      await _restoreReactionPromptForRetry();
      turn = _carePathNotifier.snapshot;
    }
    if (step != OnboardingFlowStep.careTurn ||
        turn == null ||
        turn.phase != CareTurnPhase.reactionPrompt) {
      await _setMessage(turn?.message ?? '请先说完这句，再记录宝宝的回应。');
      return;
    }

    final localEventId =
        _flowSnapshot.pendingLocalEventId ?? _localEventIdGenerator();
    await _saveTransition(
      _flowSnapshot.copyWith(
        pendingLocalEventId: localEventId,
        selectedReaction: reaction,
      ),
    );
    await _carePathNotifier.selectReaction(
      reaction,
      localEventId: localEventId,
    );
    await _persistConfirmedCareTurn();
  }

  Future<void> _restoreReactionPromptForRetry() async {
    final spaceId = _flowSnapshot.selectedSpaceId;
    final activityId = _flowSnapshot.selectedActivityId;
    if (spaceId?.trim().isEmpty != false ||
        activityId?.trim().isEmpty != false) {
      return;
    }
    await _carePathNotifier.startMoment(
      spaceId: spaceId!,
      activityId: activityId!,
    );
    _carePathNotifier.markSaid();
  }

  Future<void> continueFromTrace() {
    if (step != OnboardingFlowStep.trace || !_flowSnapshot.hasConfirmedTrace) {
      return Future.value();
    }
    return _saveTransition(
      _flowSnapshot.copyWith(step: OnboardingFlowStep.accountInvitation),
    );
  }

  Future<void> continueFromCareTurn() {
    if (step != OnboardingFlowStep.careTurn ||
        !_flowSnapshot.hasConfirmedTrace) {
      return Future.value();
    }
    return _saveTransition(
      _flowSnapshot.copyWith(step: OnboardingFlowStep.trace),
    );
  }

  Future<void> beginAccountSave() async {
    if (step != OnboardingFlowStep.accountInvitation ||
        !_flowSnapshot.hasConfirmedTrace) {
      return;
    }
    await _authContinuationCoordinator.beginSaveOnboardingMemory();
  }

  Future<OnboardingSnapshot?> handleAccountReturn(Object? result) async {
    if (result != AccountEntryResult.signedIn || !_accountNotifier.isSignedIn) {
      return null;
    }
    return _completeFromPersistedTrace();
  }

  Future<OnboardingSnapshot> chooseLocalOnly() async {
    return _completeFromPersistedTrace();
  }

  Future<void> recoverSignedInContinuation() async {
    if (!_flowSnapshot.hasConfirmedTrace || !_accountNotifier.isSignedIn) {
      return;
    }
    final continuation = await _authContinuationCoordinator.readPending();
    if (continuation?.intent != AuthContinuationIntent.saveOnboardingMemory) {
      return;
    }
    await _completeFromPersistedTrace();
  }

  Future<OnboardingSnapshot> _completeFromPersistedTrace() async {
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
      throw StateError('onboarding 完成所需的真实照护记录不完整。');
    }

    _setBusy(true);
    try {
      final completed = await _onboardingRepository.completeOnboarding(
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
      await _onboardingRepository.clearFlowSnapshot();
      await _authContinuationCoordinator.clear();
      return completed;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _persistConfirmedCareTurn() {
    final turn = _carePathNotifier.snapshot;
    if (turn == null ||
        step != OnboardingFlowStep.careTurn ||
        !_hasConfirmedCareTrace(turn)) {
      return Future.value();
    }
    if (_flowSnapshot.hasConfirmedTrace) {
      return Future.value();
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

  Future<void> _saveTransition(OnboardingFlowSnapshot next) async {
    final persisted = next.copyWith(updatedAt: _now());
    await _onboardingRepository.saveFlowSnapshot(persisted);
    if (_disposed) {
      return;
    }
    _flowSnapshot = persisted;
    _message = null;
    notifyListeners();
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
