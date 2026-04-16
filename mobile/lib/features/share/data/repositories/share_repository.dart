import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/share/data/services/share_api_service.dart';
import 'package:mobile/features/share/data/services/share_sheet_launcher.dart';
import 'package:mobile/features/share/domain/models/share_link_draft.dart';

typedef SharePlatformHintResolver = String? Function();

enum ShareExecutionStatus { shared, cancelled, failed }

class ShareExecutionResult {
  const ShareExecutionResult({
    required this.status,
    required this.phase,
    required this.message,
    this.draft,
    this.shareUrl,
    this.token,
  });

  final ShareExecutionStatus status;
  final String phase;
  final String message;
  final ShareLinkDraft? draft;
  final String? shareUrl;
  final String? token;

  bool get isSuccess => status == ShareExecutionStatus.shared;
  bool get isCancelled => status == ShareExecutionStatus.cancelled;
  bool get isFailure => status == ShareExecutionStatus.failed;
}

class ShareRepository {
  ShareRepository({
    required ShareApiService apiService,
    required ShareSheetLauncher shareSheetLauncher,
    SharePlatformHintResolver? platformHintResolver,
  }) : _apiService = apiService,
       _shareSheetLauncher = shareSheetLauncher,
       _platformHintResolver = platformHintResolver ?? _defaultPlatformHintResolver;

  final ShareApiService _apiService;
  final ShareSheetLauncher _shareSheetLauncher;
  final SharePlatformHintResolver _platformHintResolver;

  ShareLinkDraft? buildDraft({
    GardenGrowthSnapshot? growthSnapshot,
    PracticeContinuitySnapshot? continuitySnapshot,
  }) {
    return ShareLinkDraft.fromSnapshots(
      growthSnapshot: growthSnapshot,
      continuitySnapshot: continuitySnapshot,
    );
  }

  bool canShare({
    GardenGrowthSnapshot? growthSnapshot,
    PracticeContinuitySnapshot? continuitySnapshot,
  }) {
    return buildDraft(
          growthSnapshot: growthSnapshot,
          continuitySnapshot: continuitySnapshot,
        ) !=
        null;
  }

  Future<ShareExecutionResult> shareSnapshots({
    GardenGrowthSnapshot? growthSnapshot,
    PracticeContinuitySnapshot? continuitySnapshot,
  }) async {
    final draft = buildDraft(
      growthSnapshot: growthSnapshot,
      continuitySnapshot: continuitySnapshot,
    );
    if (draft == null) {
      return const ShareExecutionResult(
        status: ShareExecutionStatus.failed,
        phase: 'draft_unavailable',
        message: '当前还没有可分享的成长瞬间。',
      );
    }

    final platformHint = _platformHintResolver();
    final ShareCreateLinkResponse response;
    try {
      response = await _apiService.createShareLink(
        draft: draft,
        platformHint: platformHint,
      );
    } on ShareApiException catch (error) {
      return ShareExecutionResult(
        status: ShareExecutionStatus.failed,
        phase: _phaseForApiError(error),
        message: _messageForApiError(error),
        draft: draft,
      );
    }

    final shareMessage = draft.buildShareMessage(response.shareUrl);
    if (shareMessage == null) {
      return ShareExecutionResult(
        status: ShareExecutionStatus.failed,
        phase: 'share_message_invalid',
        message: '分享文案异常，暂时不能分享。',
        draft: draft,
        shareUrl: response.shareUrl,
        token: response.token,
      );
    }

    try {
      final result = await _shareSheetLauncher.shareText(
        shareMessage,
        subject: draft.headline,
      );
      switch (result.status) {
        case ShareSheetLaunchStatus.success:
          return ShareExecutionResult(
            status: ShareExecutionStatus.shared,
            phase: 'share_sheet_success',
            message: '分享面板已打开。',
            draft: draft,
            shareUrl: response.shareUrl,
            token: response.token,
          );
        case ShareSheetLaunchStatus.dismissed:
          return ShareExecutionResult(
            status: ShareExecutionStatus.cancelled,
            phase: 'share_sheet_dismissed',
            message: '已取消分享。',
            draft: draft,
            shareUrl: response.shareUrl,
            token: response.token,
          );
        case ShareSheetLaunchStatus.unavailable:
          return ShareExecutionResult(
            status: ShareExecutionStatus.failed,
            phase: 'share_sheet_unavailable',
            message: '当前设备暂时无法打开分享面板，请稍后重试。',
            draft: draft,
            shareUrl: response.shareUrl,
            token: response.token,
          );
      }
    } on ShareSheetException catch (error) {
      return ShareExecutionResult(
        status: ShareExecutionStatus.failed,
        phase: _phaseForShareSheetError(error),
        message: error.message,
        draft: draft,
        shareUrl: response.shareUrl,
        token: response.token,
      );
    }
  }

  static String _messageForApiError(ShareApiException error) {
    switch (error.kind) {
      case ShareApiFailureKind.network:
        return '网络暂时不可用，请稍后重试。';
      case ShareApiFailureKind.timeout:
        return '分享链接生成超时，请稍后重试。';
      case ShareApiFailureKind.malformed:
        return '分享链接响应异常，请稍后重试。';
      case ShareApiFailureKind.http:
        return error.isServerFailure
            ? '分享链接暂时不可用，请稍后重试。'
            : '当前分享内容暂时无法生成链接，请稍后重试。';
    }
  }

  static String _phaseForApiError(ShareApiException error) {
    switch (error.kind) {
      case ShareApiFailureKind.network:
        return 'create_network_failed';
      case ShareApiFailureKind.timeout:
        return 'create_timeout';
      case ShareApiFailureKind.malformed:
        return 'create_malformed_response';
      case ShareApiFailureKind.http:
        return 'create_http_${error.statusCode ?? 'unknown'}';
    }
  }

  static String _phaseForShareSheetError(ShareSheetException error) {
    switch (error.kind) {
      case ShareSheetFailureKind.emptyMessage:
        return 'share_message_invalid';
      case ShareSheetFailureKind.timeout:
        return 'share_sheet_timeout';
      case ShareSheetFailureKind.unavailable:
        return 'share_sheet_unavailable';
      case ShareSheetFailureKind.launchFailed:
        return 'share_sheet_failed';
    }
  }

  static String? _defaultPlatformHintResolver() {
    if (kIsWeb) {
      return null;
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return null;
  }
}
