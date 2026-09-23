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
  int? _activeRouteGeneration;
  Future<void>? _activeRouteCompletion;
  int _scopeGeneration = 0;
  bool _disposed = false;

  /// Call only after account state has finished settling. A missing account
  /// suspends recovery; it never consumes another account's durable intent.
  Future<void> recoverForAuthenticatedAccount({
    String? accountContext,
    String? resumableGeneratedContentId,
  }) {
    final normalizedAccountContext = accountContext?.trim();
    final scopeGeneration = ++_scopeGeneration;
    final previousAccountContext = _stableAccountContext;
    final accountChanged =
        previousAccountContext != normalizedAccountContext &&
        previousAccountContext != null;
    _stableAccountContext = normalizedAccountContext;
    if (accountChanged) {
      _controller.invalidateForAccountChange();
      _recoveredAccountContext = null;
      _routedContentId = null;
    }
    return _enqueue(() async {
      if (_disposed || scopeGeneration != _scopeGeneration) {
        return;
      }
      if (normalizedAccountContext == null ||
          normalizedAccountContext.isEmpty) {
        _stableAccountContext = null;
        _recoveredAccountContext = null;
        _routedContentId = null;
        return;
      }
      if (_recoveredAccountContext == normalizedAccountContext) {
        await _routePreparedContentIfReady(scopeGeneration: scopeGeneration);
        await _routeResumableGeneratedContentIfIdle(
          resumableGeneratedContentId,
          scopeGeneration: scopeGeneration,
        );
        return;
      }
      try {
        await _controller.restore(accountContext: normalizedAccountContext);
      } on Object {
        return;
      }
      if (scopeGeneration != _scopeGeneration) {
        return;
      }
      _recoveredAccountContext = normalizedAccountContext;
      await _routePreparedContentIfReady(scopeGeneration: scopeGeneration);
      await _routeResumableGeneratedContentIfIdle(
        resumableGeneratedContentId,
        scopeGeneration: scopeGeneration,
      );
    });
  }

  /// UI invokes this command, but routing remains in this coordinator.
  Future<void> openPreparedContent() {
    final activeStart = _activePreparedContentOpenStart;
    if (activeStart != null) {
      return activeStart;
    }
    late final Future<void> operation;
    final scopeGeneration = _scopeGeneration;
    operation =
        _enqueue(
          () => _routePreparedContentIfReady(
            allowRecoveredRetry: true,
            scopeGeneration: scopeGeneration,
          ),
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
    int? scopeGeneration,
  }) async {
    final generation = scopeGeneration ?? _scopeGeneration;
    if (generation != _scopeGeneration) {
      return;
    }
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
      scopeGeneration: generation,
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
      if (generation != _scopeGeneration ||
          _stableAccountContext != accountContext ||
          _controller.state.generatedContentId != generatedContentId) {
        return;
      }
      _trackRouteAttempt(
        accountContext: accountContext,
        generatedContentId: generatedContentId,
        scopeGeneration: generation,
        routeAttempt: routeAttempt,
      );
    } on Object {
      if (generation == _scopeGeneration &&
          _stableAccountContext == accountContext &&
          _controller.state.generatedContentId == generatedContentId) {
        _routedContentId = null;
        _controller.markHandoffRouteFailed();
      }
    }
  }

  Future<void> _routeResumableGeneratedContentIfIdle(
    String? generatedContentId, {
    int? scopeGeneration,
  }) async {
    final generation = scopeGeneration ?? _scopeGeneration;
    if (generation != _scopeGeneration) {
      return;
    }
    final accountContext = _stableAccountContext;
    final normalizedContentId = generatedContentId?.trim();
    if (accountContext == null ||
        _isSafetyTerminal ||
        _controller.state.canOpenPreparedContent ||
        normalizedContentId == null ||
        normalizedContentId.isEmpty ||
        _isRouteActive(
          accountContext: accountContext,
          generatedContentId: normalizedContentId,
          scopeGeneration: generation,
        ) ||
        _routedContentId == normalizedContentId) {
      return;
    }
    _routedContentId = normalizedContentId;
    try {
      final routeAttempt = await _handoffSink.handoff(
        CustomSceneCareTurnHandoff(generatedContentId: normalizedContentId),
      );
      if (generation != _scopeGeneration ||
          _stableAccountContext != accountContext) {
        return;
      }
      _trackRouteAttempt(
        accountContext: accountContext,
        generatedContentId: normalizedContentId,
        scopeGeneration: generation,
        routeAttempt: routeAttempt,
      );
    } on Object {
      if (generation == _scopeGeneration &&
          _stableAccountContext == accountContext) {
        _routedContentId = null;
      }
    }
  }

  bool get _isSafetyTerminal =>
      _controller.state.phase == CustomSceneSubmissionPhase.healthSafety ||
      _controller.state.phase ==
          CustomSceneSubmissionPhase.assessmentUnavailable;

  bool _isRouteActive({
    required String accountContext,
    required String generatedContentId,
    required int scopeGeneration,
  }) {
    return _activeRouteAccountContext == accountContext &&
        _activeRouteContentId == generatedContentId &&
        _activeRouteGeneration == scopeGeneration &&
        _activeRouteCompletion != null;
  }

  void _trackRouteAttempt({
    required String accountContext,
    required String generatedContentId,
    required int scopeGeneration,
    required CustomSceneCareTurnRouteAttempt routeAttempt,
  }) {
    final completion = routeAttempt.routeCompletion;
    _activeRouteAccountContext = accountContext;
    _activeRouteContentId = generatedContentId;
    _activeRouteGeneration = scopeGeneration;
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
    _activeRouteGeneration = null;
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
