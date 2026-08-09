import 'dart:async';

import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';

/// Sole app-level owner of durable custom-scene recovery and Care Turn routes.
/// Pages may render its state or ask it to reopen prepared content, but never
/// inspect durable storage or navigate themselves.
class CustomSceneRecoveryCoordinator {
  CustomSceneRecoveryCoordinator({
    required CustomSceneSubmissionController controller,
    required CustomSceneCareTurnHandoffSink handoffSink,
  }) : _controller = controller,
       _handoffSink = handoffSink {
    _controller.addListener(_onSubmissionStateChanged);
  }

  final CustomSceneSubmissionController _controller;
  final CustomSceneCareTurnHandoffSink _handoffSink;
  Future<void> _mutationTail = Future<void>.value();
  Future<void>? _activePreparedContentOpenStart;
  String? _stableAccountContext;
  String? _recoveredAccountContext;
  String? _routedContentId;
  String? _activeRouteAccountContext;
  String? _activeRouteContentId;
  Future<void>? _activeRouteCompletion;
  bool _disposed = false;

  /// Call only after account state has finished settling. A missing account
  /// suspends recovery; it never consumes another account's durable intent.
  Future<void> recoverForAuthenticatedAccount({
    String? accountContext,
    String? resumableGeneratedContentId,
  }) {
    return _enqueue(() async {
      final normalizedAccountContext = accountContext?.trim();
      if (normalizedAccountContext == null ||
          normalizedAccountContext.isEmpty) {
        _stableAccountContext = null;
        _recoveredAccountContext = null;
        _routedContentId = null;
        return;
      }
      if (_stableAccountContext != normalizedAccountContext) {
        _routedContentId = null;
      }
      _stableAccountContext = normalizedAccountContext;
      if (_recoveredAccountContext == normalizedAccountContext) {
        await _routePreparedContentIfReady();
        await _routeResumableGeneratedContentIfIdle(
          resumableGeneratedContentId,
        );
        return;
      }
      try {
        await _controller.restore(accountContext: normalizedAccountContext);
      } on Object {
        return;
      }
      _recoveredAccountContext = normalizedAccountContext;
      await _routePreparedContentIfReady();
      await _routeResumableGeneratedContentIfIdle(resumableGeneratedContentId);
    });
  }

  /// UI invokes this command, but routing remains in this coordinator.
  Future<void> openPreparedContent() {
    final activeStart = _activePreparedContentOpenStart;
    if (activeStart != null) {
      return activeStart;
    }
    late final Future<void> operation;
    operation =
        _enqueue(
          () => _routePreparedContentIfReady(allowRecoveredRetry: true),
        ).whenComplete(() {
          if (identical(_activePreparedContentOpenStart, operation)) {
            _activePreparedContentOpenStart = null;
          }
        });
    _activePreparedContentOpenStart = operation;
    return operation;
  }

  Future<void> _routePreparedContentIfReady({
    bool allowRecoveredRetry = false,
  }) async {
    final accountContext = _stableAccountContext;
    final state = _controller.state;
    final generatedContentId = state.generatedContentId?.trim();
    if (accountContext == null ||
        !state.canOpenPreparedContent ||
        (!allowRecoveredRetry &&
            state.phase != CustomSceneSubmissionPhase.readyForHandoff) ||
        generatedContentId == null ||
        generatedContentId.isEmpty) {
      return;
    }
    if (_isRouteActive(
      accountContext: accountContext,
      generatedContentId: generatedContentId,
    )) {
      return;
    }
    if (!allowRecoveredRetry && _routedContentId == generatedContentId) {
      return;
    }
    _routedContentId = generatedContentId;
    try {
      final routeAttempt = await _handoffSink.handoff(
        CustomSceneCareTurnHandoff(generatedContentId: generatedContentId),
      );
      _trackRouteAttempt(
        accountContext: accountContext,
        generatedContentId: generatedContentId,
        routeAttempt: routeAttempt,
      );
    } on Object {
      _routedContentId = null;
      _controller.markHandoffRouteFailed();
    }
  }

  Future<void> _routeResumableGeneratedContentIfIdle(
    String? generatedContentId,
  ) async {
    final accountContext = _stableAccountContext;
    final normalizedContentId = generatedContentId?.trim();
    if (accountContext == null ||
        _controller.state.canOpenPreparedContent ||
        normalizedContentId == null ||
        normalizedContentId.isEmpty ||
        _isRouteActive(
          accountContext: accountContext,
          generatedContentId: normalizedContentId,
        ) ||
        _routedContentId == normalizedContentId) {
      return;
    }
    _routedContentId = normalizedContentId;
    try {
      final routeAttempt = await _handoffSink.handoff(
        CustomSceneCareTurnHandoff(generatedContentId: normalizedContentId),
      );
      _trackRouteAttempt(
        accountContext: accountContext,
        generatedContentId: normalizedContentId,
        routeAttempt: routeAttempt,
      );
    } on Object {
      _routedContentId = null;
    }
  }

  bool _isRouteActive({
    required String accountContext,
    required String generatedContentId,
  }) {
    return _activeRouteAccountContext == accountContext &&
        _activeRouteContentId == generatedContentId &&
        _activeRouteCompletion != null;
  }

  void _trackRouteAttempt({
    required String accountContext,
    required String generatedContentId,
    required CustomSceneCareTurnRouteAttempt routeAttempt,
  }) {
    final completion = routeAttempt.routeCompletion;
    _activeRouteAccountContext = accountContext;
    _activeRouteContentId = generatedContentId;
    _activeRouteCompletion = completion;
    unawaited(
      completion.then<void>(
        (_) => _clearRouteAttempt(completion),
        onError: (_, _) => _clearRouteAttempt(completion),
      ),
    );
  }

  void _clearRouteAttempt(Future<void> completion) {
    if (!identical(_activeRouteCompletion, completion)) {
      return;
    }
    _activeRouteAccountContext = null;
    _activeRouteContentId = null;
    _activeRouteCompletion = null;
  }

  void _onSubmissionStateChanged() {
    if (_disposed) {
      return;
    }
    if (!_controller.state.canOpenPreparedContent) {
      _routedContentId = null;
      return;
    }
    if (_controller.state.phase == CustomSceneSubmissionPhase.readyForHandoff) {
      unawaited(_enqueue(_routePreparedContentIfReady));
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() mutation) {
    final running = _mutationTail.then((_) => mutation());
    _mutationTail = running.then<void>((_) {}, onError: (_, _) {});
    return running;
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _controller.removeListener(_onSubmissionStateChanged);
  }
}
