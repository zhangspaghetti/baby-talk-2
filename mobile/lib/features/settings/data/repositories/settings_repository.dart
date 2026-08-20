import 'dart:convert';

import 'package:mobile/features/settings/data/local/settings_local_data_source.dart';

/// Current settings schema version. Bump when the JSON shape changes.
const int settingsSchemaVersion = 1;

/// ---------------------------------------------------------------------------
/// SettingsSnapshot — serialisable domain model for application settings.
/// ---------------------------------------------------------------------------

class SettingsSnapshot {
  const SettingsSnapshot({
    this.reminderEnabled = false,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.childName = '',
    this.childBirthDate,
    this.childAgeMonths,
    this.childStage = '',
    this.caregiverRole = '',
    this.preferredLanguage = 'zh',
    this.autoPlayEnabled = true,
    this.audioSpeed = 1.0,
    this.appVersion = '',
    this.profileAccountId,
    this.lastModifiedAt,
  });

  /// Deserialise from a JSON map.
  factory SettingsSnapshot.fromJson(Map<String, dynamic> json) {
    return SettingsSnapshot(
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      reminderHour: json['reminderHour'] as int? ?? 9,
      reminderMinute: json['reminderMinute'] as int? ?? 0,
      childName: json['childName'] as String? ?? '',
      childBirthDate: _readOptionalDateTime(json, 'childBirthDate'),
      childAgeMonths: json['childAgeMonths'] as int?,
      childStage: json['childStage'] as String? ?? '',
      caregiverRole: json['caregiverRole'] as String? ?? '',
      preferredLanguage: json['preferredLanguage'] as String? ?? 'zh',
      autoPlayEnabled: json['autoPlayEnabled'] as bool? ?? true,
      audioSpeed: (json['audioSpeed'] as num?)?.toDouble() ?? 1.0,
      appVersion: json['appVersion'] as String? ?? '',
      profileAccountId: json['profileAccountId'] as String?,
      lastModifiedAt: _readOptionalDateTime(json, 'lastModifiedAt'),
    );
  }

  /// Serialise to a JSON map.
  Map<String, Object?> toJson() {
    return {
      'reminderEnabled': reminderEnabled,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'childName': childName,
      'childBirthDate': childBirthDate?.toUtc().toIso8601String(),
      'childAgeMonths': childAgeMonths,
      'childStage': childStage,
      'caregiverRole': caregiverRole,
      'preferredLanguage': preferredLanguage,
      'autoPlayEnabled': autoPlayEnabled,
      'audioSpeed': audioSpeed,
      'appVersion': appVersion,
      'profileAccountId': profileAccountId,
      'lastModifiedAt': lastModifiedAt?.toUtc().toIso8601String(),
    };
  }

  /// Deserialise from a raw JSON string.
  factory SettingsSnapshot.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('settings snapshot 顶层必须是对象。');
    }
    return SettingsSnapshot.fromJson(decoded);
  }

  /// Serialise to a JSON string.
  String toJsonString() => jsonEncode(toJson());

  // --- Fields ---

  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final String childName;
  final DateTime? childBirthDate;
  final int? childAgeMonths;
  final String childStage;
  final String caregiverRole;
  final String preferredLanguage;
  final bool autoPlayEnabled;
  final double audioSpeed;
  final String appVersion;

  /// Account scope of the last remotely confirmed baby profile projection.
  /// Null means this snapshot is local-only and must not be treated as a
  /// server authority.
  final String? profileAccountId;
  final DateTime? lastModifiedAt;

  /// Returns a new copy with the given fields overridden.
  SettingsSnapshot copyWith({
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    String? childName,
    DateTime? childBirthDate,
    bool clearChildBirthDate = false,
    int? childAgeMonths,
    String? childStage,
    String? caregiverRole,
    String? preferredLanguage,
    bool? autoPlayEnabled,
    double? audioSpeed,
    String? appVersion,
    String? profileAccountId,
    bool clearProfileAccountId = false,
    bool clearChildAgeMonths = false,
    DateTime? lastModifiedAt,
  }) {
    return SettingsSnapshot(
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      childName: childName ?? this.childName,
      childBirthDate: clearChildBirthDate
          ? null
          : (childBirthDate ?? this.childBirthDate),
      childAgeMonths: clearChildAgeMonths
          ? null
          : (childAgeMonths ?? this.childAgeMonths),
      childStage: childStage ?? this.childStage,
      caregiverRole: caregiverRole ?? this.caregiverRole,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      autoPlayEnabled: autoPlayEnabled ?? this.autoPlayEnabled,
      audioSpeed: audioSpeed ?? this.audioSpeed,
      appVersion: appVersion ?? this.appVersion,
      profileAccountId: clearProfileAccountId
          ? null
          : (profileAccountId ?? this.profileAccountId),
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
    );
  }

  static DateTime? _readOptionalDateTime(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.parse(value).toUtc();
  }
}

/// ---------------------------------------------------------------------------
/// SettingsRepository — merges local store into a clean read/write API.
/// ---------------------------------------------------------------------------

class SettingsRepository {
  SettingsRepository({required SettingsLocalDataSource localDataSource})
    : _localDataSource = localDataSource;

  final SettingsLocalDataSource _localDataSource;

  /// Reads the persisted settings, falling back to defaults on first launch.
  Future<SettingsSnapshot> readSettings() async {
    try {
      final raw = await _localDataSource.readSnapshotJson();
      if (raw == null || raw.trim().isEmpty) {
        return const SettingsSnapshot();
      }
      return SettingsSnapshot.fromJsonString(raw);
    } on FormatException {
      // Corrupted data — reset to defaults.
      await _localDataSource.deleteSnapshotIfExists();
      return const SettingsSnapshot();
    } catch (error) {
      throw SettingsPersistenceException('读取设置失败。', error);
    }
  }

  /// Persists the full settings snapshot and returns the updated version.
  Future<SettingsSnapshot> writeSettings(SettingsSnapshot snapshot) async {
    final now = DateTime.now().toUtc();
    final updated = snapshot.copyWith(lastModifiedAt: now);
    await _localDataSource.writeSnapshotJson(
      updated.toJsonString(),
      version: settingsSchemaVersion,
    );
    return updated;
  }

  /// Partial update: reads the current settings, applies [updater], and writes
  /// back. Returns the updated snapshot.
  Future<SettingsSnapshot> updateSettings(
    SettingsSnapshot Function(SettingsSnapshot current) updater,
  ) async {
    final current = await readSettings();
    final updated = updater(current);
    return writeSettings(updated);
  }

  /// Deletes all persisted settings, returning to factory defaults.
  Future<void> clearSettings() async {
    await _localDataSource.deleteSnapshotIfExists();
  }
}
