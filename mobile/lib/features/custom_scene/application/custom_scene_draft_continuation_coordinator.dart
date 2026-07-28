import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/domain/models/auth_continuation.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_draft_store.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_stored_draft.dart';

enum CustomSceneDraftContinuationStatus {
  readyForAuthentication,
  readyForSubmission,
  notFound,
  expired,
  unavailable,
  accountMismatch,
  inconsistent,
  otherIntentPending,
}

class CustomSceneDraftContinuationResult {
  const CustomSceneDraftContinuationResult({required this.status, this.draft});

  final CustomSceneDraftContinuationStatus status;
  final CustomSceneStoredDraft? draft;
}

class CustomSceneDraftContinuationException implements Exception {
  const CustomSceneDraftContinuationException();

  @override
  String toString() => 'Custom scene continuation unavailable.';
}

/// Coordinates two atomic stores without placing raw scene text in the auth
/// continuation. The continuation carries only stable identifiers and context.
class CustomSceneDraftContinuationCoordinator {
  CustomSceneDraftContinuationCoordinator({
    required CustomSceneDraftStore draftStore,
    required AuthContinuationCoordinator authContinuationCoordinator,
    DateTime Function()? clock,
    String Function()? draftIdGenerator,
  }) : _draftStore = draftStore,
       _authContinuationCoordinator = authContinuationCoordinator,
       _clock = clock ?? DateTime.now,
       _draftIdGenerator = draftIdGenerator ?? _defaultDraftId;

  final CustomSceneDraftStore _draftStore;
  final AuthContinuationCoordinator _authContinuationCoordinator;
  final DateTime Function() _clock;
  final String Function() _draftIdGenerator;
  Future<void> _mutationTail = Future<void>.value();

  Future<CustomSceneStoredDraft> beginAuthentication({
    required CustomSceneDraft draft,
    String? expectedAccountContext,
  }) {
    return _enqueue(() async {
      final existing = await _readReusablePendingDraft();
      if (existing != null) {
        return existing;
      }
      final createdAt = _clock().toUtc();
      final expiresAt = createdAt.add(_authContinuationCoordinator.ttl);
      final stored = CustomSceneStoredDraft(
        draftId: _draftIdGenerator(),
        text: draft.text,
        entrySource: draft.entrySource,
        requestIdentity: draft.requestIdentity,
        state: CustomSceneStoredDraftState.awaitingAuthentication,
        createdAt: createdAt,
        expiresAt: expiresAt,
        expectedAccountContext: expectedAccountContext,
      );
      try {
        await _draftStore.write(stored);
        await _authContinuationCoordinator.beginGenerateCustomScene(
          payload: AuthContinuationCustomScenePayload(
            draftId: stored.draftId,
            entrySource: stored.entrySource,
            clientRequestId: stored.requestIdentity.clientRequestId,
            expectedAccountContext: stored.expectedAccountContext,
          ),
        );
        return stored;
      } on Object {
        await _clearBestEffort();
        throw const CustomSceneDraftContinuationException();
      }
    });
  }

  /// A second tap while authentication is pending must preserve the first
  /// draft/request identity. A different intent is never overwritten here.
  Future<CustomSceneStoredDraft?> _readReusablePendingDraft() async {
    final continuationResult = await _authContinuationCoordinator
        .readPendingResult();
    switch (continuationResult.status) {
      case AuthContinuationReadStatus.notFound:
        return null;
      case AuthContinuationReadStatus.expired:
      case AuthContinuationReadStatus.corrupt:
        await _deleteDraftBestEffort();
        return null;
      case AuthContinuationReadStatus.ioFailure:
        throw const CustomSceneDraftContinuationException();
      case AuthContinuationReadStatus.available:
        break;
    }
    final continuation = continuationResult.continuation;
    if (continuation == null) {
      await _clearBestEffort();
      return null;
    }
    if (continuation.intent != AuthContinuationIntent.generateCustomScene) {
      throw const CustomSceneDraftContinuationException();
    }
    final payload = continuation.customScene;
    if (payload == null) {
      await _clearBestEffort();
      return null;
    }
    final draftResult = await _draftStore.readResult(now: _clock().toUtc());
    switch (draftResult.status) {
      case CustomSceneDraftReadStatus.available:
        final stored = draftResult.draft;
        if (stored != null &&
            _matches(payload, stored) &&
            (stored.state ==
                    CustomSceneStoredDraftState.awaitingAuthentication ||
                stored.state ==
                    CustomSceneStoredDraftState.authenticationResolved)) {
          return stored;
        }
        await _clearBestEffort();
        return null;
      case CustomSceneDraftReadStatus.notFound:
      case CustomSceneDraftReadStatus.expired:
      case CustomSceneDraftReadStatus.corrupt:
        await _clearContinuationBestEffort();
        return null;
      case CustomSceneDraftReadStatus.ioFailure:
        throw const CustomSceneDraftContinuationException();
    }
  }

