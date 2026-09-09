import 'dart:convert';
import 'dart:io';

import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/domain/models/household_shared_context.dart';
import 'package:path_provider/path_provider.dart';

typedef HouseholdDirectoryResolver = Future<Directory> Function();

class HouseholdLocalStoreException implements Exception {
  const HouseholdLocalStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HouseholdLocalSnapshot {
  const HouseholdLocalSnapshot({
    this.householdId,
    this.role,
    this.sharedContext,
    this.lastPhase = 'idle',
    this.lastVisibleError,
    this.lastAcceptedAt,
    this.pendingClearHouseholdScopeFingerprint,
  }) : assert(lastPhase != '');

  final String? householdId;
  final HouseholdRole? role;
  final HouseholdSharedContext? sharedContext;
  final String lastPhase;
  final String? lastVisibleError;
  final DateTime? lastAcceptedAt;
  final String? pendingClearHouseholdScopeFingerprint;

  bool get hasSharedContext => sharedContext != null;

  static const HouseholdLocalSnapshot empty = HouseholdLocalSnapshot();

  HouseholdLocalSnapshot copyWith({
    String? householdId,
    bool clearHouseholdId = false,
    HouseholdRole? role,
    bool clearRole = false,
    HouseholdSharedContext? sharedContext,
    bool clearSharedContext = false,
    String? lastPhase,
    String? lastVisibleError,
    bool clearLastVisibleError = false,
    DateTime? lastAcceptedAt,
    bool clearLastAcceptedAt = false,
    String? pendingClearHouseholdScopeFingerprint,
    bool clearPendingClearHouseholdScopeFingerprint = false,
  }) {
    final nextHouseholdId = clearHouseholdId
        ? null
        : (householdId ?? this.householdId);
    return HouseholdLocalSnapshot(
      householdId: nextHouseholdId,
      role: nextHouseholdId == null
          ? null
          : (clearRole ? null : (role ?? this.role)),
      sharedContext: nextHouseholdId == null
          ? null
          : (clearSharedContext ? null : (sharedContext ?? this.sharedContext)),
      lastPhase: (lastPhase ?? this.lastPhase).trim().isEmpty
          ? 'idle'
          : (lastPhase ?? this.lastPhase).trim(),
      lastVisibleError: clearLastVisibleError
          ? null
          : _normalizeOptionalString(lastVisibleError ?? this.lastVisibleError),
      lastAcceptedAt: nextHouseholdId == null
          ? null
          : (clearLastAcceptedAt
                ? null
                : (lastAcceptedAt ?? this.lastAcceptedAt)),
      pendingClearHouseholdScopeFingerprint:
          clearPendingClearHouseholdScopeFingerprint
          ? null
          : _normalizeOptionalScopeFingerprint(
              pendingClearHouseholdScopeFingerprint ??
                  this.pendingClearHouseholdScopeFingerprint,
            ),
    );
  }

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'householdId': householdId,
      'role': role?.wireValue,
      'sharedContext': sharedContext?.toJsonMap(),
      'lastPhase': lastPhase,
      'lastVisibleError': lastVisibleError,
      'lastAcceptedAt': lastAcceptedAt?.toIso8601String(),
      'pendingClearHouseholdScopeFingerprint':
          pendingClearHouseholdScopeFingerprint,
    };
  }

  factory HouseholdLocalSnapshot.fromJsonMap(Map<String, dynamic> json) {
    final householdId = _normalizeOptionalString(
      _readOptionalString(json, 'householdId'),
    );
    final role = _parseOptionalRole(json['role']);
    final sharedContext = _parseOptionalSharedContext(json['sharedContext']);
    final lastAcceptedAt = _parseOptionalDateTime(json['lastAcceptedAt']);
    if (householdId == null &&
        ((json.containsKey('role') && json['role'] != null) ||
            (json.containsKey('sharedContext') &&
                json['sharedContext'] != null) ||
            (json.containsKey('lastAcceptedAt') &&
                json['lastAcceptedAt'] != null))) {
      throw const FormatException(
        'household snapshot contains family fields without household id',
      );
    }
    return HouseholdLocalSnapshot(
      householdId: householdId,
      role: role,
      sharedContext: sharedContext,
      lastPhase:
          _normalizeOptionalString(_readOptionalString(json, 'lastPhase')) ??
          'idle',
      lastVisibleError: _normalizeOptionalString(
        _readOptionalString(json, 'lastVisibleError'),
      ),
      lastAcceptedAt: lastAcceptedAt,
      pendingClearHouseholdScopeFingerprint: _parseOptionalScopeFingerprint(
        json['pendingClearHouseholdScopeFingerprint'],
      ),
    );
  }
}

class HouseholdLocalStore {
  HouseholdLocalStore({
    HouseholdDirectoryResolver? directoryResolver,
    this.fileName = 'household_state.json',
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory;

  final HouseholdDirectoryResolver _directoryResolver;
  final String fileName;

  Future<HouseholdLocalSnapshot> read() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        return HouseholdLocalSnapshot.empty;
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        throw const FormatException('household snapshot 为空。');
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('household snapshot 顶层必须是对象。');
      }
      return HouseholdLocalSnapshot.fromJsonMap(decoded);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw HouseholdLocalStoreException('读取 household snapshot 失败：$error');
    }
  }

  Future<void> write(HouseholdLocalSnapshot snapshot) async {
    try {
      final file = await _resolveFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(snapshot.toJsonMap()), flush: true);
    } catch (error) {
      throw HouseholdLocalStoreException('写入 household snapshot 失败：$error');
    }
  }

  Future<void> deleteIfExists() async {
    try {
      final file = await _resolveFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      throw HouseholdLocalStoreException('清理 household snapshot 失败：$error');
    }
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryResolver();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }
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
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

HouseholdRole? _parseOptionalRole(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    return null;
  }
  try {
    return parseHouseholdRole(value);
  } on FormatException {
    return null;
  }
}

HouseholdSharedContext? _parseOptionalSharedContext(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! Map<String, dynamic>) {
    return null;
  }
  try {
    return HouseholdSharedContext.fromJsonMap(value);
  } on FormatException {
    return null;
  }
}

DateTime? _parseOptionalDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    return null;
  }
}

String? _parseOptionalScopeFingerprint(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw const FormatException(
      'household snapshot pending scope fingerprint is invalid',
    );
  }
  return value;
}

String? _normalizeOptionalScopeFingerprint(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return _parseOptionalScopeFingerprint(value);
}
