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
  String? _stableAccountContext;
  String? _recoveredAccountContext;
  String? _routedContentId;
  bool _disposed = false;

  /// Call only after account state has finished settling. A missing account
  /// suspends recovery; it never consumes another account's durable intent.
  Future<void> recoverForAuthenticatedAccount({String? accountContext}) {
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
        return;
      }
      try {
        await _controller.restore(accountContext: normalizedAccountContext);
      } on Object {
        return;
      }
      _recoveredAccountContext = normalizedAccountContext;
      await _routePreparedContentIfReady();
    });
  }

  /// UI invokes this command, but routing remains in this coordinator.
  Future<void> openPreparedContent() {
    return _enqueue(
      () => _routePreparedContentIfReady(allowRecoveredRetry: true),
    );
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
    if (_routedContentId == generatedContentId) {
      return;
    }
    _routedContentId = generatedContentId;
    try {
      await _handoffSink.handoff(
        CustomSceneCareTurnHandoff(generatedContentId: generatedContentId),
      );
    } on Object {
      _routedContentId = null;
      _controller.markHandoffRouteFailed();
    }
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
