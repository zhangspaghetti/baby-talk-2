import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

typedef PracticeContinuitySnapshotLoader =
    Future<PracticeContinuitySnapshot> Function({
      String? starterSpaceId,
      String? starterActivityId,
    });
typedef PracticeActivitySnapshotLoader =
    Future<PracticeActivitySnapshot> Function({
      required String spaceId,
      required String activityId,
    });
typedef GeneratedPracticeActivitySnapshotLoader =
    Future<PracticeActivitySnapshot> Function({
      required String generatedContentId,
    });

enum PracticeContinuityLoadStatus { idle, loading, ready, error }

extension PracticeContinuityLoadStatusLabel on PracticeContinuityLoadStatus {
  String get label {
    switch (this) {
      case PracticeContinuityLoadStatus.idle:
        return 'idle';
      case PracticeContinuityLoadStatus.loading:
        return 'loading';
      case PracticeContinuityLoadStatus.ready:
        return 'ready';
      case PracticeContinuityLoadStatus.error:
        return 'error';
    }
  }
}

class PracticeContinuitySeedState {
  const PracticeContinuitySeedState({
    this.starterArgs,
    this.snapshot,
    this.activitySnapshot,
    this.recommendedArgs,
    this.generatedRecommendedArgs,
    this.status = PracticeContinuityLoadStatus.idle,
    this.warningMessage,
    this.disabledReason,
    this.lastRefreshReason,
  });

  final PracticeRouteArgs? starterArgs;
  final PracticeContinuitySnapshot? snapshot;
  final PracticeActivitySnapshot? activitySnapshot;
  final PracticeRouteArgs? recommendedArgs;
  final GeneratedCareTurnRouteArgs? generatedRecommendedArgs;
  final PracticeContinuityLoadStatus status;
  final String? warningMessage;
  final String? disabledReason;
  final String? lastRefreshReason;
}

class PracticeContinuityNotifier extends ChangeNotifier {
  PracticeContinuityNotifier({
    PracticeRepository? repository,
    PracticeContinuitySnapshotLoader? continuitySnapshotLoader,
    PracticeActivitySnapshotLoader? activitySnapshotLoader,
    GeneratedPracticeActivitySnapshotLoader? generatedActivitySnapshotLoader,
    PracticeRouteArgs? initialStarterArgs,
    PracticeContinuitySeedState? seedState,
    this.refreshTimeout = const Duration(seconds: 4),
  }) : assert(
         repository != null ||
             (continuitySnapshotLoader != null &&
                 activitySnapshotLoader != null),
         'PracticeContinuityNotifier 需要 repository 或完整 loader 注入。',
       ),
       _continuitySnapshotLoader =
           continuitySnapshotLoader ?? repository!.getContinuitySnapshot,
       _activitySnapshotLoader =
           activitySnapshotLoader ?? repository!.getActivitySnapshot,
       _generatedActivitySnapshotLoader =
           generatedActivitySnapshotLoader ??
           repository?.getGeneratedActivitySnapshot,
       _starterArgs = _normalizeArgs(
         seedState?.starterArgs ?? initialStarterArgs,
       ),
       _snapshot = seedState?.snapshot,
       _activitySnapshot = seedState?.activitySnapshot,
       _recommendedArgs = _normalizeArgs(seedState?.recommendedArgs),
       _generatedRecommendedArgs = _normalizeGeneratedArgs(
         seedState?.generatedRecommendedArgs,
       ),
       _status = seedState?.status ?? PracticeContinuityLoadStatus.idle,
       _warningMessage = _cleanMessage(
         seedState?.warningMessage ?? seedState?.snapshot?.warningMessage,
       ),
       _disabledReason = _cleanMessage(seedState?.disabledReason),
       _lastRefreshReason = _cleanMessage(seedState?.lastRefreshReason);

  final PracticeContinuitySnapshotLoader _continuitySnapshotLoader;
  final PracticeActivitySnapshotLoader _activitySnapshotLoader;
  final GeneratedPracticeActivitySnapshotLoader?
  _generatedActivitySnapshotLoader;
  final Duration refreshTimeout;

