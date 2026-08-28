import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_profile_context_resolver.dart';
import 'package:mobile/features/settings/data/repositories/baby_profile_repository.dart';
import 'package:mobile/features/settings/data/repositories/settings_repository.dart';

void main() {
  test(
    'uses saved account profile without legacy onboarding snapshot',
    () async {
      final resolver = CustomSceneProfileContextResolver(
        settingsRepository: _SettingsRepository(),
        babyProfileRepository: _BabyProfileRepository(),
      );

      final context = await resolver.resolve();

      expect(context.babyProfileId, 'babyprof_1');
      expect(context.ageRange, 'm7_11');
      expect(context.parentGoal, 'natural_opening');
      expect(context.locale, 'zh-CN');
    },
  );

  test(
    'unsupported settings locale is not reported as a missing profile',
    () async {
      final resolver = CustomSceneProfileContextResolver(
        settingsRepository: _SettingsRepository(preferredLanguage: 'en'),
        babyProfileRepository: _BabyProfileRepository(),
      );

      await expectLater(
        resolver.resolve(),
        throwsA(
          isA<CustomSceneProfileContextException>().having(
            (error) => error.kind,
            'kind',
            CustomSceneProfileContextFailureKind.malformed,
          ),
        ),
      );
    },
  );

  test(
    'settings persistence failure is not reported as a missing profile',
    () async {
      final resolver = CustomSceneProfileContextResolver(
        settingsRepository: _FailingSettingsRepository(),
        babyProfileRepository: _BabyProfileRepository(),
      );

      await expectLater(
        resolver.resolve(),
        throwsA(
          isA<CustomSceneProfileContextException>().having(
            (error) => error.kind,
            'kind',
            CustomSceneProfileContextFailureKind.unavailable,
          ),
        ),
      );
    },
  );
}

class _BabyProfileRepository extends Fake implements BabyProfileRepository {
  @override
  Future<BabyProfileProjection?> load() async => BabyProfileProjection(
    accountId: 'account_1',
    babyProfileId: 'babyprof_1',
    babyName: '宝宝',
    ageRange: 'm7_11',
    parentGoal: null,
    onboardingState: 'draft',
    onboardingCompletedAt: null,
    version: 1,
    createdAt: DateTime.utc(2026, 8, 25),
    updatedAt: DateTime.utc(2026, 8, 25),
  );
}

class _SettingsRepository extends Fake implements SettingsRepository {
  _SettingsRepository({this.preferredLanguage = 'zh-CN'});

  final String preferredLanguage;

  @override
  Future<SettingsSnapshot> readSettings() async => const SettingsSnapshot(
    preferredLanguage: 'zh-CN',
  ).copyWith(preferredLanguage: preferredLanguage);
}

class _FailingSettingsRepository extends Fake implements SettingsRepository {
  @override
  Future<SettingsSnapshot> readSettings() async {
    throw StateError('settings store unavailable');
  }
}
