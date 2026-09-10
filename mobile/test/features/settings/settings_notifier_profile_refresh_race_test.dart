import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/settings/data/repositories/baby_profile_repository.dart';
import 'package:mobile/features/settings/data/repositories/settings_repository.dart';
import 'package:mobile/features/settings/presentation/settings_notifier.dart';

void main() {
  test('initialize stops before account refresh after disposal', () async {
    final settings = _BlockingSettingsRepository();
    final remote = _DelayedBabyProfileRepository()..accountId = 'acct_1';
    final notifier = SettingsNotifier(
      repository: settings,
      babyProfileRepository: remote,
    );

    final initialization = notifier.initialize();
    await settings.readStarted.future;
    notifier.dispose();
    settings.readCompleter.complete(const SettingsSnapshot());

    await initialization;

    expect(remote.currentAccountIdCalls, 0);
  });

  test('profile edit waits for the account refresh after sign-in', () async {
    final accountState = ChangeNotifier();
    final remote = _DelayedBabyProfileRepository();
    final notifier = SettingsNotifier(
      repository: _FakeSettingsRepository(),
      babyProfileRepository: remote,
      accountStateListenable: accountState,
    );

    await notifier.initialize();

    remote.accountId = 'acct_1';
    accountState.notifyListeners();
    await remote.refreshStarted.future;

    final update = notifier.updateBabyProfile(name: '宝宝', ageMonths: 6);
    remote.loadCompleter.complete(null);
    await update;

    expect(remote.saveCalls, 1);
    expect(notifier.saveStatus, SettingsSaveStatus.success);
  });
}

class _DelayedBabyProfileRepository extends Fake
    implements BabyProfileRepository {
  String? accountId;
  int currentAccountIdCalls = 0;
  int saveCalls = 0;
  final refreshStarted = Completer<void>();
  final loadCompleter = Completer<BabyProfileProjection?>();

  @override
  Future<String?> currentAccountId() async {
    currentAccountIdCalls += 1;
    return accountId;
  }

  @override
  Future<BabyProfileProjection?> load() {
    if (!refreshStarted.isCompleted) {
      refreshStarted.complete();
    }
    return loadCompleter.future;
  }

  @override
  Future<BabyProfileProjection> save({
    required String ageRange,
    required String onboardingState,
    String? babyName,
    String? parentGoal,
    int? expectedVersion,
    DateTime? completedAt,
    String? clientTraceId,
  }) async {
    saveCalls += 1;
    final now = DateTime.utc(2026, 8, 26);
    return BabyProfileProjection(
      accountId: accountId!,
      babyProfileId: 'babyprof_1',
      babyName: babyName,
      ageRange: ageRange,
      parentGoal: parentGoal,
      onboardingState: onboardingState,
      onboardingCompletedAt: completedAt,
      version: (expectedVersion ?? 0) + 1,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _FakeSettingsRepository extends Fake implements SettingsRepository {
  SettingsSnapshot snapshot = const SettingsSnapshot();

  @override
  Future<SettingsSnapshot> readSettings() async => snapshot;

  @override
  Future<SettingsSnapshot> updateSettings(
    SettingsSnapshot Function(SettingsSnapshot current) updater,
  ) async {
    snapshot = updater(snapshot);
    return snapshot;
  }

  @override
  Future<SettingsSnapshot> writeSettings(SettingsSnapshot value) async {
    snapshot = value;
    return value;
  }
}

class _BlockingSettingsRepository extends Fake implements SettingsRepository {
  final readStarted = Completer<void>();
  final readCompleter = Completer<SettingsSnapshot>();

  @override
  Future<SettingsSnapshot> readSettings() async {
    readStarted.complete();
    return readCompleter.future;
  }
}
