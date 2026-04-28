import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';

class AccountLocalStoreException implements Exception {
  const AccountLocalStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountChallengePlaceholder {
  AccountChallengePlaceholder({
    required this.maskedPhoneNumber,
    required this.codeLength,
    required DateTime issuedAt,
  }) : issuedAt = issuedAt.toUtc() {
    if (maskedPhoneNumber.trim().isEmpty) {
      throw const FormatException('maskedPhoneNumber 不能为空。');
    }
    if (codeLength <= 0) {
      throw const FormatException('codeLength 必须大于 0。');
    }
  }

  final String maskedPhoneNumber;
  final int codeLength;
  final DateTime issuedAt;

  Map<String, Object?> toJsonMap() {
    return {
      'maskedPhoneNumber': maskedPhoneNumber,
      'codeLength': codeLength,
      'issuedAt': issuedAt.toIso8601String(),
    };
  }

  factory AccountChallengePlaceholder.fromJsonMap(Map<String, dynamic> json) {
    return AccountChallengePlaceholder(
      maskedPhoneNumber: _readRequiredString(json, 'maskedPhoneNumber'),
      codeLength: _readRequiredInt(json, 'codeLength'),
      issuedAt: _readRequiredDateTime(json, 'issuedAt'),
    );
  }
}

class AccountLocalSnapshot {
  AccountLocalSnapshot({
    required this.consentState,
    this.session,
    this.challenge,
    this.pendingSyncCount = 0,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.lastSyncPhase = 'idle',
    this.lastVisibleError,
    String? upgradeUrl,
    this.lastSyncAt,
  }) : upgradeUrl = _normalizeOptionalString(upgradeUrl) {
    if (pendingSyncCount < 0) {
      throw const FormatException('pendingSyncCount 不能小于 0。');
    }
    if (syncedCount < 0) {
      throw const FormatException('syncedCount 不能小于 0。');
    }
    if (failedCount < 0) {
      throw const FormatException('failedCount 不能小于 0。');
    }
    if (lastSyncPhase.trim().isEmpty) {
      throw const FormatException('lastSyncPhase 不能为空。');
    }
  }

  final AccountConsentState consentState;
  final AccountSession? session;
  final AccountChallengePlaceholder? challenge;
  final int pendingSyncCount;
  final int syncedCount;
  final int failedCount;
  final String lastSyncPhase;
  final String? lastVisibleError;
  final String? upgradeUrl;
  final DateTime? lastSyncAt;

  bool get isSignedIn => session != null;

  bool get isUpgradeRequired =>
      lastSyncPhase.contains('426') || upgradeUrl != null;

  static final AccountLocalSnapshot localOnly = AccountLocalSnapshot(
    consentState: AccountConsentState.localOnly,
  );

  static final AccountLocalSnapshot signedOut = AccountLocalSnapshot(
    consentState: AccountConsentState.signedOut,
  );

  AccountLocalSnapshot copyWith({
    AccountConsentState? consentState,
    AccountSession? session,
    bool clearSession = false,
    AccountChallengePlaceholder? challenge,
    bool clearChallenge = false,
    int? pendingSyncCount,
    int? syncedCount,
    int? failedCount,
    String? lastSyncPhase,
    String? lastVisibleError,
    bool clearLastVisibleError = false,
    String? upgradeUrl,
    bool clearUpgradeUrl = false,
    DateTime? lastSyncAt,
    bool clearLastSyncAt = false,
  }) {
    return AccountLocalSnapshot(
      consentState: consentState ?? this.consentState,
      session: clearSession ? null : (session ?? this.session),
      challenge: clearChallenge ? null : (challenge ?? this.challenge),
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      syncedCount: syncedCount ?? this.syncedCount,
      failedCount: failedCount ?? this.failedCount,
      lastSyncPhase: lastSyncPhase ?? this.lastSyncPhase,
      lastVisibleError: clearLastVisibleError
          ? null
          : (lastVisibleError ?? this.lastVisibleError),
      upgradeUrl: clearUpgradeUrl ? null : (upgradeUrl ?? this.upgradeUrl),
      lastSyncAt: clearLastSyncAt ? null : (lastSyncAt ?? this.lastSyncAt),
    );
  }

