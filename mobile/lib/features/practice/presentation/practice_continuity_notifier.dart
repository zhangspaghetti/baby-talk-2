import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_view_model.dart'
    show
        PracticeActivitySnapshotLoader,
        PracticeContinuityLoadStatus,
        PracticeContinuitySeedState,
        PracticeContinuitySnapshotLoader;
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

/// Riverpod-ready notifier that replaces [PracticeContinuityViewModel].
///
/// Uses [ChangeNotifier] as the base so existing widget code can adapt
/// incrementally without a full rewrite of the UI layer.
///
/// The API surface intentionally mirrors the old ViewModel so that callers
/// only need to swap the type they resolve.
class PracticeContinuityNotifier extends ChangeNotifier {
  PracticeContinuityNotifier({
    required PracticeRepository repository,
    this.refreshTimeout = const Duration(seconds: 4),
    PracticeContinuitySnapshotLoader? continuitySnapshotLoader,
    PracticeActivitySnapshotLoader? activitySnapshotLoader,
    PracticeRouteArgs? initialStarterArgs,
    PracticeContinuitySeedState? seedState,
  }) : _continuitySnapshotLoader =
           continuitySnapshotLoader ?? repository.getContinuitySnapshot,
       _activitySnapshotLoader =
           activitySnapshotLoader ?? repository.getActivitySnapshot,
       _starterArgs = _normalizeArgs(
         seedState?.starterArgs ?? initialStarterArgs,
       ),
       _snapshot = seedState?.snapshot,
       _activitySnapshot = seedState?.activitySnapshot,
       _recommendedArgs = _normalizeArgs(seedState?.recommendedArgs),
       _status = seedState?.status ?? PracticeContinuityLoadStatus.idle,
       _warningMessage = _cleanMessage(
         seedState?.warningMessage ?? seedState?.snapshot?.warningMessage,
       ),
       _disabledReason = _cleanMessage(seedState?.disabledReason),
       _lastRefreshReason = _cleanMessage(seedState?.lastRefreshReason);

  final PracticeContinuitySnapshotLoader _continuitySnapshotLoader;
  final PracticeActivitySnapshotLoader _activitySnapshotLoader;
  final Duration refreshTimeout;

  PracticeRouteArgs? _starterArgs;
  PracticeContinuitySnapshot? _snapshot;
  PracticeActivitySnapshot? _activitySnapshot;
  PracticeRouteArgs? _recommendedArgs;
  PracticeContinuityLoadStatus _status;
  bool _isRefreshing = false;
  String? _warningMessage;
  String? _disabledReason;
  String? _lastRefreshReason;
  bool _disposed = false;
  Future<void>? _refreshFuture;
  String? _queuedRefreshReason;
  Timer? _refreshTimeoutTimer;

  // -- Getters ---------------------------------------------------------------

  PracticeRouteArgs? get starterArgs => _starterArgs;
  PracticeContinuitySnapshot? get snapshot => _snapshot;
  PracticeActivitySnapshot? get activitySnapshot => _activitySnapshot;
  PracticeRouteArgs? get recommendedArgs => _recommendedArgs;
  PracticeContinuityLoadStatus get status => _status;
  bool get isRefreshing => _isRefreshing;
  String? get warningMessage => _warningMessage;
  String? get disabledReason => _disabledReason;
  String? get lastRefreshReason => _lastRefreshReason;

  bool get hasResolvedRecommendation =>
      _activitySnapshot != null && _recommendedArgs != null;

  bool get isInitialLoading =>
      (_status == PracticeContinuityLoadStatus.idle ||
          _status == PracticeContinuityLoadStatus.loading) &&
      !hasResolvedRecommendation;

  bool get isActionDisabled =>
      _recommendedArgs == null || (_disabledReason?.trim().isNotEmpty ?? false);

  // -- Public API ------------------------------------------------------------

  Future<void> initialize({String reason = 'initial_load'}) {
    if (_status != PracticeContinuityLoadStatus.idle || _isRefreshing) {
      return _refreshFuture ?? Future.value();
    }
    return refresh(reason: reason);
  }

  Future<void> configureStarterArgs(
    PracticeRouteArgs? args, {
    String reason = 'starter_context_changed',
  }) async {
    final normalized = _normalizeArgs(args);
    if (_sameArgs(_starterArgs, normalized)) {
      return _refreshFuture ?? Future.value();
    }
    _starterArgs = normalized;
    if (_isRefreshing) {
      _queuedRefreshReason = reason;
      return _refreshFuture ?? Future.value();
    }
    await refresh(reason: reason);
  }

