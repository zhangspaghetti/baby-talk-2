import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/settings/data/repositories/baby_profile_repository.dart';
import 'package:mobile/features/settings/data/repositories/settings_repository.dart';
import 'package:mobile/features/settings/data/reminder_scheduler.dart';

/// ---------------------------------------------------------------------------
/// SettingsNotifier — ChangeNotifier that manages application settings state.
///
/// Follows the project `initialize() → snapshot → notifyListeners()` pattern
/// (mirrors OnboardingNotifier / AccountNotifier).
/// ---------------------------------------------------------------------------

enum SettingsLoadStatus { idle, loading, ready, error }

enum SettingsSaveStatus { idle, saving, success, error }

class SettingsNotifier extends ChangeNotifier {
  SettingsNotifier({
    required SettingsRepository repository,
    ReminderScheduler? reminderScheduler,
    BabyProfileRepository? babyProfileRepository,
    Listenable? accountStateListenable,
  }) : _repository = repository,
       _reminderScheduler = reminderScheduler,
       _babyProfileRepository = babyProfileRepository,
       _accountStateListenable = accountStateListenable {
    _accountStateListenable?.addListener(_handleAccountStateChanged);
  }

  final SettingsRepository _repository;
  final ReminderScheduler? _reminderScheduler;
  final BabyProfileRepository? _babyProfileRepository;
  final Listenable? _accountStateListenable;