  PracticeRouteArgs? _starterArgs;
  PracticeContinuitySnapshot? _snapshot;
  PracticeActivitySnapshot? _activitySnapshot;
  PracticeRouteArgs? _recommendedArgs;
  GeneratedCareTurnRouteArgs? _generatedRecommendedArgs;
  PracticeContinuityLoadStatus _status;
  bool _isRefreshing = false;
  String? _warningMessage;
  String? _disabledReason;
  String? _lastRefreshReason;
  bool _disposed = false;
  Future<void>? _refreshFuture;
  String? _queuedRefreshReason;
  Timer? _refreshTimeoutTimer;

  PracticeRouteArgs? get starterArgs => _starterArgs;
  PracticeContinuitySnapshot? get snapshot => _snapshot;
  PracticeActivitySnapshot? get activitySnapshot => _activitySnapshot;
  PracticeRouteArgs? get recommendedArgs => _recommendedArgs;
  GeneratedCareTurnRouteArgs? get generatedRecommendedArgs =>
      _generatedRecommendedArgs;
  PracticeRouteTarget? get recommendedRoute =>
      _generatedRecommendedArgs ?? _recommendedArgs;
  PracticeContinuityLoadStatus get status => _status;
  bool get isRefreshing => _isRefreshing;
  String? get warningMessage => _warningMessage;
  String? get disabledReason => _disabledReason;
  String? get lastRefreshReason => _lastRefreshReason;

  bool get hasResolvedRecommendation =>
      _activitySnapshot != null && recommendedRoute != null;

  bool get isInitialLoading =>
      (_status == PracticeContinuityLoadStatus.idle ||
          _status == PracticeContinuityLoadStatus.loading) &&
      !hasResolvedRecommendation;

  bool get isActionDisabled =>
      recommendedRoute == null || (_disabledReason?.trim().isNotEmpty ?? false);

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
      final generatedContentId =
          nextSnapshot.recommendedActivity.generatedContentId;
      final recommendedArgs = generatedContentId == null
          ? PracticeRouteArgs.maybeCreate(
              spaceId: nextSnapshot.recommendedActivity.spaceId,
              activityId: nextSnapshot.recommendedActivity.activityId,
            )
          : null;
      final generatedRecommendedArgs = generatedContentId == null
          ? null
          : GeneratedCareTurnRouteArgs(generatedContentId: generatedContentId);
      if (recommendedArgs == null && generatedRecommendedArgs == null) {
        _applyMalformedSnapshot(nextSnapshot);
        return;
      }

      final nextActivitySnapshot = generatedRecommendedArgs == null
          ? await _runWithTimeout(
              _activitySnapshotLoader(
                spaceId: recommendedArgs!.spaceId,
                activityId: recommendedArgs.activityId,
              ),
            )
          : await _runWithTimeout(
              _loadGeneratedActivitySnapshot(generatedRecommendedArgs),
            );
      if (_disposed) {
        return;
      }

      _snapshot = nextSnapshot;
      _activitySnapshot = nextActivitySnapshot;
      _recommendedArgs = recommendedArgs;
      _generatedRecommendedArgs = generatedRecommendedArgs;
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

  Future<PracticeActivitySnapshot> _loadGeneratedActivitySnapshot(
    GeneratedCareTurnRouteArgs args,
  ) {
    final loader = _generatedActivitySnapshotLoader;
    if (loader == null) {
      throw const FormatException('generated continuity resolver 不可用。');
    }
    return loader(generatedContentId: args.generatedContentId);
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  /// 会话重置时调用，清除所有内存状态回到安全空态。
  /// logout/delete/revoke 场景下由 home_screen 触发。
  void resetToSafeEmpty() {
    _refreshTimeoutTimer?.cancel();
    _refreshTimeoutTimer = null;
    _refreshFuture = null;
    _queuedRefreshReason = null;
    _isRefreshing = false;
    _snapshot = null;
    _activitySnapshot = null;
    _recommendedArgs = null;
    _generatedRecommendedArgs = null;
    _status = PracticeContinuityLoadStatus.idle;
    _warningMessage = null;
    _disabledReason = null;
    _lastRefreshReason = null;
    notifyListeners();
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
    _generatedRecommendedArgs = null;
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

  static GeneratedCareTurnRouteArgs? _normalizeGeneratedArgs(
    GeneratedCareTurnRouteArgs? args,
  ) {
    return args;
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