  Future<void> refresh({required String reason}) {
    if (_disposed) {
      return Future.value();
    }
    if (_isRefreshing) {
      _queuedRefreshReason = reason;
      return _refreshFuture ?? Future.value();
    }

    final future = _refreshInternal(reason: reason);
    _refreshFuture = future;
    return future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    });
  }

  /// Resets all in-memory state to a safe empty baseline.
  ///
  /// Called on session resets so the UI does not leak stale data.
  void resetToSafeEmpty() {
    _refreshTimeoutTimer?.cancel();
    _refreshTimeoutTimer = null;
    _refreshFuture = null;
    _queuedRefreshReason = null;
    _isRefreshing = false;
    _snapshot = null;
    _activitySnapshot = null;
    _recommendedArgs = null;
    _status = PracticeContinuityLoadStatus.idle;
    _warningMessage = null;
    _disabledReason = null;
    _lastRefreshReason = null;
    notifyListeners();
  }

  // -- Internals -------------------------------------------------------------

  Future<void> _refreshInternal({required String reason}) async {
    final starterArgs = _starterArgs;
    _isRefreshing = true;
    _lastRefreshReason = reason;
    if (!hasResolvedRecommendation) {
      _status = PracticeContinuityLoadStatus.loading;
    }
    notifyListeners();

    try {
      final nextSnapshot = await _runWithTimeout(
        _continuitySnapshotLoader(
          starterSpaceId: starterArgs?.spaceId,
          starterActivityId: starterArgs?.activityId,
        ),
      );
      if (_disposed) {
        return;
      }
      final recommendedArgs = PracticeRouteArgs.maybeCreate(
        spaceId: nextSnapshot.recommendedActivity.spaceId,
        activityId: nextSnapshot.recommendedActivity.activityId,
      );
      if (recommendedArgs == null) {
        _applyMalformedSnapshot(nextSnapshot);
        return;
      }

      final nextActivitySnapshot = await _runWithTimeout(
        _activitySnapshotLoader(
          spaceId: recommendedArgs.spaceId,
          activityId: recommendedArgs.activityId,
        ),
      );
      if (_disposed) {
        return;
      }

      _snapshot = nextSnapshot;
      _activitySnapshot = nextActivitySnapshot;
      _recommendedArgs = recommendedArgs;
      _status = PracticeContinuityLoadStatus.ready;
      _warningMessage = _cleanMessage(nextSnapshot.warningMessage);
      _disabledReason = null;
    } on TimeoutException {
      if (_disposed) {
        return;
      }
      _status = PracticeContinuityLoadStatus.error;
      _warningMessage = _mergeMessages(
        _snapshot?.warningMessage,
        'continuity 刷新超时，先保留最近一次稳定结果。',
      );
      _disabledReason = 'continuity 刷新超时，请重新整理后再继续练习。';
    } catch (error) {
      if (_disposed) {
        return;
      }
      _status = PracticeContinuityLoadStatus.error;
      _warningMessage = _mergeMessages(
        _snapshot?.warningMessage,
        'continuity 刷新失败：$error',
      );
      _disabledReason = 'continuity 刷新失败，请稍后重试。';
    } finally {
      _isRefreshing = false;
      notifyListeners();
      final queuedRefreshReason = _queuedRefreshReason;
      _queuedRefreshReason = null;
      if (!_disposed && queuedRefreshReason != null) {
        unawaited(refresh(reason: queuedRefreshReason));
      }
    }
  }

  Future<T> _runWithTimeout<T>(Future<T> future) {
    if (refreshTimeout <= Duration.zero) {
      return future;
    }
    final completer = Completer<T>();
    final timer = Timer(refreshTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('continuity_refresh', refreshTimeout),
        );
      }
    });
    _refreshTimeoutTimer = timer;

    future
        .then(
          (value) {
            if (!completer.isCompleted) {
              completer.complete(value);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          },
        )
        .whenComplete(() {
          timer.cancel();
          if (identical(_refreshTimeoutTimer, timer)) {
            _refreshTimeoutTimer = null;
          }
        });

    return completer.future.whenComplete(() {
      timer.cancel();
      if (identical(_refreshTimeoutTimer, timer)) {
        _refreshTimeoutTimer = null;
      }
    });
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimeoutTimer?.cancel();
    _refreshTimeoutTimer = null;
    super.dispose();
  }

  void _applyMalformedSnapshot(PracticeContinuitySnapshot snapshot) {
    _snapshot = snapshot;
    _activitySnapshot = null;
    _recommendedArgs = null;
    _status = PracticeContinuityLoadStatus.error;
    _warningMessage = _mergeMessages(
      snapshot.warningMessage,
      'continuity snapshot 缺少有效推荐 activity 参数，继续入口已禁用。',
    );
    _disabledReason = 'continuity snapshot 缺少有效推荐 activity 参数。';
  }

  static PracticeRouteArgs? _normalizeArgs(PracticeRouteArgs? args) {
    if (args == null || !args.isValid) {
      return null;
    }
    return args.normalized();
  }

  static bool _sameArgs(PracticeRouteArgs? left, PracticeRouteArgs? right) {
    return left?.scopeLabel == right?.scopeLabel;
  }

  static String? _cleanMessage(String? message) {
    final trimmed = message?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static String? _mergeMessages(String? first, String? second) {
    final parts = [
      _cleanMessage(first),
      _cleanMessage(second),
    ].whereType<String>().toList(growable: false);
    if (parts.isEmpty) {
      return null;
    }
    return parts.join('；');
  }
}
