import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/presentation/account_scoped_refresh_guard.dart';

enum GardenGrowthLoadStatus { idle, loading, ready, empty, error }

class GardenGrowthNotifier extends ChangeNotifier {
  GardenGrowthNotifier({
    required GardenGrowthRepository repository,
    this.refreshTimeout = const Duration(seconds: 4),
  }) : _repository = repository;

  final GardenGrowthRepository _repository;
  final Duration refreshTimeout;

  GardenGrowthSnapshot _snapshot = GardenGrowthSnapshot.empty();
  GardenGrowthLoadStatus _status = GardenGrowthLoadStatus.idle;
  bool _isRefreshing = false;
  String? _message;
  bool _disposed = false;
  Future<void>? _refreshFuture;
  bool _refreshQueued = false;
  Timer? _refreshTimeoutTimer;
  final AccountScopedRefreshGuard _refreshGuard = AccountScopedRefreshGuard();

  GardenGrowthSnapshot get snapshot => _snapshot;
  GardenGrowthLoadStatus get status => _status;
  bool get isRefreshing => _isRefreshing;
  String? get message => _message;

  bool get isReady => _status == GardenGrowthLoadStatus.ready;
  bool get isEmpty => _status == GardenGrowthLoadStatus.empty;
  bool get hasError => _status == GardenGrowthLoadStatus.error;

  Future<void> initialize() {
    if (_status != GardenGrowthLoadStatus.idle || _isRefreshing) {
      return _refreshFuture ?? Future.value();
    }
    return refresh();
  }

  Future<void> refresh() {
    if (_disposed) {
      return Future.value();
    }
    if (_isRefreshing) {
      _refreshQueued = true;
      return _refreshFuture ?? Future.value();
    }

    final refreshToken = _refreshGuard.beginRefresh();
    final future = _refreshInternal(refreshToken: refreshToken);
    _refreshFuture = future;
    return future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    });
  }

  Future<void> refreshForAccountProjection() {
    return refresh();
  }

  Future<void> _refreshInternal({
    required AccountScopedRefreshToken refreshToken,
  }) async {
    _isRefreshing = true;
    if (_status == GardenGrowthLoadStatus.idle) {
      _status = GardenGrowthLoadStatus.loading;
      notifyListeners();
    }

    try {
      final nextSnapshot = await _runWithTimeout(_repository.buildSnapshot());
      if (!_ownsRefresh(refreshToken)) {
        return;
      }
      _snapshot = nextSnapshot;
      _status = nextSnapshot.isEmpty
          ? GardenGrowthLoadStatus.empty
          : GardenGrowthLoadStatus.ready;
      _message = nextSnapshot.projectionWarning;
    } on TimeoutException {
      if (!_ownsRefresh(refreshToken)) {
        return;
      }
      _status = GardenGrowthLoadStatus.error;
      _message = '成长更新超时，先保留上一次稳定结果。';
    } catch (error) {
      if (!_ownsRefresh(refreshToken)) {
        return;
      }
      _status = GardenGrowthLoadStatus.error;
      _message = '成长更新暂时不可用，请稍后重试。';
    } finally {
      if (_ownsRefresh(refreshToken)) {
        _isRefreshing = false;
        notifyListeners();
        final shouldRunQueuedRefresh = _refreshQueued;
        _refreshQueued = false;
        if (!_disposed && shouldRunQueuedRefresh) {
          unawaited(refresh());
        }
      }
    }
  }

  /// Changes the in-memory owner scope and invalidates any in-flight result.
  /// No account identifier is persisted or logged.
  void bindAccountContext(String? accountContext, {bool notify = true}) {
    if (!_refreshGuard.bindAccountContext(accountContext)) {
      return;
    }
    _invalidateRefreshAndClearProjection();
    if (notify) {
      notifyListeners();
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
          TimeoutException('garden_growth_refresh', refreshTimeout),
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

  /// 会话重置时调用，清除所有内存状态回到安全空态。
  void resetToSafeEmpty() {
    _refreshGuard.invalidate(clearAccountContext: true);
    _invalidateRefreshAndClearProjection();
    notifyListeners();
  }

  bool _ownsRefresh(AccountScopedRefreshToken token) =>
      !_disposed && _refreshGuard.owns(token);

  void _invalidateRefreshAndClearProjection() {
    _refreshTimeoutTimer?.cancel();
    _refreshTimeoutTimer = null;
    _refreshFuture = null;
    _refreshQueued = false;
    _isRefreshing = false;
    _snapshot = GardenGrowthSnapshot.empty();
    _status = GardenGrowthLoadStatus.idle;
    _message = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimeoutTimer?.cancel();
    _refreshTimeoutTimer = null;
    super.dispose();
  }
}
