import 'dart:async';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum AccountExternalLinkFailureKind {
  missingUrl,
  malformedUrl,
  unsafeScheme,
  timeout,
  unavailable,
  launchFailed,
}

class AccountUpgradeUrlValidation {
  const AccountUpgradeUrlValidation._({this.uri, this.failureKind});

  final Uri? uri;
  final AccountExternalLinkFailureKind? failureKind;

  bool get isValid => uri != null && failureKind == null;

  String? get normalizedUrl => uri?.toString();

  static AccountUpgradeUrlValidation valid(Uri uri) {
    return AccountUpgradeUrlValidation._(uri: uri);
  }

  static AccountUpgradeUrlValidation invalid(
    AccountExternalLinkFailureKind failureKind,
  ) {
    return AccountUpgradeUrlValidation._(failureKind: failureKind);
  }
}

AccountUpgradeUrlValidation validateAccountUpgradeUrl(String? rawUrl) {
  final normalized = rawUrl?.trim();
  if (normalized == null || normalized.isEmpty) {
    return AccountUpgradeUrlValidation.invalid(
      AccountExternalLinkFailureKind.missingUrl,
    );
  }

  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
    return AccountUpgradeUrlValidation.invalid(
      AccountExternalLinkFailureKind.malformedUrl,
    );
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') {
    return AccountUpgradeUrlValidation.invalid(
      AccountExternalLinkFailureKind.unsafeScheme,
    );
  }

  return AccountUpgradeUrlValidation.valid(uri);
}

String messageForAccountUpgradeUrlFailure(
  AccountExternalLinkFailureKind failureKind,
) {
  switch (failureKind) {
    case AccountExternalLinkFailureKind.missingUrl:
      return '升级入口暂未配置，请稍后重试或联系支持。';
    case AccountExternalLinkFailureKind.malformedUrl:
    case AccountExternalLinkFailureKind.unsafeScheme:
      return '升级链接配置错误，请稍后重试或联系支持。';
    case AccountExternalLinkFailureKind.timeout:
      return '打开升级页面超时，请稍后重试。';
    case AccountExternalLinkFailureKind.unavailable:
      return '当前设备暂时无法打开升级页面，请稍后重试。';
    case AccountExternalLinkFailureKind.launchFailed:
      return '打开升级页面失败，请稍后重试。';
  }
}

class AccountExternalLinkException implements Exception {
  const AccountExternalLinkException({
    required this.kind,
    required this.message,
  });

  final AccountExternalLinkFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

abstract interface class AccountExternalLinkOpener {
  Future<void> openUpgradeUrl(String url);
}

class UrlLauncherAccountExternalLinkOpener
    implements AccountExternalLinkOpener {
  const UrlLauncherAccountExternalLinkOpener({
    this.timeout = const Duration(seconds: 4),
  });

  final Duration timeout;

  @override
  Future<void> openUpgradeUrl(String url) async {
    final validation = validateAccountUpgradeUrl(url);
    if (!validation.isValid) {
      throw AccountExternalLinkException(
        kind:
            validation.failureKind ??
            AccountExternalLinkFailureKind.launchFailed,
        message: messageForAccountUpgradeUrlFailure(
          validation.failureKind ?? AccountExternalLinkFailureKind.launchFailed,
        ),
      );
    }

    try {
      final launched = await launchUrl(
        validation.uri!,
        mode: LaunchMode.externalApplication,
      ).timeout(timeout);
      if (!launched) {
        throw const AccountExternalLinkException(
          kind: AccountExternalLinkFailureKind.unavailable,
          message: '当前设备暂时无法打开升级页面，请稍后重试。',
        );
      }
    } on TimeoutException {
      throw const AccountExternalLinkException(
        kind: AccountExternalLinkFailureKind.timeout,
        message: '打开升级页面超时，请稍后重试。',
      );
    } on MissingPluginException {
      throw const AccountExternalLinkException(
        kind: AccountExternalLinkFailureKind.unavailable,
        message: '当前设备暂时无法打开升级页面，请稍后重试。',
      );
    } on AccountExternalLinkException {
      rethrow;
    } on Object {
      throw const AccountExternalLinkException(
        kind: AccountExternalLinkFailureKind.launchFailed,
        message: '打开升级页面失败，请稍后重试。',
      );
    }
  }
}