  Future<CustomSceneDraftContinuationResult> readForAuthenticatedResume({
    required String accountContext,
  }) {
    return _enqueue(() => _readForAuthenticatedResume(accountContext));
  }

  Future<CustomSceneDraftContinuationResult> _readForAuthenticatedResume(
    String accountContext,
  ) async {
    final normalizedAccountContext = accountContext.trim();
    if (normalizedAccountContext.isEmpty) {
      return const CustomSceneDraftContinuationResult(
        status: CustomSceneDraftContinuationStatus.accountMismatch,
      );
    }

    final AuthContinuationReadResult continuationResult;
    try {
      continuationResult = await _authContinuationCoordinator
          .readPendingResult();
    } on Object {
      return const CustomSceneDraftContinuationResult(
        status: CustomSceneDraftContinuationStatus.unavailable,
      );
    }
    switch (continuationResult.status) {
      case AuthContinuationReadStatus.notFound:
        return const CustomSceneDraftContinuationResult(
          status: CustomSceneDraftContinuationStatus.notFound,
        );
      case AuthContinuationReadStatus.expired:
        await _deleteDraftBestEffort();
        return const CustomSceneDraftContinuationResult(
          status: CustomSceneDraftContinuationStatus.expired,
        );
      case AuthContinuationReadStatus.corrupt:
        await _deleteDraftBestEffort();
        return const CustomSceneDraftContinuationResult(
          status: CustomSceneDraftContinuationStatus.inconsistent,
        );
      case AuthContinuationReadStatus.ioFailure:
        return const CustomSceneDraftContinuationResult(
          status: CustomSceneDraftContinuationStatus.unavailable,
        );
      case AuthContinuationReadStatus.available:
        break;
    }

    final continuation = continuationResult.continuation;
    if (continuation == null) {
      return const CustomSceneDraftContinuationResult(
        status: CustomSceneDraftContinuationStatus.inconsistent,
      );
    }
    if (continuation.intent != AuthContinuationIntent.generateCustomScene) {
      return const CustomSceneDraftContinuationResult(
        status: CustomSceneDraftContinuationStatus.otherIntentPending,
      );
    }
    final payload = continuation.customScene;
    if (payload == null) {
      await _clearBestEffort();
      return const CustomSceneDraftContinuationResult(
        status: CustomSceneDraftContinuationStatus.inconsistent,
      );
    }

    final draftResult = await _draftStore.readResult(now: _clock().toUtc());
    switch (draftResult.status) {
      case CustomSceneDraftReadStatus.notFound:
        await _clearContinuationBestEffort();
        return const CustomSceneDraftContinuationResult(
          status: CustomSceneDraftContinuationStatus.inconsistent,
        );
      case CustomSceneDraftReadStatus.expired:
        await _clearContinuationBestEffort();
        return const CustomSceneDraftContinuationResult(
          status: CustomSceneDraftContinuationStatus.expired,
        );
      case CustomSceneDraftReadStatus.corrupt:
        await _clearContinuationBestEffort();
        return const CustomSceneDraftContinuationResult(
          status: CustomSceneDraftContinuationStatus.inconsistent,
        );
      case CustomSceneDraftReadStatus.ioFailure:
        return const CustomSceneDraftContinuationResult(
          status: CustomSceneDraftContinuationStatus.unavailable,
        );
      case CustomSceneDraftReadStatus.available:
        break;
    }
    final draft = draftResult.draft;
    if (draft == null || !_matches(payload, draft)) {
      await _clearBestEffort();
      return const CustomSceneDraftContinuationResult(
        status: CustomSceneDraftContinuationStatus.inconsistent,
      );
    }

    final payloadAccount = payload.expectedAccountContext;
    final draftAccount = draft.expectedAccountContext;
    if (payloadAccount != null &&
        draftAccount != null &&
        payloadAccount != draftAccount) {
      await _clearBestEffort();
      return const CustomSceneDraftContinuationResult(
        status: CustomSceneDraftContinuationStatus.inconsistent,
      );
    }
    final expectedAccount = payloadAccount ?? draftAccount;
    if (expectedAccount != null &&
        expectedAccount != normalizedAccountContext) {
      await _clearBestEffort();
      return const CustomSceneDraftContinuationResult(
        status: CustomSceneDraftContinuationStatus.accountMismatch,
      );
    }

    if (draft.state == CustomSceneStoredDraftState.authenticationResolved) {
      if (expectedAccount == null) {
        await _clearBestEffort();
        return const CustomSceneDraftContinuationResult(
          status: CustomSceneDraftContinuationStatus.inconsistent,
        );
      }
      return CustomSceneDraftContinuationResult(
        status: CustomSceneDraftContinuationStatus.readyForSubmission,
        draft: draft,
      );
    }
    if (draft.state != CustomSceneStoredDraftState.awaitingAuthentication) {
      await _clearBestEffort();
      return const CustomSceneDraftContinuationResult(
        status: CustomSceneDraftContinuationStatus.inconsistent,
      );
    }

    final resolved = draft.copyWith(
      state: CustomSceneStoredDraftState.authenticationResolved,
      expectedAccountContext: normalizedAccountContext,
    );
    try {
      await _draftStore.write(resolved);
      await _authContinuationCoordinator.bindGenerateCustomSceneAccount(
        continuation: continuation,
        expectedAccountContext: normalizedAccountContext,
      );
    } on Object {
      return const CustomSceneDraftContinuationResult(
        status: CustomSceneDraftContinuationStatus.unavailable,
      );
    }
    return CustomSceneDraftContinuationResult(
      status: CustomSceneDraftContinuationStatus.readyForSubmission,
      draft: resolved,
    );
  }

