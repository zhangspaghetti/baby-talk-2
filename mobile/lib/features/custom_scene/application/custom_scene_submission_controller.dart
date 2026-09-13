import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_draft_store.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_failure.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_repository.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_result.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_stored_draft.dart';
import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';

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

class _NoopCustomSceneAudioStopper implements CustomSceneAudioStopper {
  const _NoopCustomSceneAudioStopper();

  @override
  Future<void> stopActive() async {}
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

@immutable
class CustomSceneSubmissionState {
  const CustomSceneSubmissionState({
    required this.phase,
    this.message,
    this.generatedContentId,
    this.canCancelRetainedDraft = false,
    this.safetyNotice,
  });

  const CustomSceneSubmissionState.editing()
    : phase = CustomSceneSubmissionPhase.editing,
      message = null,
      generatedContentId = null,
      canCancelRetainedDraft = false,
      safetyNotice = null;

  final CustomSceneSubmissionPhase phase;
  final String? message;
  final String? generatedContentId;
  final bool canCancelRetainedDraft;
  final HealthSafetyNotice? safetyNotice;

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
  bool _disposed = false;

  static const _audioStopTimeout = Duration(milliseconds: 250);

  CustomSceneSubmissionState get state => _state;

  Future<void> submit(CustomSceneDraft draft) {
    if (_isSafetyTerminal) {
      return Future<void>.value();
    }
    final running = _activeSubmission;
    if (running != null) {
      return running;
    }
    final operation = _enqueue(() async {
      try {
        final accountContext = await _loadAccountContext();
        final stored = await _persistOrReuseDraft(
          draft: draft,
          accountContext: accountContext,
        );
        await _submitStored(stored, accountContext: accountContext);
      } on CustomSceneSubmissionException {
        _setState(_recoverable('当前已有另一段描述待处理，请先完成或取消。'));
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
    final operation = _enqueue(() async {
      _setState(
        const CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.restoring,
        ),
      );
      final resumed = await _draftContinuationCoordinator
          .readForAuthenticatedResume(accountContext: accountContext);
      if (resumed.status !=
              CustomSceneDraftContinuationStatus.readyForSubmission ||
          resumed.draft == null) {
        _setState(_stateForResumeStatus(resumed.status));
        return;
      }
      await _submitStored(resumed.draft!, accountContext: accountContext);
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
    final accountContext = await _loadAccountContext();
    if (accountContext == null) {
      _setState(
        const CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.needsAuthentication,
          message: '请先登录后再生成。',
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
    return _enqueue(() async {
      if (_isSafetyTerminal) {
        return;
      }
      _setState(
        const CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.restoring,
        ),
      );
      final result = await _draftStore.readResult(now: _clock().toUtc());
      if (result.status == CustomSceneDraftReadStatus.notFound) {
        _setState(const CustomSceneSubmissionState.editing());
        return;
      }
      if (result.status == CustomSceneDraftReadStatus.expired ||
          result.status == CustomSceneDraftReadStatus.corrupt) {
        await _draftContinuationCoordinator.cancel();
        _setState(const CustomSceneSubmissionState.editing());
        return;
      }
      if (result.status != CustomSceneDraftReadStatus.available ||
          result.draft == null) {
        _setState(_recoverable('暂时无法恢复这次描述，请重新填写。'));
        return;
      }
      final draft = result.draft!;
      if (!_matchesAccount(draft, accountContext)) {
        _setState(_recoverable('账号已切换，请重新填写描述。'));
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
        );
        return;
      }
      if (draft.state == CustomSceneStoredDraftState.submitting) {
        await _draftStore.write(
          draft.copyWith(state: CustomSceneStoredDraftState.unknownOutcome),
        );
      }
      _setState(
        const CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.unknownOutcome,
          message: '上次请求的结果尚未确认，请重试以继续。',
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
    final operation = _enqueue(() async {
      final accountContext = await _loadAccountContext();
      if (accountContext == null) {
        _setState(
          const CustomSceneSubmissionState(
            phase: CustomSceneSubmissionPhase.needsAuthentication,
            message: '请先登录后再生成。',
          ),
        );
        return;
      }
      final result = await _draftStore.readResult(now: _clock().toUtc());
      if (result.status != CustomSceneDraftReadStatus.available ||
          result.draft == null) {
        _setState(_recoverable('暂时无法继续，请重新填写描述。'));
        return;
      }
      final draft = result.draft!;
      if (!_matchesAccount(draft, accountContext)) {
        _setState(_recoverable('账号已切换，请重新填写描述。'));
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
          operationEpoch: _operationEpoch,
        );
        return;
      }
      await _submitStored(draft, accountContext: accountContext);
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
        message: '暂时无法打开照护内容，请再试一次。',
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
      await _draftContinuationCoordinator.cancel();
      _approvedMomentPendingRegistration = null;
      _setState(const CustomSceneSubmissionState.editing());
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
    return _enqueue(_draftContinuationCoordinator.cancel);
  }

  /// Clears a terminal safety notice before the user enters a new description.
  Future<void> modifyDescription() => cancel();

  Future<void> _resumeStoredDraftAfterAuthentication(
    CustomSceneStoredDraft draft, {
    required String accountContext,
  }) async {
    final resumed = await _draftContinuationCoordinator
        .readForAuthenticatedResume(accountContext: accountContext);
    if (resumed.status !=
            CustomSceneDraftContinuationStatus.readyForSubmission ||
        resumed.draft == null ||
        resumed.draft!.draftId != draft.draftId) {
      _setState(_stateForResumeStatus(resumed.status));
      return;
    }
    await _submitStored(resumed.draft!, accountContext: accountContext);
  }

  Future<void> _submitStored(
    CustomSceneStoredDraft draft, {
    required String? accountContext,
  }) async {
    final operationEpoch = _operationEpoch;
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
      if (_isOperationCurrent(operationEpoch)) {
        await _beginAuthentication(draft, operationEpoch: operationEpoch);
      }
      return;
    }
    if (!_matchesAccount(draft, accountContext)) {
      _setState(_recoverable('账号已切换，请重新填写描述。'));
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
      _setState(_recoverable('暂时无法保存描述，请稍后再试。'));
      return;
    }
    if (!_isOperationCurrent(operationEpoch)) {
      await _draftContinuationCoordinator.cancel();
      return;
    }
    final accountStillCurrent = await _isAccountContextCurrent(accountContext);
    if (!_isOperationCurrent(operationEpoch)) {
      await _draftContinuationCoordinator.cancel();
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
    try {
      if (!_isOperationCurrent(operationEpoch)) {
        await _draftContinuationCoordinator.cancel();
        return;
      }
      final result = await _repository.generate(submitting.toDraft());
      if (!_isOperationCurrent(operationEpoch)) {
        if (!_isSafetyTerminal) {
          await _markUnknownOutcome(submitting, publish: false);
        }
        return;
      }
      if (!await _isAccountContextCurrent(accountContext)) {
        _operationEpoch += 1;
        await _markUnknownOutcome(submitting, publish: false);
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
              operationEpoch: operationEpoch,
              draftId: submitting.draftId,
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
          _approvedMomentPendingRegistration = moment;
          if (!_isOperationCurrent(operationEpoch)) {
            if (!_isSafetyTerminal) {
              await _markUnknownOutcome(pendingRegistration, publish: false);
            }
            return;
          }
          _setState(
            const CustomSceneSubmissionState(
              phase: CustomSceneSubmissionPhase.generated,
            ),
          );
          await _registerApprovedMoment(
            accountContext: accountContext,
            moment: moment,
            draft: pendingRegistration,
            operationEpoch: operationEpoch,
          );
        case HealthSafetyResult(:final safety):
          await _publishSafety(
            phase: CustomSceneSubmissionPhase.healthSafety,
            safety: safety,
            operationEpoch: operationEpoch,
            draftId: submitting.draftId,
          );
        case AssessmentUnavailableResult(:final safety):
          await _publishSafety(
            phase: CustomSceneSubmissionPhase.assessmentUnavailable,
            safety: safety,
            operationEpoch: operationEpoch,
            draftId: submitting.draftId,
          );
      }
    } on CustomSceneFailure catch (failure) {
      if (!_isOperationCurrent(operationEpoch)) {
        await _markUnknownOutcome(submitting, publish: false);
        return;
      }
      await _handleFailure(failure, submitting, operationEpoch: operationEpoch);
    } on Object {
      await _markUnknownOutcome(
        submitting,
        publish: _isOperationCurrent(operationEpoch),
        operationEpoch: operationEpoch,
      );
    }
  }

  Future<void> _registerApprovedMoment({
    required String accountContext,
    required GeneratedCareMoment moment,
    required CustomSceneStoredDraft draft,
    required int operationEpoch,
  }) async {
    if (!_isOperationCurrent(operationEpoch)) {
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
      if (!_isOperationCurrent(operationEpoch)) {
        return;
      }
      final accountStillCurrent = await _isAccountContextCurrent(
        accountContext,
      );
      if (!_isOperationCurrent(operationEpoch)) {
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
      if (!_isOperationCurrent(operationEpoch)) {
        return;
      }
      try {
        await _draftContinuationCoordinator.clearAuthenticationContinuation(
          draftId: readyForHandoff.draftId,
        );
      } on Object {
        // Ready intent is committed. A stale authentication continuation is
        // removed by confirmation or lifecycle cleanup.
      }
      _approvedMomentPendingRegistration = null;
      if (!_isOperationCurrent(operationEpoch)) {
        return;
      }
      _setState(
        CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.readyForHandoff,
          generatedContentId: moment.generatedContentId,
        ),
      );
    } on Object {
      if (_isOperationCurrent(operationEpoch)) {
        _setState(_recoverable('内容已准备好，但暂时无法保存。请重试以继续。'));
      }
    }
  }

  Future<void> _handleFailure(
    CustomSceneFailure failure,
    CustomSceneStoredDraft submitting, {
    required int operationEpoch,
  }) async {
    if (failure.kind == CustomSceneFailureKind.authenticationRequired) {
      await _beginAuthentication(submitting, operationEpoch: operationEpoch);
      return;
    }
    if (_isUnknownOutcome(failure)) {
      await _markUnknownOutcome(submitting, operationEpoch: operationEpoch);
      return;
    }
    if (failure.kind == CustomSceneFailureKind.profileUnavailable) {
      // Profile resolution happens before the discovery request. There is no
      // server-side request to reconcile, so retaining this local intent would
      // turn a deterministic profile miss into an unrelated "pending draft"
      // error on the next attempt.
      await _discardUnsubmittedDraft(submitting);
    }
    if (!_isOperationCurrent(operationEpoch)) {
      return;
    }
    _setState(
      _recoverable(
        failure.presentationMessage,
        canCancelRetainedDraft:
            failure.kind == CustomSceneFailureKind.requestTerminal,
      ),
    );
  }

  Future<void> _discardUnsubmittedDraft(
    CustomSceneStoredDraft submitting,
  ) async {
    try {
      final result = await _draftStore.readResult(now: _clock().toUtc());
      final stored = result.draft;
      if (result.status != CustomSceneDraftReadStatus.available ||
          stored == null ||
          stored.draftId != submitting.draftId ||
          stored.requestIdentity.clientRequestId !=
              submitting.requestIdentity.clientRequestId) {
        return;
      }
      await _draftContinuationCoordinator.cancel();
    } on Object {
      // Keep the deterministic profile error visible if local cleanup fails.
    }
  }

  Future<void> _beginAuthentication(
    CustomSceneStoredDraft stored, {
    int? operationEpoch,
  }) async {
    try {
      await _draftContinuationCoordinator.beginAuthentication(
        draft: stored.toDraft(),
        expectedAccountContext: stored.expectedAccountContext,
      );
      if (operationEpoch != null && !_isOperationCurrent(operationEpoch)) {
        return;
      }
      _setState(
        const CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.needsAuthentication,
          message: '请先登录后再生成。',
        ),
      );
    } on Object {
      if (operationEpoch == null || _isOperationCurrent(operationEpoch)) {
        _setState(_recoverable('暂时无法保存描述，请稍后再试。'));
      }
    }
  }

  Future<void> _markUnknownOutcome(
    CustomSceneStoredDraft draft, {
    bool publish = true,
    int? operationEpoch,
  }) async {
    try {
      await _draftStore.write(
        draft.copyWith(state: CustomSceneStoredDraftState.unknownOutcome),
      );
    } on Object {
      // The request identity remains in the previous durable snapshot when
      // storage cannot update the transient phase.
    }
    if (publish &&
        (operationEpoch == null || _isOperationCurrent(operationEpoch))) {
      _setState(
        const CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.unknownOutcome,
          message: '结果尚未确认，请重试以继续。',
        ),
      );
    }
  }

  Future<CustomSceneStoredDraft> _persistOrReuseDraft({
    required CustomSceneDraft draft,
    required String? accountContext,
  }) async {
    final result = await _draftStore.readResult(now: _clock().toUtc());
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
    required int operationEpoch,
    required String draftId,
  }) async {
    if (!_isOperationCurrent(operationEpoch)) {
      return;
    }
    _operationEpoch += 1;
    final safetyEpoch = _operationEpoch;
    _approvedMomentPendingRegistration = null;
    try {
      await _audioStopper.stopActive().timeout(_audioStopTimeout);
    } on Object {
      // A hung or failed audio stop cannot delay the safety state indefinitely.
    }
    if (!_isOperationCurrent(safetyEpoch)) {
      return;
    }
    _setState(
      CustomSceneSubmissionState(
        phase: phase,
        message: safety.messageZh,
        safetyNotice: safety,
      ),
    );
    try {
      await _draftStore.deleteIfExists();
    } on Object {
      // Safety notice remains the primary visible result.
    }
    try {
      await _draftContinuationCoordinator.clearAuthenticationContinuation(
        draftId: draftId,
      );
    } on Object {
      // Authentication continuation cleanup is best effort.
    }
  }

  bool _isOperationCurrent(int operationEpoch) {
    return !_disposed && operationEpoch == _operationEpoch;
  }

  CustomSceneSubmissionState _stateForResumeStatus(
    CustomSceneDraftContinuationStatus status,
  ) {
    return switch (status) {
      CustomSceneDraftContinuationStatus.notFound ||
      CustomSceneDraftContinuationStatus.expired => _recoverable(
        '这次描述已过期，请重新填写。',
      ),
      CustomSceneDraftContinuationStatus.accountMismatch => _recoverable(
        '账号已切换，请重新填写描述。',
      ),
      CustomSceneDraftContinuationStatus.unavailable => _recoverable(
        '暂时无法恢复这次描述，请稍后再试。',
      ),
      CustomSceneDraftContinuationStatus.inconsistent ||
      CustomSceneDraftContinuationStatus.otherIntentPending => _recoverable(
        '暂时无法恢复这次描述，请重新填写。',
      ),
      CustomSceneDraftContinuationStatus.readyForAuthentication =>
        const CustomSceneSubmissionState(
          phase: CustomSceneSubmissionPhase.needsAuthentication,
          message: '请先登录后再生成。',
        ),
      CustomSceneDraftContinuationStatus.readyForSubmission =>
        const CustomSceneSubmissionState.editing(),
    };
  }

  CustomSceneSubmissionState _recoverable(
    String message, {
    bool canCancelRetainedDraft = false,
  }) {
    return CustomSceneSubmissionState(
      phase: CustomSceneSubmissionPhase.recoverableError,
      message: message,
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
