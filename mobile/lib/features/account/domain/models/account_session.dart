class AccountSession {
  AccountSession({
    required this.accountId,
    required this.sessionId,
    required this.maskedPhoneNumber,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc() {
    if (accountId.trim().isEmpty) {
      throw const FormatException('accountId 不能为空。');
    }
    if (sessionId.trim().isEmpty) {
      throw const FormatException('sessionId 不能为空。');
    }
    if (maskedPhoneNumber.trim().isEmpty) {
      throw const FormatException('maskedPhoneNumber 不能为空。');
    }
  }

  final String accountId;
  final String sessionId;
  final String maskedPhoneNumber;
  final DateTime createdAt;

  Map<String, Object?> toJsonMap() {
    return {
      'accountId': accountId,
      'sessionId': sessionId,
      'maskedPhoneNumber': maskedPhoneNumber,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AccountSession.fromJsonMap(Map<String, dynamic> json) {
    return AccountSession(
      accountId: _readRequiredString(json, 'accountId'),
      sessionId: _readRequiredString(json, 'sessionId'),
      maskedPhoneNumber: _readRequiredString(json, 'maskedPhoneNumber'),
      createdAt: _readRequiredDateTime(json, 'createdAt'),
    );
  }

  static String _readRequiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('字段 `$key` 缺失或不是非空字符串。');
    }
    return value;
  }

  static DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('字段 `$key` 缺失或不是合法时间字符串。');
    }
    return DateTime.parse(value).toUtc();
  }
}