  Map<String, Object?> toJsonMap() {
    return {
      'consentState': consentState.wireValue,
      'session': session?.toJsonMap(),
      'challenge': challenge?.toJsonMap(),
      'pendingSyncCount': pendingSyncCount,
      'syncedCount': syncedCount,
      'failedCount': failedCount,
      'lastSyncPhase': lastSyncPhase,
      'lastVisibleError': lastVisibleError,
      'upgradeUrl': upgradeUrl,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
    };
  }

  factory AccountLocalSnapshot.fromJsonMap(Map<String, dynamic> json) {
    final consentState = parseAccountConsentState(
      _readRequiredString(json, 'consentState'),
    );
    final sessionJson = json['session'];
    final challengeJson = json['challenge'];
    final session = sessionJson == null
        ? null
        : AccountSession.fromJsonMap(_readRequiredMap(sessionJson, 'session'));
    final challenge = challengeJson == null
        ? null
        : AccountChallengePlaceholder.fromJsonMap(
            _readRequiredMap(challengeJson, 'challenge'),
          );

    if (consentState == AccountConsentState.acceptedPendingSync &&
        session == null) {
      throw const FormatException('accepted_pending_sync 状态必须携带 session。');
    }

    return AccountLocalSnapshot(
      consentState: consentState,
      session: session,
      challenge: challenge,
      pendingSyncCount: _readOptionalInt(json, 'pendingSyncCount') ?? 0,
      syncedCount: _readOptionalInt(json, 'syncedCount') ?? 0,
      failedCount: _readOptionalInt(json, 'failedCount') ?? 0,
      lastSyncPhase: _readOptionalString(json, 'lastSyncPhase') ?? 'idle',
      lastVisibleError: _readOptionalString(json, 'lastVisibleError'),
      upgradeUrl: _readOptionalString(json, 'upgradeUrl'),
      lastSyncAt: _readOptionalDateTime(json, 'lastSyncAt'),
    );
  }
}

class AccountLocalStore {
  AccountLocalStore({
    FlutterSecureStorage? secureStorage,
    this.storageKey = _defaultKey,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _defaultKey = 'account_state';

  final FlutterSecureStorage _secureStorage;
  final String storageKey;

  Future<AccountLocalSnapshot> read() async {
    try {
      final raw = await _secureStorage.read(key: storageKey);
      if (raw == null || raw.trim().isEmpty) {
        return AccountLocalSnapshot.localOnly;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('account snapshot 顶层必须是对象。');
      }
      return AccountLocalSnapshot.fromJsonMap(decoded);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw AccountLocalStoreException('读取 account snapshot 失败：$error');
    }
  }

  Future<void> write(AccountLocalSnapshot snapshot) async {
    try {
      await _secureStorage.write(
        key: storageKey,
        value: jsonEncode(snapshot.toJsonMap()),
      );
    } catch (error) {
      throw AccountLocalStoreException('写入 account snapshot 失败：$error');
    }
  }

  Future<void> deleteIfExists() async {
    try {
      await _secureStorage.delete(key: storageKey);
    } catch (error) {
      throw AccountLocalStoreException('清理 account snapshot 失败：$error');
    }
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('字段 `$key` 缺失或不是非空字符串。');
  }
  return value;
}

String? _readOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('字段 `$key` 不是字符串。');
  }
  return value;
}

String? _normalizeOptionalString(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

int _readRequiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  throw FormatException('字段 `$key` 缺失或不是整数。');
}

int? _readOptionalInt(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  return _readRequiredInt(json, key);
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('字段 `$key` 缺失或不是合法时间字符串。');
  }
  return DateTime.parse(value).toUtc();
}

DateTime? _readOptionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('字段 `$key` 不是合法时间字符串。');
  }
  return DateTime.parse(value).toUtc();
}

Map<String, dynamic> _readRequiredMap(Object value, String key) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('字段 `$key` 不是对象。');
  }
  return value;
}
