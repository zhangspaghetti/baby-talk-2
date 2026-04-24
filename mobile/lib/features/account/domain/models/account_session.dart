class AccountSession {
  AccountSession({
    required this.accountId,
    required this.sessionId,
    required this.maskedPhoneNumber,
    required DateTime createdAt,
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    DateTime? accessTokenExpiresAt,
    DateTime? refreshTokenExpiresAt,
  }) : createdAt = createdAt.toUtc(),
       accessToken = _normalizeOptionalString(accessToken),
       refreshToken = _normalizeOptionalString(refreshToken),
       tokenType = _normalizeOptionalString(tokenType),
       accessTokenExpiresAt = accessTokenExpiresAt?.toUtc(),
       refreshTokenExpiresAt = refreshTokenExpiresAt?.toUtc() {
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
        this.accessToken != null ||
        this.refreshToken != null ||
        this.tokenType != null ||
        this.accessTokenExpiresAt != null ||
        this.refreshTokenExpiresAt != null;
    if (!hasAnyJwtField) {
      return;
    }

    if (this.accessToken == null || this.refreshToken == null) {
      throw const FormatException(
        'JWT session 必须同时包含 accessToken 与 refreshToken。',
      );
    }
    if (this.accessTokenExpiresAt == null ||
        this.refreshTokenExpiresAt == null) {
      throw const FormatException(
        'JWT session 必须同时包含 accessTokenExpiresAt 与 refreshTokenExpiresAt。',
      );
    }
  }

  final String accountId;
  final String sessionId;
  final String maskedPhoneNumber;
  final DateTime createdAt;
  final String? accessToken;
  final String? refreshToken;
  final String? tokenType;
  final DateTime? accessTokenExpiresAt;
  final DateTime? refreshTokenExpiresAt;

  bool get hasJwtTokens => accessToken != null && refreshToken != null;

  String get normalizedTokenType => tokenType ?? 'Bearer';

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
    String tokenType = 'Bearer',
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

  factory AccountSession.fromJsonMap(Map<String, dynamic> json) {
    return AccountSession(
      accountId: _readRequiredString(json, 'accountId'),
      sessionId: _readRequiredString(json, 'sessionId'),
      maskedPhoneNumber: _readRequiredString(json, 'maskedPhoneNumber'),
      createdAt: _readRequiredDateTime(json, 'createdAt'),
      accessToken: _readOptionalString(json, 'accessToken'),
      refreshToken: _readOptionalString(json, 'refreshToken'),
      tokenType: _readOptionalString(json, 'tokenType'),
      accessTokenExpiresAt: _readOptionalDateTime(json, 'accessTokenExpiresAt'),
      refreshTokenExpiresAt: _readOptionalDateTime(
        json,
        'refreshTokenExpiresAt',
      ),
    );
  }

  static String _readRequiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('字段 `$key` 缺失或不是非空字符串。');
    }
    return value;
  }

  static String? _readOptionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw FormatException('字段 `$key` 不是字符串。');
    }
    return value;
  }

  static String? _normalizeOptionalString(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('字段 `$key` 缺失或不是合法时间字符串。');
    }
    return DateTime.parse(value).toUtc();
  }

  static DateTime? _readOptionalDateTime(
    Map<String, dynamic> json,
    String key,
  ) {
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
