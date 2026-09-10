import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/settings/data/repositories/baby_profile_repository.dart';
import 'package:mobile/features/settings/data/repositories/settings_repository.dart';
import 'package:mobile/features/settings/presentation/settings_notifier.dart';

void main() {
  test(
    'signed-in profile bootstrap projects the server name and age',
    () async {
      final remote = _FakeBabyProfileRepository(
        accountId: 'acct_a',
        profile: _profile(accountId: 'acct_a', name: '小满', ageRange: 'm7_11'),
      );
      final notifier = SettingsNotifier(
        repository: _FakeSettingsRepository(
          initialSnapshot: const SettingsSnapshot(childName: '旧设备宝宝'),
        ),
        babyProfileRepository: remote,
      );

      await notifier.initialize();

      expect(notifier.childName, '小满');
      expect(notifier.childAgeMonths, 6);
      expect(notifier.snapshot.profileAccountId, 'acct_a');
    },
  );

  test(
    'signed-in profile edit saves remotely before updating local projection',
    () async {
      final remote = _FakeBabyProfileRepository(
        accountId: 'acct_a',
        profile: _profile(accountId: 'acct_a', name: '小满', ageRange: 'm7_11'),
      );
      final notifier = SettingsNotifier(
        repository: _FakeSettingsRepository(),
        babyProfileRepository: remote,
      );
      await notifier.initialize();

      await notifier.updateBabyProfile(name: '小满二号', ageMonths: 12);

      expect(remote.savedName, '小满二号');
      expect(remote.savedExpectedVersion, 2);
      expect(notifier.childName, '小满二号');
      expect(notifier.childAgeMonths, 12);
      expect(notifier.saveStatus, SettingsSaveStatus.success);
    },
  );

  test('profile projection is scoped to the active account', () async {
    final remote = _FakeBabyProfileRepository(
      accountId: 'acct_b',
      profile: _profile(accountId: 'acct_b', name: '小乙', ageRange: 'm12_17'),
    );
    final notifier = SettingsNotifier(
      repository: _FakeSettingsRepository(
        initialSnapshot: const SettingsSnapshot(
          childName: '小甲',
          childAgeMonths: 0,
          profileAccountId: 'acct_a',
        ),
      ),
      babyProfileRepository: remote,
    );

    await notifier.initialize();

    expect(notifier.childName, '小乙');
    expect(notifier.childAgeMonths, 12);
    expect(notifier.snapshot.profileAccountId, 'acct_b');
  });
}

BabyProfileProjection _profile({
  required String accountId,
  required String name,
  required String ageRange,
  int version = 2,
}) {
  final now = DateTime.utc(2026, 8, 20);
  return BabyProfileProjection(
    accountId: accountId,
    babyProfileId: 'profile_$accountId',
    babyName: name,
    ageRange: ageRange,
    parentGoal: null,
    onboardingState: 'draft',
    onboardingCompletedAt: null,
    version: version,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeBabyProfileRepository extends Fake implements BabyProfileRepository {
  _FakeBabyProfileRepository({required this.accountId, required this.profile});

  final String accountId;
  BabyProfileProjection profile;
  String? savedName;
  int? savedExpectedVersion;

  @override
  Future<String?> currentAccountId() async => accountId;

  @override
  Future<BabyProfileProjection?> load() async => profile;

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
    savedName = babyName;
    savedExpectedVersion = expectedVersion;
    profile = BabyProfileProjection(
      accountId: accountId,
      babyProfileId: profile.babyProfileId,
      babyName: babyName,
      ageRange: ageRange,
      parentGoal: parentGoal,
      onboardingState: onboardingState,
      onboardingCompletedAt: completedAt,
      version: (expectedVersion ?? profile.version) + 1,
      createdAt: profile.createdAt,
      updatedAt: DateTime.utc(2026, 8, 21),
    );
    return profile;
  }
}

class _FakeSettingsRepository extends Fake implements SettingsRepository {
  _FakeSettingsRepository({SettingsSnapshot? initialSnapshot})
    : _snapshot = initialSnapshot ?? const SettingsSnapshot();

  SettingsSnapshot _snapshot;

  @override
  Future<SettingsSnapshot> readSettings() async => _snapshot;

  @override
  Future<SettingsSnapshot> updateSettings(
    SettingsSnapshot Function(SettingsSnapshot current) updater,
  ) async {
    _snapshot = updater(_snapshot);
    return _snapshot;
  }

  @override
  Future<SettingsSnapshot> writeSettings(SettingsSnapshot snapshot) async {
    _snapshot = snapshot;
    return snapshot;
  }
}