  bool _initialized = false;
  bool _disposed = false;
  SettingsLoadStatus _loadStatus = SettingsLoadStatus.idle;
  SettingsSaveStatus _saveStatus = SettingsSaveStatus.idle;
  SettingsSnapshot _snapshot = const SettingsSnapshot();
  BabyProfileProjection? _remoteProfile;
  bool _remoteProfileAvailable = false;
  Future<void>? _accountProfileRefresh;
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
    await refreshAccountProfile();
  }

  /// Reloads settings from disk (e.g. after returning from a sub-page).
  Future<void> refresh() => _loadSettings();

  /// Refreshes the account-backed profile and reprojects its confirmed
  /// name/age into local settings. Local settings remain an offline
  /// projection; a failed refresh never invents a remote success.
  Future<void> refreshAccountProfile() {
    final running = _accountProfileRefresh;
    if (running != null) {
      return running;
    }

    final refresh = _refreshAccountProfile();
    late final Future<void> tracked;
    tracked = refresh.whenComplete(() {
      if (identical(_accountProfileRefresh, tracked)) {
        _accountProfileRefresh = null;
      }
    });
    _accountProfileRefresh = tracked;
    return tracked;
  }

  Future<void> _refreshAccountProfile() async {
    final remote = _babyProfileRepository;
    if (remote == null) {
      return;
    }
    final accountId = await remote.currentAccountId();
    if (accountId == null) {
      _remoteProfile = null;
      _remoteProfileAvailable = false;
      return;
    }
    try {
      final profile = await remote.load();
      _remoteProfileAvailable = true;
      _remoteProfile = profile;
      if (profile == null) {
        await _projectEmptyProfile(accountId);
      } else {
        await _projectRemoteProfile(profile);
      }
    } on Object catch (error) {
      _remoteProfileAvailable = true;
      _errorMessage = '宝宝档案暂时无法从账号恢复：${_stripErrorPrefix(error)}';
      _notifySafely();
    }
  }

  // --- Update methods ---

  /// Updates the reminder schedule.
  Future<void> updateReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      _saveStatus = SettingsSaveStatus.error;
      _errorMessage = '提醒时间不合法。';
      _notifySafely();
      return;
    }

    if (_saveStatus == SettingsSaveStatus.saving) return;

    final previous = _snapshot;
    _saveStatus = SettingsSaveStatus.saving;
    _errorMessage = null;
    _notifySafely();

    SettingsSnapshot persisted;
    try {
      persisted = await _repository.updateSettings(
        (s) => s.copyWith(
          reminderEnabled: enabled,
          reminderHour: hour,
          reminderMinute: minute,
        ),
      );
      _snapshot = persisted;
    } catch (error) {
      _saveStatus = SettingsSaveStatus.error;
      _errorMessage = '保存设置失败：${_stripErrorPrefix(error)}';
      _notifySafely();
      return;
    }

    final scheduler = _reminderScheduler;
    if (scheduler != null) {
      try {
        if (!enabled) {
          await scheduler.cancel();
        } else {
          final result = await scheduler.scheduleDaily(
            hour: hour,
            minute: minute,
          );
          if (result != ReminderScheduleResult.scheduled) {
            await _rollbackReminder(previous);
            _saveStatus = SettingsSaveStatus.error;
            _errorMessage = result == ReminderScheduleResult.permissionDenied
                ? '未获得通知权限，无法开启每日提醒。'
                : '当前设备暂时无法设置每日提醒。';
            _notifySafely();
            return;
          }
        }
      } on Object {
        await _rollbackReminder(previous);
        _saveStatus = SettingsSaveStatus.error;
        _errorMessage = '当前设备暂时无法设置每日提醒。';
        _notifySafely();
        return;
      }
    }

    _saveStatus = SettingsSaveStatus.success;
    _errorMessage = null;
    _notifySafely();
  }

  /// Updates baby profile fields.
  Future<void> updateBabyProfile({
    String? name,
    DateTime? birthDate,
    bool clearBirthDate = false,
    int? ageMonths,
    String? stage,
  }) async {
    final remote = _babyProfileRepository;
    if (remote != null) {
      if (!_remoteProfileAvailable) {
        await refreshAccountProfile();
      }
      if (_remoteProfileAvailable) {
        await _updateAccountBabyProfile(
          remote,
          name: name,
          ageMonths: ageMonths,
          stage: stage,
        );
        return;
      }
    }
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

  Future<void> _updateAccountBabyProfile(
    BabyProfileRepository remote, {
    required String? name,
    required int? ageMonths,
    required String? stage,
  }) async {
    if (_saveStatus == SettingsSaveStatus.saving) {
      return;
    }
    final ageRange = _ageRangeForMonths(ageMonths) ?? _remoteProfile?.ageRange;
    if (ageRange == null) {
      _saveStatus = SettingsSaveStatus.error;
      _errorMessage = '请先选择宝宝月龄，再保存账号档案。';
      _notifySafely();
      return;
    }

    _saveStatus = SettingsSaveStatus.saving;
    _errorMessage = null;
    _notifySafely();
    try {
      final profile = await remote.save(
        expectedVersion: _remoteProfile?.version,
        babyName: name,
        ageRange: ageRange,
        onboardingState: _remoteProfile?.onboardingState ?? 'draft',
        parentGoal: _remoteProfile?.parentGoal,
        clientTraceId:
            'settings_profile_${DateTime.now().microsecondsSinceEpoch}',
      );
      _remoteProfile = profile;
      await _projectRemoteProfile(profile, stage: stage);
      _saveStatus = SettingsSaveStatus.success;
      _errorMessage = null;
      _notifySafely();
    } on Object catch (error) {
      _saveStatus = SettingsSaveStatus.error;
      _errorMessage = '保存账号宝宝档案失败：${_stripErrorPrefix(error)}';
      _notifySafely();
    }
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

  Future<void> _projectRemoteProfile(
    BabyProfileProjection profile, {
    String? stage,
  }) async {
    final existingScope = _snapshot.profileAccountId;
    _snapshot = await _repository.updateSettings(
      (current) => current.copyWith(
        childName: profile.babyName ?? '',
        childAgeMonths: _monthsForAgeRange(profile.ageRange),
        childStage:
            stage ??
            (existingScope == profile.accountId ? current.childStage : ''),
        profileAccountId: profile.accountId,
        clearChildBirthDate:
            existingScope != null && existingScope != profile.accountId,
      ),
    );
    _notifySafely();
  }

  Future<void> _projectEmptyProfile(String accountId) async {
    _snapshot = await _repository.updateSettings(
      (current) => current.copyWith(
        childName: '',
        clearChildBirthDate: true,
        clearChildAgeMonths: true,
        childStage: '',
        profileAccountId: accountId,
      ),
    );
    _notifySafely();
  }

  void _handleAccountStateChanged() {
    if (_disposed) {
      return;
    }
    unawaited(refreshAccountProfile());
  }

  String? _ageRangeForMonths(int? value) {
    if (value == null || value < 0 || value > 36) {
      return null;
    }
    if (value == 0) return 'm0_3';
    if (value <= 3) return 'm4_6';
    if (value <= 9) return 'm7_11';
    if (value <= 12) return 'm12_17';
    if (value <= 23) return 'm18_23';
    if (value <= 30) return 'm24_30';
    return 'm31_36';
  }

  int? _monthsForAgeRange(String value) {
    return switch (value) {
      'm0_3' => 0,
      'm4_6' => 3,
      'm7_11' => 6,
      'm12_17' => 12,
      'm18_23' => 18,
      'm24_30' => 24,
      'm31_36' => 31,
      _ => null,
    };
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

  /// Restores the local snapshot when the native reminder operation did not
  /// complete. The best-effort write keeps the in-memory state truthful even
  /// if the rollback write itself is unavailable.
  Future<void> _rollbackReminder(SettingsSnapshot previous) async {
    try {
      _snapshot = await _repository.writeSettings(previous);
    } catch (_) {
      _snapshot = previous;
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
    _accountStateListenable?.removeListener(_handleAccountStateChanged);
    super.dispose();
  }
}
