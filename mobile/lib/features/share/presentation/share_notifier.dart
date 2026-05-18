import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/share/data/repositories/share_repository.dart';
import 'package:mobile/features/share/domain/models/share_link_draft.dart';

enum ShareViewStatus { idle, success, cancelled, error }

class ShareNotifier extends ChangeNotifier {
  ShareNotifier({
    required ShareRepository repository,
    GardenGrowthSnapshot? initialGrowthSnapshot,
    PracticeContinuitySnapshot? initialContinuitySnapshot,
  }) : _repository = repository,
       _growthSnapshot = initialGrowthSnapshot,
       _continuitySnapshot = initialContinuitySnapshot;

  final ShareRepository _repository;

  GardenGrowthSnapshot? _growthSnapshot;
  PracticeContinuitySnapshot? _continuitySnapshot;
  AsyncValue<ShareExecutionResult?> _shareRequest =
      const AsyncValue<ShareExecutionResult?>.data(null);
  ShareViewStatus _lastShareStatus = ShareViewStatus.idle;
  String? _message;
  String? _lastSharePhase;
  bool _disposed = false;
  Future<ShareExecutionResult>? _shareFuture;

  ShareLinkDraft? get currentDraft => _repository.buildDraft(
    growthSnapshot: _growthSnapshot,
    continuitySnapshot: _continuitySnapshot,
  );

  bool get hasShareDraft => currentDraft != null;

  AsyncValue<ShareExecutionResult?> get shareRequest => _shareRequest;

  bool get canShare => !isSharing && hasShareDraft;

  bool get isSharing => _shareRequest.isLoading;
  ShareViewStatus get lastShareStatus => _lastShareStatus;
  String? get message => _message;
  String? get lastSharePhase => _lastSharePhase;

  void updateSnapshots({
    GardenGrowthSnapshot? growthSnapshot,
    PracticeContinuitySnapshot? continuitySnapshot,
    bool notify = true,
  }) {
    final previousDraftSignature = _draftSignature(currentDraft);
    _growthSnapshot = growthSnapshot;
    _continuitySnapshot = continuitySnapshot;
    final nextDraftSignature = _draftSignature(currentDraft);
    if (notify && previousDraftSignature != nextDraftSignature) {
      notifyListeners();
    }
  }

  Future<ShareExecutionResult> shareCurrent() {
    if (isSharing) {
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
    _shareRequest = const AsyncValue<ShareExecutionResult?>.loading();
    _message = null;
    notifyListeners();

    final result = await _repository.shareSnapshots(
      growthSnapshot: _growthSnapshot,
      continuitySnapshot: _continuitySnapshot,
    );

    if (_disposed) {
      return result;
    }

    _shareRequest = AsyncValue<ShareExecutionResult?>.data(result);
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

  String? _draftSignature(ShareLinkDraft? draft) {
    if (draft == null) {
      return null;
    }
    return [
      draft.source.wireValue,
      draft.headline,
      draft.storyText,
      draft.phraseText,
      draft.recommendationTitle,
      draft.recommendationReason,
      draft.spaceId,
      draft.activityId,
    ].join('|');
  }
}
