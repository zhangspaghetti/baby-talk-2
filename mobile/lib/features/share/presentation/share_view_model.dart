import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/share/data/repositories/share_repository.dart';

enum ShareViewStatus { idle, success, cancelled, error }

class ShareViewModel extends ChangeNotifier {
  ShareViewModel({
    required ShareRepository repository,
    GardenGrowthSnapshot? initialGrowthSnapshot,
    PracticeContinuitySnapshot? initialContinuitySnapshot,
  }) : _repository = repository,
       _growthSnapshot = initialGrowthSnapshot,
       _continuitySnapshot = initialContinuitySnapshot;

  final ShareRepository _repository;

  GardenGrowthSnapshot? _growthSnapshot;
  PracticeContinuitySnapshot? _continuitySnapshot;
  bool _isSharing = false;
  ShareViewStatus _lastShareStatus = ShareViewStatus.idle;
  String? _message;
  String? _lastSharePhase;
  bool _disposed = false;
  Future<ShareExecutionResult>? _shareFuture;

  bool get canShare =>
      !_isSharing &&
      _repository.canShare(
        growthSnapshot: _growthSnapshot,
        continuitySnapshot: _continuitySnapshot,
      );

  bool get isSharing => _isSharing;
  ShareViewStatus get lastShareStatus => _lastShareStatus;
  String? get message => _message;
  String? get lastSharePhase => _lastSharePhase;

  void updateSnapshots({
    GardenGrowthSnapshot? growthSnapshot,
    PracticeContinuitySnapshot? continuitySnapshot,
  }) {
    _growthSnapshot = growthSnapshot;
    _continuitySnapshot = continuitySnapshot;
    notifyListeners();
  }

  Future<ShareExecutionResult> shareCurrent() {
    if (_isSharing) {
      return _shareFuture ??
          Future<ShareExecutionResult>.value(
            ShareExecutionResult(
              status: ShareExecutionStatus.failed,
              phase: 'share_already_running',
              message: '分享仍在进行中，请稍候。',
            ),
          );
    }

    final future = _shareInternal();
    _shareFuture = future;
    return future.whenComplete(() {
      if (identical(_shareFuture, future)) {
        _shareFuture = null;
      }
    });
  }

  Future<ShareExecutionResult> _shareInternal() async {
    _isSharing = true;
    _message = null;
    notifyListeners();

    final result = await _repository.shareSnapshots(
      growthSnapshot: _growthSnapshot,
      continuitySnapshot: _continuitySnapshot,
    );

    if (_disposed) {
      return result;
    }

    _isSharing = false;
    _lastSharePhase = result.phase;
    _message = result.message;
    switch (result.status) {
      case ShareExecutionStatus.shared:
        _lastShareStatus = ShareViewStatus.success;
      case ShareExecutionStatus.cancelled:
        _lastShareStatus = ShareViewStatus.cancelled;
      case ShareExecutionStatus.failed:
        _lastShareStatus = ShareViewStatus.error;
    }
    notifyListeners();
    return result;
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
    super.dispose();
  }
}
