import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_draft_store.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_failure.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_repository.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_result.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_stored_draft.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';

/// #23 supplies the account-scoped, restart-safe implementation. The state
/// machine deliberately refuses to delete its recovery record before this
/// port completes.
abstract interface class CustomSceneApprovedContentRegistrar {
  Future<void> register({
    required String accountContext,
    required GeneratedCareMoment moment,
  });
}

abstract interface class CustomSceneAudioStopper {
  Future<void> stopActive();
}

const safetyAudioStopTimeout = Duration(milliseconds: 250);

class _NoopCustomSceneAudioStopper implements CustomSceneAudioStopper {
  const _NoopCustomSceneAudioStopper();

  @override
  Future<void> stopActive() async {}
}

class _CustomSceneOperationToken {
  const _CustomSceneOperationToken({
    required this.operationEpoch,
    required this.accountGeneration,
  });

  final int operationEpoch;
  final int accountGeneration;
}

class _CustomSceneDraftCleanupSnapshot {
  const _CustomSceneDraftCleanupSnapshot({
    required this.draftId,
    required this.clientRequestId,
    required this.expectedAccountContext,
  });

  factory _CustomSceneDraftCleanupSnapshot.fromDraft(
    CustomSceneStoredDraft draft,
  ) {
    return _CustomSceneDraftCleanupSnapshot(
      draftId: draft.draftId,
      clientRequestId: draft.requestIdentity.clientRequestId,
      expectedAccountContext: draft.expectedAccountContext,
    );
  }

  final String draftId;
  final String clientRequestId;
  final String? expectedAccountContext;
}

/// An app-level route command. `custom_scene` never imports a Care Turn screen.
class CustomSceneCareTurnHandoff {
  CustomSceneCareTurnHandoff({required String generatedContentId})
    : generatedContentId = _required(generatedContentId);

  final String generatedContentId;

  static String _required(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'generatedContentId', '不能为空。');
    }
    return normalized;
  }
}

/// One started Care Turn route. Completion means only that the destination
/// exited; it never confirms an interactive handoff or cleans durable intent.
class CustomSceneCareTurnRouteAttempt {
  const CustomSceneCareTurnRouteAttempt({required this.routeCompletion});

  final Future<void> routeCompletion;
}

abstract interface class CustomSceneCareTurnHandoffSink {
  Future<CustomSceneCareTurnRouteAttempt> handoff(
    CustomSceneCareTurnHandoff handoff,
  );
}

typedef CustomSceneAccountContextLoader = Future<String?> Function();

enum CustomSceneSubmissionPhase {
  editing,
  needsAuthentication,
  restoring,
  submitting,
  unknownOutcome,
  generated,
  registeringCareMoment,
  readyForHandoff,
  handoffFailed,
  handoffTimedOut,
  recoverableError,
  healthSafety,
  assessmentUnavailable,
}

enum CustomSceneSubmissionMessageKey {
  anotherDraftPending,
  authenticationRequired,
  restoreUnavailable,
  accountChanged,
  unknownOutcome,
  previousRequestUnknown,
  retryUnavailable,
  handoffRouteFailed,
  saveUnavailable,
  preparedContentSaveFailed,
  requestTerminal,
  draftExpired,
  draftRecoveryUnavailable,
  draftInconsistent,
}

@immutable
class CustomSceneSubmissionMessage {
  const CustomSceneSubmissionMessage(
    this.key, {
    this.data = const <String, Object?>{},
  });

  final CustomSceneSubmissionMessageKey key;

  /// Only stable, non-sensitive values may be carried here. User input,
  /// account identifiers, tokens, and profile identifiers never belong in UI
  /// status data.
  final Map<String, Object?> data;
}

@immutable
class CustomSceneSubmissionState {
  const CustomSceneSubmissionState({
    required this.phase,
    this.message,
    this.failure,
    this.generatedContentId,
    this.canCancelRetainedDraft = false,
    this.safetyNotice,
  });

  const CustomSceneSubmissionState.editing()
    : phase = CustomSceneSubmissionPhase.editing,
      message = null,
      failure = null,
      generatedContentId = null,
      canCancelRetainedDraft = false,
      safetyNotice = null;

  final CustomSceneSubmissionPhase phase;

  /// Typed recoverable messages are kept as CustomSceneSubmissionMessage.
  /// Terminal health states carry server-owned Chinese copy directly so the
  /// safety panel can render exact policy text without localization fallback.
  final Object? message;
  final CustomSceneFailure? failure;
  final String? generatedContentId;
  final bool canCancelRetainedDraft;
  final HealthSafetyNotice? safetyNotice;

  CustomSceneSubmissionMessageKey? get messageKey =>
      message is CustomSceneSubmissionMessage
      ? (message as CustomSceneSubmissionMessage).key
      : null;

  Map<String, Object?> get messageData =>
      message is CustomSceneSubmissionMessage
      ? (message as CustomSceneSubmissionMessage).data
      : const <String, Object?>{};

  CustomSceneFailureKind? get failureKind => failure?.kind;

