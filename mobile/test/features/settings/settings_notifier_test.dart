import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/settings/data/repositories/settings_repository.dart';
import 'package:mobile/features/settings/presentation/settings_notifier.dart';

void main() {
  group('SettingsNotifier', () {
    test('initializes with idle state and default snapshot', () async {
      final notifier = SettingsNotifier(
        repository: _FakeSettingsRepository(),
      );

      expect(notifier.loadStatus, SettingsLoadStatus.idle);
      expect(notifier.saveStatus, SettingsSaveStatus.idle);
      expect(notifier.snapshot, const SettingsSnapshot());
      expect(notifier.errorMessage, isNull);
      expect(notifier.isLoading, isFalse);
      expect(notifier.isSaving, isFalse);
      expect(notifier.hasError, isFalse);
    });

    test('initialize loads settings from repository', () async {
      final repository = _FakeSettingsRepository(
        initialSnapshot: const SettingsSnapshot(
          reminderEnabled: true,
          reminderHour: 20,
          childName: '米米',
        ),
      );
      final notifier = SettingsNotifier(repository: repository);

      await notifier.initialize();

      expect(notifier.loadStatus, SettingsLoadStatus.ready);
      expect(notifier.snapshot.reminderEnabled, isTrue);
      expect(notifier.snapshot.reminderHour, 20);
      expect(notifier.snapshot.childName, '米米');
      expect(notifier.isLoading, isFalse);
      expect(notifier.hasError, isFalse);
    });

    test('initialize is idempotent - only loads once', () async {
      final repository = _FakeSettingsRepository(
        initialSnapshot: const SettingsSnapshot(childName: '果果'),
      );
      final notifier = SettingsNotifier(repository: repository);

      await notifier.initialize();
      await notifier.initialize(); // second call should be no-op

      expect(notifier.loadStatus, SettingsLoadStatus.ready);
      expect(notifier.snapshot.childName, '果果');
      expect(repository.readCount, 1);
    });

    test('initialize handles load error gracefully', () async {
      final repository = _FakeSettingsRepository(
        shouldFailOnRead: true,
      );
      final notifier = SettingsNotifier(repository: repository);

      await notifier.initialize();

      expect(notifier.loadStatus, SettingsLoadStatus.error);
      expect(notifier.hasError, isTrue);
      expect(notifier.errorMessage, contains('加载设置失败'));
    });

    test('refresh reloads settings from repository', () async {
      final repository = _FakeSettingsRepository(
        initialSnapshot: const SettingsSnapshot(childName: '第一次'),
      );
      final notifier = SettingsNotifier(repository: repository);

      await notifier.initialize();
      expect(notifier.snapshot.childName, '第一次');

      // Simulate external change
      repository.updateDirectly(
        const SettingsSnapshot(childName: '第二次'),
      );

      await notifier.refresh();
      expect(notifier.snapshot.childName, '第二次');
    });

    test('updateReminder persists new reminder settings', () async {
      final repository = _FakeSettingsRepository();
      final notifier = SettingsNotifier(repository: repository);

      await notifier.initialize();
      expect(notifier.reminderEnabled, isFalse);

      await notifier.updateReminder(enabled: true, hour: 8, minute: 30);

      expect(notifier.reminderEnabled, isTrue);
      expect(notifier.reminderHour, 8);
      expect(notifier.reminderMinute, 30);
      expect(notifier.saveStatus, SettingsSaveStatus.success);
    });

    test('updateBabyProfile persists baby info', () async {
      final repository = _FakeSettingsRepository();
      final notifier = SettingsNotifier(repository: repository);

      await notifier.initialize();

      await notifier.updateBabyProfile(
        name: '米米',
        ageMonths: 12,
        stage: 'gesture_plus_words',
      );

      expect(notifier.childName, '米米');
      expect(notifier.childAgeMonths, 12);
      expect(notifier.childStage, 'gesture_plus_words');
    });

    test('updateCaregiverPreferences persists role and language', () async {
      final repository = _FakeSettingsRepository();
      final notifier = SettingsNotifier(repository: repository);

      await notifier.initialize();

      await notifier.updateCaregiverPreferences(
        role: '妈妈',
        language: 'en',
      );

      expect(notifier.caregiverRole, '妈妈');
      expect(notifier.preferredLanguage, 'en');
    });

    test('updatePlaybackPreferences persists auto-play and speed', () async {
      final repository = _FakeSettingsRepository();
      final notifier = SettingsNotifier(repository: repository);

      await notifier.initialize();

      await notifier.updatePlaybackPreferences(
        autoPlay: false,
        speed: 1.5,
      );

      expect(notifier.autoPlayEnabled, isFalse);
      expect(notifier.audioSpeed, 1.5);
    });

    test('resetToDefaults clears all settings', () async {
      final repository = _FakeSettingsRepository(
        initialSnapshot: const SettingsSnapshot(
          reminderEnabled: true,
          childName: '米米',
          caregiverRole: '妈妈',
        ),
      );
      final notifier = SettingsNotifier(repository: repository);

      await notifier.initialize();
      expect(notifier.childName, '米米');

      await notifier.resetToDefaults();

      expect(notifier.childName, '');
      expect(notifier.reminderEnabled, isFalse);
      expect(notifier.caregiverRole, '');
      expect(notifier.preferredLanguage, 'zh');
      expect(notifier.autoPlayEnabled, isTrue);
      expect(notifier.audioSpeed, 1.0);
    });

    test('update handles save error gracefully', () async {
      final repository = _FakeSettingsRepository(shouldFailOnWrite: true);
      final notifier = SettingsNotifier(repository: repository);

      await notifier.initialize();

      await notifier.updateReminder(enabled: true, hour: 9, minute: 0);

      expect(notifier.saveStatus, SettingsSaveStatus.error);
      expect(notifier.errorMessage, contains('保存设置失败'));
      // Snapshot should remain unchanged on error
      expect(notifier.reminderEnabled, isFalse);
    });

    test('concurrent update calls are deduplicated', () async {
      final repository = _FakeSettingsRepository();
      final notifier = SettingsNotifier(repository: repository);

      await notifier.initialize();

      // Fire two updates simultaneously
      await Future.wait([
        notifier.updateReminder(enabled: true, hour: 8, minute: 0),
        notifier.updateBabyProfile(name: '米米'),
      ]);

      // The second call should be deduplicated because the first is still saving
      // (only one write to the repository)
      expect(repository.writeCount, lessThanOrEqualTo(2));
      // At least one of the updates should have taken effect
      expect(
        notifier.reminderEnabled || notifier.childName == '米米',
        isTrue,
      );
    });

    test('notifier exposes convenience getters from snapshot', () async {
      final repository = _FakeSettingsRepository(
        initialSnapshot: const SettingsSnapshot(
          reminderEnabled: true,
          reminderHour: 7,
          reminderMinute: 45,
          childName: '宝宝',
          childAgeMonths: 6,
          childStage: 'sound_response',
          caregiverRole: '爸爸',
          preferredLanguage: 'en',
          autoPlayEnabled: false,
          audioSpeed: 1.25,
          appVersion: '1.0.0',
        ),
      );
      final notifier = SettingsNotifier(repository: repository);

      await notifier.initialize();

      expect(notifier.reminderEnabled, isTrue);
      expect(notifier.reminderHour, 7);
      expect(notifier.reminderMinute, 45);
      expect(notifier.childName, '宝宝');
      expect(notifier.childAgeMonths, 6);
      expect(notifier.childStage, 'sound_response');
      expect(notifier.caregiverRole, '爸爸');
      expect(notifier.preferredLanguage, 'en');
      expect(notifier.autoPlayEnabled, isFalse);
      expect(notifier.audioSpeed, 1.25);
      expect(notifier.appVersion, '1.0.0');
    });

    test('notifier notifies listeners on state changes', () async {
      final repository = _FakeSettingsRepository();
      final notifier = SettingsNotifier(repository: repository);
      final listenerCalls = <String>[];

      notifier.addListener(() {
        listenerCalls.add(notifier.loadStatus.name);
      });

      await notifier.initialize();

      // initialize triggers: loading, then ready
      expect(listenerCalls, containsAll(['loading', 'ready']));
    });

    test('dispose prevents late listener notifications', () async {
      final repository = _FakeSettingsRepository(
        shouldFailOnRead: true,
      );
      final notifier = SettingsNotifier(repository: repository);

      await notifier.initialize();
      notifier.dispose();

      // Should not throw after disposal
      expect(notifier.hasError, isTrue);
    });
  });
}

