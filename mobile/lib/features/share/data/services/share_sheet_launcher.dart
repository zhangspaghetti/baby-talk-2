import 'dart:async';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

enum ShareSheetFailureKind { emptyMessage, timeout, unavailable, launchFailed }

enum ShareSheetLaunchStatus { success, dismissed, unavailable }

class ShareSheetLaunchResult {
  const ShareSheetLaunchResult({required this.status, this.raw});

  final ShareSheetLaunchStatus status;
  final String? raw;
}

class ShareSheetException implements Exception {
  const ShareSheetException({required this.kind, required this.message});

  final ShareSheetFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

abstract interface class ShareSheetLauncher {
  Future<ShareSheetLaunchResult> shareText(String text, {String? subject});
}

class SharePlusSheetLauncher implements ShareSheetLauncher {
  const SharePlusSheetLauncher({this.timeout = const Duration(seconds: 8)});

  final Duration timeout;

  @override
  Future<ShareSheetLaunchResult> shareText(
    String text, {
    String? subject,
  }) async {
    final normalizedText = _normalizeShareText(text);
    if (normalizedText == null) {
      throw const ShareSheetException(
        kind: ShareSheetFailureKind.emptyMessage,
        message: '分享文案为空，暂时不能分享。',
      );
    }

    try {
      final result = await SharePlus.instance
          .share(
            ShareParams(
              text: normalizedText,
              subject: _normalizeShareText(subject),
            ),
          )
          .timeout(timeout);
      return ShareSheetLaunchResult(
        status: _mapStatus(result.status),
        raw: result.raw,
      );
    } on TimeoutException {
      throw const ShareSheetException(
        kind: ShareSheetFailureKind.timeout,
        message: '打开分享面板超时，请稍后重试。',
      );
    } on MissingPluginException {
      throw const ShareSheetException(
        kind: ShareSheetFailureKind.unavailable,
        message: '当前设备暂时无法打开分享面板，请稍后重试。',
      );
    } on ShareSheetException {
      rethrow;
    } on Object {
      throw const ShareSheetException(
        kind: ShareSheetFailureKind.launchFailed,
        message: '打开分享面板失败，请稍后重试。',
      );
    }
  }

  ShareSheetLaunchStatus _mapStatus(ShareResultStatus status) {
    switch (status) {
      case ShareResultStatus.success:
        return ShareSheetLaunchStatus.success;
      case ShareResultStatus.dismissed:
        return ShareSheetLaunchStatus.dismissed;
      case ShareResultStatus.unavailable:
        return ShareSheetLaunchStatus.unavailable;
    }
  }
}

String? _normalizeShareText(String? rawText) {
  if (rawText == null) {
    return null;
  }
  final normalized = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}