  CustomSceneRecoveryAction? get recoveryAction => failure?.recoveryAction;

  bool get isBusy => switch (phase) {
    CustomSceneSubmissionPhase.restoring ||
    CustomSceneSubmissionPhase.submitting ||
    CustomSceneSubmissionPhase.generated ||
    CustomSceneSubmissionPhase.registeringCareMoment => true,
    _ => false,
  };

  bool get canOpenPreparedContent {
    final id = generatedContentId?.trim();
    return id != null &&
        id.isNotEmpty &&
        (phase == CustomSceneSubmissionPhase.readyForHandoff ||
            phase == CustomSceneSubmissionPhase.handoffFailed ||
            phase == CustomSceneSubmissionPhase.handoffTimedOut);
  }
}

/// Serializes every network/disk mutation around a durable request identity.
/// It contains no navigator, Dio, backend DTO, log, or telemetry dependency.
class CustomSceneSubmissionController extends ChangeNotifier {
  CustomSceneSubmissionController({
    required CustomSceneRepository repository,
    required CustomSceneDraftStore draftStore,
    required CustomSceneDraftContinuationCoordinator
    draftContinuationCoordinator,
    required CustomSceneApprovedContentRegistrar approvedContentRegistrar,
    required CustomSceneAccountContextLoader accountContextLoader,
    CustomSceneAudioStopper? audioStopper,
    DateTime Function()? clock,
    String Function()? draftIdGenerator,
  }) : _repository = repository,
       _draftStore = draftStore,
       _draftContinuationCoordinator = draftContinuationCoordinator,
       _approvedContentRegistrar = approvedContentRegistrar,
       _accountContextLoader = accountContextLoader,
       _audioStopper = audioStopper ?? const _NoopCustomSceneAudioStopper(),
       _clock = clock ?? DateTime.now,
       _draftIdGenerator = draftIdGenerator ?? _defaultDraftId;

  final CustomSceneRepository _repository;
  final CustomSceneDraftStore _draftStore;
  final CustomSceneDraftContinuationCoordinator _draftContinuationCoordinator;
  final CustomSceneApprovedContentRegistrar _approvedContentRegistrar;
  final CustomSceneAccountContextLoader _accountContextLoader;
  final CustomSceneAudioStopper _audioStopper;
  final DateTime Function() _clock;
  final String Function() _draftIdGenerator;

  CustomSceneSubmissionState _state =
      const CustomSceneSubmissionState.editing();
  Future<void> _mutationTail = Future<void>.value();
  Future<void>? _activeSubmission;
  GeneratedCareMoment? _approvedMomentPendingRegistration;
  int _operationEpoch = 0;
  int _accountGeneration = 0;
  bool _disposed = false;

  CustomSceneSubmissionState get state => _state;

  /// Invalidates all work bound to the previous account without touching its
  /// durable draft. Recovery owns subsequent account-scoped restoration.
  void invalidateForAccountChange() {
    _accountGeneration += 1;
    _operationEpoch += 1;
    _approvedMomentPendingRegistration = null;
    _setState(const CustomSceneSubmissionState.editing());
  }

  Future<void> submit(CustomSceneDraft draft) {
    if (_isSafetyTerminal) {
      return Future<void>.value();
    }
    final running = _activeSubmission;
    if (running != null) {
      return running;
    }
    final operationToken = _captureOperationToken();
    final operation = _enqueue(() async {
      if (!_isOperationCurrent(operationToken)) {
        return;
      }
      try {
        final accountContext = await _loadAccountContext();
        if (!_isOperationCurrent(operationToken)) {
          return;
        }
        final stored = await _persistOrReuseDraft(
          draft: draft,
          accountContext: accountContext,
          operationToken: operationToken,
        );
        if (!_isOperationCurrent(operationToken)) {
          return;
        }
        await _submitStored(
          stored,
          accountContext: accountContext,
          operationToken: operationToken,
        );
      } on CustomSceneSubmissionException {
        if (_isOperationCurrent(operationToken)) {
          _setState(
            _recoverable(
              const CustomSceneSubmissionMessage(
                CustomSceneSubmissionMessageKey.anotherDraftPending,
              ),
            ),
          );
        }
      }
    });
    _activeSubmission = operation;
    return operation.whenComplete(() {
      if (identical(_activeSubmission, operation)) {
        _activeSubmission = null;
      }
    });
  }