  Future<void> complete({
    required String draftId,
    required String accountContext,
  }) {
    return _enqueue(() async {
      final result = await _readForAuthenticatedResume(accountContext);
      if (result.status !=
              CustomSceneDraftContinuationStatus.readyForSubmission ||
          result.draft?.draftId != draftId) {
        return;
      }
      await _draftStore.deleteIfExists();
      await _authContinuationCoordinator.clear();
    });
  }

  Future<void> cancel() => _enqueue(_clear);

  /// Authentication continuation is disposable once registration has produced
  /// a durable handoff intent. It must never delete that intent.
  Future<void> clearAuthenticationContinuation({required String draftId}) {
    return _enqueue(
      () => _clearGenerateCustomSceneAuthenticationContinuation(draftId),
    );
  }

  /// A Care Turn acknowledgement is accepted only for the current account and
  /// exact durable ready intent. Stale, duplicate, and cross-account signals
  /// are intentionally harmless.
  Future<bool> completeHandoff({
    required String generatedContentId,
    required String accountContext,
  }) {
    return _enqueue(
      () => _completeHandoff(
        generatedContentId: generatedContentId,
        accountContext: accountContext,
      ),
    );
  }

  Future<bool> _completeHandoff({
    required String generatedContentId,
    required String accountContext,
  }) async {
    final normalizedContentId = generatedContentId.trim();
    final normalizedAccountContext = accountContext.trim();
    if (normalizedContentId.isEmpty || normalizedAccountContext.isEmpty) {
      return false;
    }
    final result = await _draftStore.readResult(now: _clock().toUtc());
    if (result.status != CustomSceneDraftReadStatus.available ||
        result.draft == null) {
      return false;
    }
    final draft = result.draft!;
    if (draft.state != CustomSceneStoredDraftState.readyForHandoff ||
        draft.registeredContentId != normalizedContentId ||
        draft.expectedAccountContext != normalizedAccountContext) {
      return false;
    }
    try {
      await _draftStore.deleteIfExists();
      try {
        await _clearGenerateCustomSceneAuthenticationContinuation(
          draft.draftId,
        );
      } on Object {
        // Draft deletion is success. Only the matching authentication record
        // is eligible for best-effort cleanup.
      }
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _clearGenerateCustomSceneAuthenticationContinuation(
    String draftId,
  ) async {
    final result = await _authContinuationCoordinator.readPendingResult();
    if (result.status != AuthContinuationReadStatus.available) {
      return;
    }
    final continuation = result.continuation;
    if (continuation?.intent != AuthContinuationIntent.generateCustomScene ||
        continuation?.customScene?.draftId != draftId) {
      return;
    }
    await _authContinuationCoordinator.clear();
  }

  /// The continuation has its own clearance target. This target owns raw text.
  Future<void> clearForLifecycle() => _enqueue(_draftStore.deleteIfExists);

  Future<void> _clear() async {
    await _draftStore.deleteIfExists();
    await _authContinuationCoordinator.clear();
  }

  bool _matches(
    AuthContinuationCustomScenePayload payload,
    CustomSceneStoredDraft draft,
  ) {
    return payload.draftId == draft.draftId &&
        payload.entrySource == draft.entrySource &&
        payload.clientRequestId == draft.requestIdentity.clientRequestId;
  }

  Future<void> _deleteDraftBestEffort() async {
    try {
      await _draftStore.deleteIfExists();
    } on Object {
      // Best-effort privacy cleanup must not replace the primary result.
    }
  }

  Future<void> _clearContinuationBestEffort() async {
    try {
      await _authContinuationCoordinator.clear();
    } on Object {
      // Best-effort privacy cleanup must not replace the primary result.
    }
  }

  Future<void> _clearBestEffort() async {
    await _deleteDraftBestEffort();
    await _clearContinuationBestEffort();
  }

  Future<T> _enqueue<T>(Future<T> Function() mutation) {
    final running = _mutationTail.then((_) => mutation());
    _mutationTail = running.then<void>((_) {}, onError: (_, _) {});
    return running;
  }

  static String _defaultDraftId() {
    return 'custom_scene_draft_${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }
}