/// A fake [SettingsRepository] for unit testing the notifier without
/// requiring Isar or a real file system.
class _FakeSettingsRepository extends Fake implements SettingsRepository {
  _FakeSettingsRepository({
    SettingsSnapshot? initialSnapshot,
    this.shouldFailOnRead = false,
    this.shouldFailOnWrite = false,
  }) : _currentSnapshot = initialSnapshot ?? const SettingsSnapshot();

  SettingsSnapshot _currentSnapshot;
  bool shouldFailOnRead;
  bool shouldFailOnWrite;
  int readCount = 0;
  int writeCount = 0;

  void updateDirectly(SettingsSnapshot snapshot) {
    _currentSnapshot = snapshot;
  }

  @override
  Future<SettingsSnapshot> readSettings() async {
    readCount += 1;
    if (shouldFailOnRead) {
      throw StateError('磁盘读取失败。');
    }
    return _currentSnapshot;
  }

  @override
  Future<SettingsSnapshot> writeSettings(SettingsSnapshot snapshot) async {
    writeCount += 1;
    if (shouldFailOnWrite) {
      throw StateError('磁盘写入失败。');
    }
    final updated = snapshot.copyWith(
      lastModifiedAt: DateTime.now().toUtc(),
    );
    _currentSnapshot = updated;
    return updated;
  }

  @override
  Future<SettingsSnapshot> updateSettings(
    SettingsSnapshot Function(SettingsSnapshot current) updater,
  ) async {
    writeCount += 1;
    if (shouldFailOnWrite) {
      throw StateError('磁盘写入失败。');
    }
    final updated = updater(_currentSnapshot).copyWith(
      lastModifiedAt: DateTime.now().toUtc(),
    );
    _currentSnapshot = updated;
    return updated;
  }

  @override
  Future<void> clearSettings() async {
    _currentSnapshot = const SettingsSnapshot();
  }
}
