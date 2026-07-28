import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/settings/data/repositories/settings_repository.dart';

/// ---------------------------------------------------------------------------
/// SettingsNotifier — ChangeNotifier that manages application settings state.
///
/// Follows the project `initialize() → snapshot → notifyListeners()` pattern
/// (mirrors OnboardingNotifier / AccountNotifier).
/// ---------------------------------------------------------------------------

enum SettingsLoadStatus { idle, loading, ready, error }

enum SettingsSaveStatus { idle, saving, success, error }

class SettingsNotifier extends ChangeNotifier {
  SettingsNotifier({required SettingsRepository repository})
    : _repository = repository;

  final SettingsRepository _repository;

  bool _initialized = false;
  bool _disposed = false;
  SettingsLoadStatus _loadStatus = SettingsLoadStatus.idle;
  SettingsSaveStatus _saveStatus = SettingsSaveStatus.idle;
  SettingsSnapshot _snapshot = const SettingsSnapshot();
  String? _errorMessage;

  // --- Getters ---

  SettingsLoadStatus get loadStatus => _loadStatus;
  SettingsSaveStatus get saveStatus => _saveStatus;
  SettingsSnapshot get snapshot => _snapshot;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _loadStatus == SettingsLoadStatus.loading;
  bool get isSaving => _saveStatus == SettingsSaveStatus.saving;
  bool get hasError => _loadStatus == SettingsLoadStatus.error;

  // --- Convenience getters for common settings ---

  bool get reminderEnabled => _snapshot.reminderEnabled;
  int get reminderHour => _snapshot.reminderHour;
  int get reminderMinute => _snapshot.reminderMinute;
  String get childName => _snapshot.childName;
  DateTime? get childBirthDate => _snapshot.childBirthDate;
  int? get childAgeMonths => _snapshot.childAgeMonths;
  String get childStage => _snapshot.childStage;
  String get caregiverRole => _snapshot.caregiverRole;
  String get preferredLanguage => _snapshot.preferredLanguage;
  bool get autoPlayEnabled => _snapshot.autoPlayEnabled;
  double get audioSpeed => _snapshot.audioSpeed;
  String get appVersion => _snapshot.appVersion;

  /// Initialises by loading persisted settings from the local store.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadSettings();
  }

  /// Reloads settings from disk (e.g. after returning from a sub-page).
  Future<void> refresh() => _loadSettings();

  // --- Update methods ---

  /// Updates the reminder schedule.
  Future<void> updateReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await _update(
      (s) => s.copyWith(
        reminderEnabled: enabled,
        reminderHour: hour,
        reminderMinute: minute,
      ),
    );
  }

  /// Updates baby profile fields.
  Future<void> updateBabyProfile({
    String? name,
    DateTime? birthDate,
    bool clearBirthDate = false,
    int? ageMonths,
    String? stage,
  }) async {
    await _update(
      (s) => s.copyWith(
        childName: name,
        childBirthDate: birthDate,
        clearChildBirthDate: clearBirthDate,
        childAgeMonths: ageMonths,
        childStage: stage,
      ),
    );
  }

  /// Updates caregiver preferences.
  Future<void> updateCaregiverPreferences({
    String? role,
    String? language,
  }) async {
    await _update(
      (s) => s.copyWith(caregiverRole: role, preferredLanguage: language),
    );
  }

  /// Updates playback preferences.
  Future<void> updatePlaybackPreferences({
    bool? autoPlay,
    double? speed,
  }) async {
    await _update(
      (s) => s.copyWith(autoPlayEnabled: autoPlay, audioSpeed: speed),
    );
  }

  /// Resets all settings to factory defaults.
  Future<void> resetToDefaults() async {
    await _update((_) => const SettingsSnapshot());
  }

  // --- Internal helpers ---

  Future<void> _loadSettings() async {
    if (_loadStatus == SettingsLoadStatus.loading) return;

    _loadStatus = SettingsLoadStatus.loading;
    _errorMessage = null;
    _notifySafely();

    try {
      _snapshot = await _repository.readSettings();
      _loadStatus = SettingsLoadStatus.ready;
      _notifySafely();
    } catch (error) {
      _loadStatus = SettingsLoadStatus.error;
      _errorMessage = '加载设置失败：${_stripErrorPrefix(error)}';
      _notifySafely();
    }
  }

  Future<void> _update(
    SettingsSnapshot Function(SettingsSnapshot current) updater,
  ) async {
    if (_saveStatus == SettingsSaveStatus.saving) return;

    _saveStatus = SettingsSaveStatus.saving;
    _errorMessage = null;
    _notifySafely();

    try {
      _snapshot = await _repository.updateSettings(updater);
      _saveStatus = SettingsSaveStatus.success;
      _errorMessage = null;
      _notifySafely();
    } catch (error) {
      _saveStatus = SettingsSaveStatus.error;
      _errorMessage = '保存设置失败：${_stripErrorPrefix(error)}';
      _notifySafely();
    }
  }

  String _stripErrorPrefix(Object error) {
    final raw = error.toString().trim();
    return raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('FormatException: ', '')
        .replaceFirst('SettingsPersistenceException: ', '')
        .trim();
  }

  void _notifySafely() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
