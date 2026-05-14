import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/app/invite_reentry_coordinator.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/domain/models/household_invite_link.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';

enum HouseholdActionKind {
  none,
  createInvite,
  acceptInvite,
  refreshSharedContext,
}

class HouseholdNotifier extends ChangeNotifier {
  HouseholdNotifier({required HouseholdRepository repository})
    : _repository = repository;

  final HouseholdRepository _repository;

  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isBusy = false;
  bool _disposed = false;
  HouseholdLocalSnapshot _snapshot = HouseholdLocalSnapshot.empty;
  HouseholdInviteLink? _lastCreatedInvite;
  String? _message;
  HouseholdActionKind _lastActionKind = HouseholdActionKind.none;
  InviteReentryAcceptCommand? _lastAcceptCommand;
  Future<void>? _initializeFuture;
  Future<HouseholdCreateInviteResult>? _createFuture;
  Future<HouseholdInviteAcceptResult>? _acceptFuture;
  Future<HouseholdLocalSnapshot>? _refreshFuture;

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isBusy => _isBusy;
  HouseholdLocalSnapshot get snapshot => _snapshot;
  HouseholdInviteLink? get lastCreatedInvite => _lastCreatedInvite;
  String? get message => _message;
  HouseholdActionKind get lastActionKind => _lastActionKind;

  Future<void> initialize() {
    if (_hasLoaded || _isLoading) {
      return _initializeFuture ?? Future.value();
    }
    final future = _initializeInternal();
    _initializeFuture = future;
    return future.whenComplete(() {
      if (identical(_initializeFuture, future)) {
        _initializeFuture = null;
      }
    });
  }

  Future<void> _initializeInternal() async {
    await reload();
  }

  Future<void> reload() async {
    if (_disposed || _isLoading) {
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      _snapshot = await _repository.loadSnapshot();
      _hasLoaded = true;
      _message = _snapshot.lastVisibleError;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<HouseholdCreateInviteResult> createInvite({
    HouseholdRole role = HouseholdRole.caregiver,
    String source = 'household_settings',
  }) {
    final inFlight = _createFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _createInviteInternal(role: role, source: source);
    _createFuture = future;
    return future.whenComplete(() {
      if (identical(_createFuture, future)) {
        _createFuture = null;
      }
    });
  }

  Future<HouseholdCreateInviteResult> _createInviteInternal({
    required HouseholdRole role,
    required String source,
  }) async {
    _isBusy = true;
    _message = '正在创建照护邀请…';
    _lastActionKind = HouseholdActionKind.createInvite;
    notifyListeners();
    try {
      final result = await _repository.createInvite(role: role, source: source);
      if (_disposed) {
        return result;
      }
      _snapshot = result.snapshot;
      _lastCreatedInvite = result.inviteLink;
      _message = result.message;
      return result;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<HouseholdInviteAcceptResult> acceptInviteFromReentry(
    InviteReentryAcceptCommand command,
  ) {
    final inFlight = _acceptFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _acceptInviteInternal(command);
    _acceptFuture = future;
    return future.whenComplete(() {
      if (identical(_acceptFuture, future)) {
        _acceptFuture = null;
      }
    });
  }

  Future<HouseholdInviteAcceptResult> _acceptInviteInternal(
    InviteReentryAcceptCommand command,
  ) async {
    _isBusy = true;
    _message = '正在接受照护邀请…';
    _lastActionKind = HouseholdActionKind.acceptInvite;
    _lastAcceptCommand = command;
    notifyListeners();
    try {
      final result = await _repository.acceptInvite(
        token: command.token,
        source: command.source,
      );
      if (_disposed) {
        return result;
      }
      _snapshot = result.snapshot;
      _message = result.message;
      return result;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<HouseholdLocalSnapshot> refreshSharedContext({
    String reason = 'manual_refresh',
  }) {
    final inFlight = _refreshFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _refreshSharedContextInternal(reason: reason);
    _refreshFuture = future;
    return future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    });
  }

  Future<HouseholdLocalSnapshot> _refreshSharedContextInternal({
    required String reason,
  }) async {
    _isBusy = true;
    _message = '正在刷新共享上下文…';
    _lastActionKind = HouseholdActionKind.refreshSharedContext;
    notifyListeners();
    try {
      final snapshot = await _repository.refreshSharedContext(reason: reason);
      if (_disposed) {
        return snapshot;
      }
      _snapshot = snapshot;
      _message = snapshot.lastVisibleError ?? '共享上下文已刷新。';
      return snapshot;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> retryLastAction() async {
    switch (_lastActionKind) {
      case HouseholdActionKind.none:
        return false;
      case HouseholdActionKind.createInvite:
        final result = await createInvite();
        return result.isSuccess;
      case HouseholdActionKind.acceptInvite:
        final command = _lastAcceptCommand;
        if (command == null) {
          return false;
        }
        final result = await acceptInviteFromReentry(command);
        return result.shouldRouteToPractice;
      case HouseholdActionKind.refreshSharedContext:
        final snapshot = await refreshSharedContext(
          reason: 'retry_last_action',
        );
        return snapshot.hasSharedContext;
    }
  }

  void clearMessage() {
    if (_message == null) {
      return;
    }
    _message = null;
    notifyListeners();
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
    _isLoading = false;
    _hasLoaded = false;
    _isBusy = false;
    _snapshot = HouseholdLocalSnapshot.empty;
    _lastCreatedInvite = null;
    _message = null;
    _lastActionKind = HouseholdActionKind.none;
    _lastAcceptCommand = null;
    _initializeFuture = null;
    _createFuture = null;
    _acceptFuture = null;
    _refreshFuture = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_repository.close());
    super.dispose();
  }
}