  /// Uses the durable continuation from #20. This is the only automatic
  /// resume path; it never initiates another login flow.
  Future<void> resumeAfterAuthentication({required String accountContext}) {
    if (_isSafetyTerminal) {
      return Future<void>.value();
    }
    final running = _activeSubmission;
    if (running != null) {
      return running;
    }
    final operationToken = _captureOperationToken();
    final operation = _enqueue(() async {
      if (!_isOperationCurrent(operationToken)) {
        return;
      }
      _setState(
        const CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.restoring,
        ),
      );
      final resumed = await _draftContinuationCoordinator
          .readForAuthenticatedResume(accountContext: accountContext);
      if (!_isOperationCurrent(operationToken)) {
        return;
      }
      if (resumed.status !=
              CustomSceneDraftContinuationStatus.readyForSubmission ||
          resumed.draft == null) {
        _setState(_stateForResumeStatus(resumed.status));
        return;
      }
      await _submitStored(
        resumed.draft!,
        accountContext: accountContext,
        operationToken: operationToken,
      );
    });
    _activeSubmission = operation;
    return operation.whenComplete(() {
      if (identical(_activeSubmission, operation)) {
        _activeSubmission = null;
      }
    });
  }

  Future<void> resumeAfterCurrentAuthentication() async {
    if (_isSafetyTerminal) {
      return;
    }
    final operationToken = _captureOperationToken();
    final accountContext = await _loadAccountContext();
    if (!_isOperationCurrent(operationToken)) {
      return;
    }
    if (accountContext == null) {
      _setState(
        const CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.needsAuthentication,
          message: CustomSceneSubmissionMessage(
            CustomSceneSubmissionMessageKey.authenticationRequired,
          ),
        ),
      );
      return;
    }
    return resumeAfterAuthentication(accountContext: accountContext);
  }

  /// Restores only durable work. Unknown outcomes require an explicit retry,
  /// which reuses the same request identity for server reconciliation.
  Future<void> restore({required String accountContext}) {
    if (_isSafetyTerminal) {
      return Future<void>.value();
    }
    final operationToken = _captureOperationToken();
    return _enqueue(() async {
      if (_isSafetyTerminal || !_isOperationCurrent(operationToken)) {
        return;
      }
      _setState(
        const CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.restoring,
        ),
      );
      final result = await _draftStore.readResult(now: _clock().toUtc());
      if (!_isOperationCurrent(operationToken)) {
        return;
      }
      if (result.status == CustomSceneDraftReadStatus.notFound) {
        _setState(const CustomSceneSubmissionState.editing());
        return;
      }
      if (result.status == CustomSceneDraftReadStatus.expired ||
          result.status == CustomSceneDraftReadStatus.corrupt) {
        final staleDraft = result.draft;
        if (staleDraft != null) {
          await _clearExactDraftIntentIfOwned(
            staleDraft,
            operationToken: operationToken,
          );
        }
        if (_isOperationCurrent(operationToken)) {
          _setState(const CustomSceneSubmissionState.editing());
        }
        return;
      }
      if (result.status != CustomSceneDraftReadStatus.available ||
          result.draft == null) {
        _setState(
          _recoverable(
            const CustomSceneSubmissionMessage(
              CustomSceneSubmissionMessageKey.restoreUnavailable,
            ),
          ),
        );
        return;
      }
      final draft = result.draft!;
      if (!_matchesAccount(draft, accountContext)) {
        _setState(
          _recoverable(
            const CustomSceneSubmissionMessage(
              CustomSceneSubmissionMessageKey.accountChanged,
            ),
          ),
        );
        return;
      }
      if (draft.state == CustomSceneStoredDraftState.readyForHandoff) {
        _setState(
          CustomSceneSubmissionState(
            phase: CustomSceneSubmissionPhase.readyForHandoff,
            generatedContentId: draft.registeredContentId,
          ),
        );
        return;
      }
      if (draft.state == CustomSceneStoredDraftState.editing) {
        _setState(const CustomSceneSubmissionState.editing());
        return;
      }
      if (draft.state == CustomSceneStoredDraftState.awaitingAuthentication ||
          draft.state == CustomSceneStoredDraftState.authenticationResolved) {
        await _resumeStoredDraftAfterAuthentication(
          draft,
          accountContext: accountContext,
          operationToken: operationToken,
        );
        return;
      }
      if (draft.state == CustomSceneStoredDraftState.submitting) {
        await _draftStore.write(
          draft.copyWith(state: CustomSceneStoredDraftState.unknownOutcome),
        );
        if (!_isOperationCurrent(operationToken)) {
          return;
        }
      }
      _setState(
        const CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.unknownOutcome,
          message: CustomSceneSubmissionMessage(
            CustomSceneSubmissionMessageKey.previousRequestUnknown,
          ),
        ),
      );
    });
  }

  Future<void> retry() {
    if (_isSafetyTerminal) {
      return Future<void>.value();
    }
    final running = _activeSubmission;
    if (running != null) {
      return running;
    }
    final operationToken = _captureOperationToken();
    final operation = _enqueue(() async {
      if (!_isOperationCurrent(operationToken)) {
        return;
      }
      final accountContext = await _loadAccountContext();
      if (!_isOperationCurrent(operationToken)) {
        return;
      }
      if (accountContext == null) {
        _setState(
          const CustomSceneSubmissionState(
            phase: CustomSceneSubmissionPhase.needsAuthentication,
            message: CustomSceneSubmissionMessage(
              CustomSceneSubmissionMessageKey.authenticationRequired,
            ),
          ),
        );
        return;
      }
      final result = await _draftStore.readResult(now: _clock().toUtc());
      if (!_isOperationCurrent(operationToken)) {
        return;
      }
      if (result.status != CustomSceneDraftReadStatus.available ||
          result.draft == null) {
        _setState(
          _recoverable(
            const CustomSceneSubmissionMessage(
              CustomSceneSubmissionMessageKey.retryUnavailable,
            ),
          ),
        );
        return;
      }
      final draft = result.draft!;
      if (!_matchesAccount(draft, accountContext)) {
        _setState(
          _recoverable(
            const CustomSceneSubmissionMessage(
              CustomSceneSubmissionMessageKey.accountChanged,
            ),
          ),
        );
        return;
      }
      if (draft.state == CustomSceneStoredDraftState.readyForHandoff) {
        _setState(
          CustomSceneSubmissionState(
            phase: CustomSceneSubmissionPhase.readyForHandoff,
            generatedContentId: draft.registeredContentId,
          ),
        );
        return;
      }
      if (draft.state ==
              CustomSceneStoredDraftState.approvedPendingRegistration &&
          _approvedMomentPendingRegistration != null) {
        await _registerApprovedMoment(
          accountContext: accountContext,
          moment: _approvedMomentPendingRegistration!,
          draft: draft,
          operationToken: operationToken,
        );
        return;
      }
      await _submitStored(
        draft,
        accountContext: accountContext,
        operationToken: operationToken,
      );
    });
    _activeSubmission = operation;
    return operation.whenComplete(() {
      if (identical(_activeSubmission, operation)) {
        _activeSubmission = null;
      }
    });
  }

  /// App-level recovery owns navigation. It reports a failed route attempt
  /// here without changing the durable intent.
  void markHandoffRouteFailed() {
    final generatedContentId = _state.generatedContentId;
    if (!_state.canOpenPreparedContent || generatedContentId == null) {
      return;
    }
    _setState(
      CustomSceneSubmissionState(
        phase: CustomSceneSubmissionPhase.handoffFailed,
        message: const CustomSceneSubmissionMessage(
          CustomSceneSubmissionMessageKey.handoffRouteFailed,
        ),
        generatedContentId: generatedContentId,
      ),
    );
  }

  /// Explicit abandonment is distinct from successful Care Turn confirmation.
  Future<void> abandonPreparedContent() {
    return _enqueue(() async {
      if (!_state.canOpenPreparedContent) {
        return;
      }
      try {
        await _draftContinuationCoordinator.cancel();
      } on Object {
        // Abandonment still exits prepared state when local cleanup fails.
      } finally {
        _approvedMomentPendingRegistration = null;
        _setState(const CustomSceneSubmissionState.editing());
      }
    });
  }

  Future<void> cancel() {
    _operationEpoch += 1;
    _approvedMomentPendingRegistration = null;
    final hasRequestInFlight = _activeSubmission != null;
    _setState(const CustomSceneSubmissionState.editing());
    if (hasRequestInFlight) {
      // The server request is not claimed as cancelled. Its durable request
      // identity is retained by the running operation for later reconciliation.
      return Future<void>.value();
    }
    return _enqueue(() async {
      try {
        await _draftContinuationCoordinator.cancel();
      } on Object {
        // Durable cleanup is best effort; editing remains the visible state.
      } finally {
        _setState(const CustomSceneSubmissionState.editing());
      }
    });
  }

  /// Clears a terminal safety notice before the user enters a new description.
  Future<void> modifyDescription() => cancel();

  Future<void> _resumeStoredDraftAfterAuthentication(
    CustomSceneStoredDraft draft, {
    required String accountContext,
    required _CustomSceneOperationToken operationToken,
  }) async {
    final resumed = await _draftContinuationCoordinator
        .readForAuthenticatedResume(accountContext: accountContext);
    if (!_isOperationCurrent(operationToken)) {
      return;
    }
    if (resumed.status !=
            CustomSceneDraftContinuationStatus.readyForSubmission ||
        resumed.draft == null ||
        resumed.draft!.draftId != draft.draftId) {
      _setState(_stateForResumeStatus(resumed.status));
      return;
    }
    await _submitStored(
      resumed.draft!,
      accountContext: accountContext,
      operationToken: operationToken,
    );
  }

  Future<void> _submitStored(
    CustomSceneStoredDraft draft, {
    required String? accountContext,
    _CustomSceneOperationToken? operationToken,
  }) async {
    final token = operationToken ?? _captureOperationToken();
    if (!_isOperationCurrent(token)) {
      return;
    }
    if (draft.state == CustomSceneStoredDraftState.readyForHandoff) {
      _setState(
        CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.readyForHandoff,
          generatedContentId: draft.registeredContentId,
        ),
      );
      return;
    }
    if (accountContext == null) {
      await _beginAuthentication(draft, operationToken: token);
      return;
    }
    if (!_matchesAccount(draft, accountContext)) {
      if (_isOperationCurrent(token)) {
        _setState(
          _recoverable(
            const CustomSceneSubmissionMessage(
              CustomSceneSubmissionMessageKey.accountChanged,
            ),
          ),
        );
      }
      return;
    }
    final submitting = draft.copyWith(
      state: CustomSceneStoredDraftState.submitting,
      expectedAccountContext: accountContext,
      clearRegisteredContentId: true,
    );
    try {
      await _draftStore.write(submitting);
    } on Object {
      if (_isOperationCurrent(token)) {
        _setState(
          _recoverable(
            const CustomSceneSubmissionMessage(
              CustomSceneSubmissionMessageKey.saveUnavailable,
            ),
          ),
        );
      }
      return;
    }
    if (!_isOperationCurrent(token)) {
      return;
    }
    final accountStillCurrent = await _isAccountContextCurrent(accountContext);
    if (!_isOperationCurrent(token)) {
      return;
    }
    if (!accountStillCurrent) {
      _operationEpoch += 1;
      return;
    }
    _setState(
      const CustomSceneSubmissionState(
        phase: CustomSceneSubmissionPhase.submitting,
      ),
    );
    var requestStarted = false;
    try {
      if (!_isOperationCurrent(token)) {
        return;
      }
      requestStarted = true;
      final result = await _repository.generate(submitting.toDraft());
      if (!_isOperationCurrent(token)) {
        if (!_isSafetyTerminal) {
          await _markUnknownOutcome(
            submitting,
            publish: false,
            accountGeneration: token.accountGeneration,
          );
        }
        return;
      }
      final resultAccountStillCurrent = await _isAccountContextCurrent(
        accountContext,
      );
      if (!_isOperationCurrent(token)) {
        if (requestStarted && !_isSafetyTerminal) {
          await _markUnknownOutcome(
            submitting,
            publish: false,
            accountGeneration: token.accountGeneration,
          );
        }
        return;
      }
      if (!resultAccountStillCurrent) {
        _operationEpoch += 1;
        await _markUnknownOutcome(
          submitting,
          publish: false,
          accountGeneration: token.accountGeneration,
        );
        return;
      }
      switch (result) {
        case GeneratedSceneResult(:final moment, :final policyVersion):
          if (policyVersion != generatedCareSafetyPolicyVersion ||
              moment.safetyPolicyVersion != generatedCareSafetyPolicyVersion ||
              moment.contentRefreshEpoch !=
                  generatedCareMomentContentRefreshEpoch) {
            await _publishSafety(
              phase: CustomSceneSubmissionPhase.assessmentUnavailable,
              safety: healthAssessmentUnavailableNotice,
              operationToken: token,
              draft: submitting,
            );
            return;
          }
          final pendingRegistration = submitting.copyWith(
            state: CustomSceneStoredDraftState.approvedPendingRegistration,
            registeredContentId: moment.generatedContentId,
            safetyPolicyVersion: moment.safetyPolicyVersion,
            contentRefreshEpoch: moment.contentRefreshEpoch,
          );
          await _draftStore.write(pendingRegistration);
          if (!_isOperationCurrent(token)) {
            if (!_isSafetyTerminal) {
              await _markUnknownOutcome(
                submitting,
                publish: false,
                accountGeneration: token.accountGeneration,
              );
            }
            return;
          }
          _approvedMomentPendingRegistration = moment;
          _setState(
            const CustomSceneSubmissionState(
              phase: CustomSceneSubmissionPhase.generated,
            ),
          );
          await _registerApprovedMoment(
            accountContext: accountContext,
            moment: moment,
            draft: pendingRegistration,
            operationToken: token,
          );
        case HealthSafetyResult(:final safety):
          await _publishSafety(
            phase: CustomSceneSubmissionPhase.healthSafety,
            safety: safety,
            operationToken: token,
            draft: submitting,
          );
        case AssessmentUnavailableResult(:final safety):
          await _publishSafety(
            phase: CustomSceneSubmissionPhase.assessmentUnavailable,
            safety: safety,
            operationToken: token,
            draft: submitting,
          );
      }
    } on CustomSceneFailure catch (failure) {
      if (!_isOperationCurrent(token)) {
        if (requestStarted && !_isSafetyTerminal) {
          await _markUnknownOutcome(
            submitting,
            publish: false,
            accountGeneration: token.accountGeneration,
          );
        }
        return;
      }
      await _handleFailure(failure, submitting, operationToken: token);
    } on Object {
      await _markUnknownOutcome(
        submitting,
        publish: _isOperationCurrent(token),
        accountGeneration: token.accountGeneration,
      );
    }
  }

  Future<void> _registerApprovedMoment({
    required String accountContext,
    required GeneratedCareMoment moment,
    required CustomSceneStoredDraft draft,
    required _CustomSceneOperationToken operationToken,
  }) async {
    if (!_isOperationCurrent(operationToken)) {
      return;
    }
    _setState(
      const CustomSceneSubmissionState(
        phase: CustomSceneSubmissionPhase.registeringCareMoment,
      ),
    );
    try {
      await _approvedContentRegistrar.register(
        accountContext: accountContext,
        moment: moment,
      );
      if (!_isOperationCurrent(operationToken)) {
        return;
      }
      final accountStillCurrent = await _isAccountContextCurrent(
        accountContext,
      );
      if (!_isOperationCurrent(operationToken)) {
        return;
      }
      if (!accountStillCurrent) {
        _operationEpoch += 1;
        return;
      }
      final readyForHandoff = draft.copyWith(
        state: CustomSceneStoredDraftState.readyForHandoff,
        expectedAccountContext: accountContext,
        registeredContentId: moment.generatedContentId,
        safetyPolicyVersion: moment.safetyPolicyVersion,
        contentRefreshEpoch: moment.contentRefreshEpoch,
      );
      await _draftStore.write(readyForHandoff);
      if (!_isOperationCurrent(operationToken)) {
        return;
      }
      try {
        await _draftContinuationCoordinator
            .clearAuthenticationContinuationIfMatches(
              draftId: readyForHandoff.draftId,
              clientRequestId: readyForHandoff.requestIdentity.clientRequestId,
              expectedAccountContext: readyForHandoff.expectedAccountContext,
            );
      } on Object {
        // Ready intent is committed. A stale authentication continuation is
        // removed by confirmation or lifecycle cleanup.
      }
      _approvedMomentPendingRegistration = null;
      if (!_isOperationCurrent(operationToken)) {
        return;
      }
      _setState(
        CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.readyForHandoff,
          generatedContentId: moment.generatedContentId,
        ),
      );
    } on Object {
      if (_isOperationCurrent(operationToken)) {
        _setState(
          _recoverable(
            const CustomSceneSubmissionMessage(
              CustomSceneSubmissionMessageKey.preparedContentSaveFailed,
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleFailure(
    CustomSceneFailure failure,
    CustomSceneStoredDraft submitting, {
    required _CustomSceneOperationToken operationToken,
  }) async {
    if (failure.kind == CustomSceneFailureKind.authenticationRequired) {
      await _beginAuthentication(submitting, operationToken: operationToken);
      return;
    }
    if (_isUnknownOutcome(failure)) {
      await _markUnknownOutcome(submitting, operationToken: operationToken);
      return;
    }
    if (failure.kind == CustomSceneFailureKind.profileUnavailable ||
        failure.kind == CustomSceneFailureKind.householdAccessRequired ||
        failure.kind == CustomSceneFailureKind.sharedProfileUnavailable ||
        failure.kind == CustomSceneFailureKind.presetSceneUnavailable) {
      // These failures happen before generation reservation. Retaining the
      // local intent would turn a deterministic input/context miss into an
      // unrelated pending-draft error on the next attempt.
      await _discardUnsubmittedDraft(
        submitting,
        operationToken: operationToken,
      );
      if (!_isOperationCurrent(operationToken)) {
        return;
      }
    }
    _setState(
      _recoverable(
        null,
        failure: failure,
        canCancelRetainedDraft:
            failure.kind == CustomSceneFailureKind.requestTerminal,
      ),
    );
  }

  Future<void> _discardUnsubmittedDraft(
    CustomSceneStoredDraft submitting, {
    required _CustomSceneOperationToken operationToken,
  }) async {
    if (!_isOperationCurrent(operationToken)) {
      return;
    }
    try {
      final result = await _draftStore.readResult(now: _clock().toUtc());
      if (!_isOperationCurrent(operationToken)) {
        return;
      }
      final stored = result.draft;
      if (result.status != CustomSceneDraftReadStatus.available ||
          stored == null ||
          stored.draftId != submitting.draftId ||
          stored.requestIdentity.clientRequestId !=
              submitting.requestIdentity.clientRequestId ||
          stored.expectedAccountContext != submitting.expectedAccountContext) {
        return;
      }
      await _clearExactDraftIntentIfOwned(
        stored,
        operationToken: operationToken,
      );
    } on Object {
      // Keep the deterministic profile error visible if local cleanup fails.
    }
  }

  Future<void> _clearExactDraftIntentIfOwned(
    CustomSceneStoredDraft draft, {
    required _CustomSceneOperationToken operationToken,
  }) async {
    if (!_isOperationCurrent(operationToken)) {
      return;
    }
    try {
      await _draftStore.deleteIfMatches(
        draftId: draft.draftId,
        clientRequestId: draft.requestIdentity.clientRequestId,
        expectedAccountContext: draft.expectedAccountContext,
        now: _clock().toUtc(),
      );
    } on Object {
      // Best effort cleanup must not replace the primary state.
    }
    if (!_isOperationCurrent(operationToken)) {
      return;
    }
    try {
      await _draftContinuationCoordinator
          .clearAuthenticationContinuationIfMatches(
            draftId: draft.draftId,
            clientRequestId: draft.requestIdentity.clientRequestId,
            expectedAccountContext: draft.expectedAccountContext,
          );
    } on Object {
      // Best effort cleanup must not replace the primary state.
    }
  }

  Future<void> _beginAuthentication(
    CustomSceneStoredDraft stored, {
    _CustomSceneOperationToken? operationToken,
  }) async {
    try {
      await _draftContinuationCoordinator.beginAuthentication(
        draft: stored.toDraft(),
        expectedAccountContext: stored.expectedAccountContext,
      );
      if (operationToken != null && !_isOperationCurrent(operationToken)) {
        return;
      }
      _setState(
        const CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.needsAuthentication,
          message: CustomSceneSubmissionMessage(
            CustomSceneSubmissionMessageKey.authenticationRequired,
          ),
        ),
      );
    } on Object {
      if (operationToken == null || _isOperationCurrent(operationToken)) {
        _setState(
          _recoverable(
            const CustomSceneSubmissionMessage(
              CustomSceneSubmissionMessageKey.saveUnavailable,
            ),
          ),
        );
      }
    }
  }

  Future<void> _markUnknownOutcome(
    CustomSceneStoredDraft draft, {
    bool publish = true,
    _CustomSceneOperationToken? operationToken,
    int? accountGeneration,
  }) async {
    if (accountGeneration != null && accountGeneration != _accountGeneration) {
      return;
    }
    if (operationToken != null &&
        operationToken.accountGeneration != _accountGeneration) {
      return;
    }
    final result = await _draftStore.readResult(now: _clock().toUtc());
    if (accountGeneration != null && accountGeneration != _accountGeneration) {
      return;
    }
    final stored = result.draft;
    if (result.status != CustomSceneDraftReadStatus.available ||
        stored == null ||
        stored.draftId != draft.draftId ||
        stored.requestIdentity.clientRequestId !=
            draft.requestIdentity.clientRequestId ||
        stored.expectedAccountContext != draft.expectedAccountContext) {
      return;
    }
    try {
      await _draftStore.write(
        stored.copyWith(state: CustomSceneStoredDraftState.unknownOutcome),
      );
    } on Object {
      // The request identity remains in the previous durable snapshot when
      // storage cannot update the transient phase.
    }
    if (publish &&
        (operationToken == null || _isOperationCurrent(operationToken))) {
      _setState(
        const CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.unknownOutcome,
          message: CustomSceneSubmissionMessage(
            CustomSceneSubmissionMessageKey.unknownOutcome,
          ),
        ),
      );
    }
  }

  Future<CustomSceneStoredDraft> _persistOrReuseDraft({
    required CustomSceneDraft draft,
    required String? accountContext,
    required _CustomSceneOperationToken operationToken,
  }) async {
    final result = await _draftStore.readResult(now: _clock().toUtc());
    if (!_isOperationCurrent(operationToken)) {
      throw const CustomSceneSubmissionException();
    }
    switch (result.status) {
      case CustomSceneDraftReadStatus.available:
        final stored = result.draft!;
        if (stored.requestIdentity.clientRequestId !=
                draft.requestIdentity.clientRequestId ||
            stored.text != draft.text ||
            stored.entrySource != draft.entrySource) {
          throw const CustomSceneSubmissionException();
        }
        if (accountContext != null &&
            !_matchesAccount(stored, accountContext)) {
          throw const CustomSceneSubmissionException();
        }
        return stored;
      case CustomSceneDraftReadStatus.notFound:
      case CustomSceneDraftReadStatus.expired:
      case CustomSceneDraftReadStatus.corrupt:
        final createdAt = _clock().toUtc();
        final stored = CustomSceneStoredDraft(
          draftId: _draftIdGenerator(),
          text: draft.text,
          entrySource: draft.entrySource,
          requestIdentity: draft.requestIdentity,
          state: CustomSceneStoredDraftState.editing,
          createdAt: createdAt,
          expiresAt: createdAt.add(const Duration(minutes: 15)),
          expectedAccountContext: accountContext,
        );
        if (!_isOperationCurrent(operationToken)) {
          throw const CustomSceneSubmissionException();
        }
        await _draftStore.write(stored);
        return stored;
      case CustomSceneDraftReadStatus.ioFailure:
        throw const CustomSceneSubmissionException();
    }
  }

  Future<String?> _loadAccountContext() async {
    try {
      final value = (await _accountContextLoader())?.trim();
      return value == null || value.isEmpty ? null : value;
    } on Object {
      return null;
    }
  }

  bool _matchesAccount(CustomSceneStoredDraft draft, String accountContext) {
    final expected = draft.expectedAccountContext;
    return expected == null || expected == accountContext.trim();
  }

  bool _isUnknownOutcome(CustomSceneFailure failure) {
    return failure.kind == CustomSceneFailureKind.timeout ||
        failure.kind == CustomSceneFailureKind.network ||
        failure.kind == CustomSceneFailureKind.generationInProgress ||
        (failure.kind == CustomSceneFailureKind.unavailable &&
            failure.retryable);
  }

  Future<bool> _isAccountContextCurrent(String expectedAccountContext) async {
    try {
      final current = (await _accountContextLoader())?.trim();
      return current == expectedAccountContext.trim();
    } on Object {
      return false;
    }
  }

  Future<void> _publishSafety({
    required CustomSceneSubmissionPhase phase,
    required HealthSafetyNotice safety,
    required _CustomSceneOperationToken operationToken,
    required CustomSceneStoredDraft draft,
  }) async {
    if (!_isOperationCurrent(operationToken)) {
      return;
    }
    final cleanupSnapshot = _CustomSceneDraftCleanupSnapshot.fromDraft(draft);
    _operationEpoch += 1;
    final safetyToken = _CustomSceneOperationToken(
      operationEpoch: _operationEpoch,
      accountGeneration: operationToken.accountGeneration,
    );
    _approvedMomentPendingRegistration = null;
    try {
      await _audioStopper.stopActive().timeout(safetyAudioStopTimeout);
    } on Object {
      // A hung or failed audio stop cannot delay the safety state indefinitely.
    }
    if (!_isOperationCurrent(safetyToken)) {
      return;
    }
    _setState(
      CustomSceneSubmissionState(
        phase: phase,
        message: safety.messageZh,
        safetyNotice: safety,
      ),
    );
    await _clearExactDraftSnapshot(cleanupSnapshot);
  }

  /// Health notices can synchronously invalidate the operation when the user
  /// taps 修改描述 from the listener. Cleanup still targets only the exact
  /// request that produced the notice, independent of the live operation token.
  Future<void> _clearExactDraftSnapshot(
    _CustomSceneDraftCleanupSnapshot snapshot,
  ) async {
    try {
      await _draftStore.deleteIfMatches(
        draftId: snapshot.draftId,
        clientRequestId: snapshot.clientRequestId,
        expectedAccountContext: snapshot.expectedAccountContext,
        now: _clock().toUtc(),
      );
    } on Object {
      // Best effort cleanup must not replace the primary safety state.
    }
    try {
      await _draftContinuationCoordinator
          .clearAuthenticationContinuationIfMatches(
            draftId: snapshot.draftId,
            clientRequestId: snapshot.clientRequestId,
            expectedAccountContext: snapshot.expectedAccountContext,
          );
    } on Object {
      // Best effort cleanup must not replace the primary safety state.
    }
  }

  _CustomSceneOperationToken _captureOperationToken() {
    return _CustomSceneOperationToken(
      operationEpoch: _operationEpoch,
      accountGeneration: _accountGeneration,
    );
  }

  bool _isOperationCurrent(_CustomSceneOperationToken operationToken) {
    return !_disposed &&
        operationToken.operationEpoch == _operationEpoch &&
        operationToken.accountGeneration == _accountGeneration;
  }

  CustomSceneSubmissionState _stateForResumeStatus(
    CustomSceneDraftContinuationStatus status,
  ) {
    return switch (status) {
      CustomSceneDraftContinuationStatus.notFound ||
      CustomSceneDraftContinuationStatus.expired => _recoverable(
        const CustomSceneSubmissionMessage(
          CustomSceneSubmissionMessageKey.draftExpired,
        ),
      ),
      CustomSceneDraftContinuationStatus.accountMismatch => _recoverable(
        const CustomSceneSubmissionMessage(
          CustomSceneSubmissionMessageKey.accountChanged,
        ),
      ),
      CustomSceneDraftContinuationStatus.unavailable => _recoverable(
        const CustomSceneSubmissionMessage(
          CustomSceneSubmissionMessageKey.draftRecoveryUnavailable,
        ),
      ),
      CustomSceneDraftContinuationStatus.inconsistent ||
      CustomSceneDraftContinuationStatus.otherIntentPending => _recoverable(
        const CustomSceneSubmissionMessage(
          CustomSceneSubmissionMessageKey.draftInconsistent,
        ),
      ),
      CustomSceneDraftContinuationStatus.readyForAuthentication =>
        const CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.needsAuthentication,
          message: CustomSceneSubmissionMessage(
            CustomSceneSubmissionMessageKey.authenticationRequired,
          ),
        ),
      CustomSceneDraftContinuationStatus.readyForSubmission =>
        const CustomSceneSubmissionState.editing(),
    };
  }

  CustomSceneSubmissionState _recoverable(
    CustomSceneSubmissionMessage? message, {
    CustomSceneFailure? failure,
    bool canCancelRetainedDraft = false,
  }) {
    return CustomSceneSubmissionState(
      phase: CustomSceneSubmissionPhase.recoverableError,
      message: message,
      failure: failure,
      canCancelRetainedDraft: canCancelRetainedDraft,
    );
  }

  Future<T> _enqueue<T>(Future<T> Function() mutation) {
    final running = _mutationTail.then((_) => mutation());
    _mutationTail = running.then<void>((_) {}, onError: (_, _) {});
    return running;
  }

  void _setState(CustomSceneSubmissionState state) {
    if (_disposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _operationEpoch += 1;
    _approvedMomentPendingRegistration = null;
    _disposed = true;
    super.dispose();
  }

  bool get _isSafetyTerminal =>
      _state.phase == CustomSceneSubmissionPhase.healthSafety ||
      _state.phase == CustomSceneSubmissionPhase.assessmentUnavailable;

  static String _defaultDraftId() {
    return 'custom_scene_draft_${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }
}

class CustomSceneSubmissionException implements Exception {
  const CustomSceneSubmissionException();
}
