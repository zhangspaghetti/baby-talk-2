import 'package:freezed_annotation/freezed_annotation.dart';

part '../../../../generated/features/account/domain/models/account_session.freezed.dart';

@freezed
class AccountSession with _$AccountSession {
  AccountSession._();

  factory AccountSession({
    required String accountId,
    required String sessionId,
    required String maskedPhoneNumber,
    required DateTime createdAt,
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    DateTime? accessTokenExpiresAt,
    DateTime? refreshTokenExpiresAt,
  }) = _AccountSession;

  factory AccountSession.validated({
    required String accountId,
    required String sessionId,
    required String maskedPhoneNumber,
    required DateTime createdAt,
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    DateTime? accessTokenExpiresAt,
    DateTime? refreshTokenExpiresAt,
  }) {
    final normalizedAccessToken = normalizeOptionalString(accessToken);
    final normalizedRefreshToken = normalizeOptionalString(refreshToken);
    final normalizedTokenType = normalizeOptionalString(tokenType);
    final utcCreatedAt = createdAt.toUtc();
    final utcAccessTokenExpiresAt = accessTokenExpiresAt?.toUtc();
    final utcRefreshTokenExpiresAt = refreshTokenExpiresAt?.toUtc();

    if (accountId.trim().isEmpty) {
      throw const FormatException('accountId 不能为空。');
    }
    if (sessionId.trim().isEmpty) {
      throw const FormatException('sessionId 不能为空。');
    }
    if (maskedPhoneNumber.trim().isEmpty) {
      throw const FormatException('maskedPhoneNumber 不能为空。');
    }

    final hasAnyJwtField =
        normalizedAccessToken != null ||
        normalizedRefreshToken != null ||
        normalizedTokenType != null ||
        utcAccessTokenExpiresAt != null ||
        utcRefreshTokenExpiresAt != null;
    if (hasAnyJwtField) {
      if (normalizedAccessToken == null || normalizedRefreshToken == null) {
        throw const FormatException(
          'JWT session 必须同时包含 accessToken 与 refreshToken。',
        );
      }
      if (utcAccessTokenExpiresAt == null || utcRefreshTokenExpiresAt == null) {
        throw const FormatException(
          'JWT session 必须同时包含 accessTokenExpiresAt 与 refreshTokenExpiresAt。',
        );
      }
    }

    return AccountSession(
      accountId: accountId,
      sessionId: sessionId,
      maskedPhoneNumber: maskedPhoneNumber,
      createdAt: utcCreatedAt,
      accessToken: normalizedAccessToken,
      refreshToken: normalizedRefreshToken,
      tokenType: normalizedTokenType,
      accessTokenExpiresAt: utcAccessTokenExpiresAt,
      refreshTokenExpiresAt: utcRefreshTokenExpiresAt,
    );
  }

  factory AccountSession.fromJsonMap(Map<String, dynamic> json) {
    return AccountSession.validated(
      accountId: readRequiredString(json, 'accountId'),
      sessionId: readRequiredString(json, 'sessionId'),
      maskedPhoneNumber: readRequiredString(json, 'maskedPhoneNumber'),
      createdAt: readRequiredDateTime(json, 'createdAt'),
      accessToken: readOptionalString(json, 'accessToken'),
      refreshToken: readOptionalString(json, 'refreshToken'),
      tokenType: readOptionalString(json, 'tokenType'),
      accessTokenExpiresAt: readOptionalDateTime(json, 'accessTokenExpiresAt'),
      refreshTokenExpiresAt: readOptionalDateTime(
        json,
        'refreshTokenExpiresAt',
      ),
    );
  }

  bool get hasJwtTokens => accessToken != null && refreshToken != null;

  String get normalizedTokenType => tokenType ?? 'Cookie';

  String get requireAccessToken {
    final value = accessToken;
    if (value == null) {
      throw StateError('当前 session 缺少 accessToken。');
    }
    return value;
  }

  String get requireRefreshToken {
    final value = refreshToken;
    if (value == null) {
      throw StateError('当前 session 缺少 refreshToken。');
    }
    return value;
  }

  AccountSession withJwtTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime accessTokenExpiresAt,
    required DateTime refreshTokenExpiresAt,
    String tokenType = 'Cookie',
  }) {
    return AccountSession(
      accountId: accountId,
      sessionId: sessionId,
      maskedPhoneNumber: maskedPhoneNumber,
      createdAt: createdAt,
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      accessTokenExpiresAt: accessTokenExpiresAt,
      refreshTokenExpiresAt: refreshTokenExpiresAt,
    );
  }

  Map<String, Object?> toJsonMap() {
    return {
      'accountId': accountId,
      'sessionId': sessionId,
      'maskedPhoneNumber': maskedPhoneNumber,
      'createdAt': createdAt.toIso8601String(),
      if (accessToken != null) 'accessToken': accessToken,
      if (refreshToken != null) 'refreshToken': refreshToken,
      if (hasJwtTokens) 'tokenType': normalizedTokenType,
      if (accessTokenExpiresAt != null)
        'accessTokenExpiresAt': accessTokenExpiresAt!.toIso8601String(),
      if (refreshTokenExpiresAt != null)
        'refreshTokenExpiresAt': refreshTokenExpiresAt!.toIso8601String(),
    };
  }

  // --- Shared validation helpers ---

  static String readRequiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('字段 `$key` 缺失或不是非空字符串。');
    }
    return value;
  }

  static String? readOptionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw FormatException('字段 `$key` 不是字符串。');
    }
    return value;
  }

  static String? normalizeOptionalString(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static DateTime readRequiredDateTime(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('字段 `$key` 缺失或不是合法时间字符串。');
    }
    return DateTime.parse(value).toUtc();
  }

  static DateTime? readOptionalDateTime(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('字段 `$key` 不是合法时间字符串。');
    }
    return DateTime.parse(value).toUtc();
  }
}
