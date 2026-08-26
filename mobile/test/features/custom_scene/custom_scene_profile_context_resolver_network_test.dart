import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_profile_context_resolver.dart';
import 'package:mobile/features/settings/data/repositories/baby_profile_repository.dart';
import 'package:mobile/features/settings/data/repositories/settings_repository.dart';

void main() {
  test(
    'preserves remote profile network failure for custom-scene mapping',
    () async {
      final resolver = CustomSceneProfileContextResolver(
        babyProfileRepository: _FailingBabyProfileRepository(),
        settingsRepository: _SettingsRepository(),
      );

      await expectLater(
        resolver.resolve(),
        throwsA(
          isA<CustomSceneProfileContextException>().having(
            (error) => error.kind,
            'kind',
            CustomSceneProfileContextFailureKind.network,
          ),
        ),
      );
    },
  );
}

class _FailingBabyProfileRepository extends Fake
    implements BabyProfileRepository {
  @override
  Future<BabyProfileProjection?> load() async {
    throw const AccountApiException.network(message: 'QA gateway unavailable');
  }
}

class _SettingsRepository extends Fake implements SettingsRepository {
  @override
  Future<SettingsSnapshot> readSettings() async =>
      const SettingsSnapshot(preferredLanguage: 'zh-CN');
}
