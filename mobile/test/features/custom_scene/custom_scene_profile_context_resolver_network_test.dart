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
        babyProfileRepository: _FailingBabyProfileRepository(
          const AccountApiException.network(message: 'QA gateway unavailable'),
        ),
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

  test(
    'maps remote profile server failure to unavailable instead of missing',
    () async {
      final resolver = CustomSceneProfileContextResolver(
        babyProfileRepository: _FailingBabyProfileRepository(
          const AccountApiException(
            kind: AccountApiFailureKind.http,
            statusCode: 503,
            code: 'service_unavailable',
            message: 'QA gateway unavailable',
          ),
        ),
        settingsRepository: _SettingsRepository(),
      );

      await expectLater(
        resolver.resolve(),
        throwsA(
          isA<CustomSceneProfileContextException>()
              .having(
                (error) => error.kind,
                'kind',
                CustomSceneProfileContextFailureKind.unavailable,
              )
              .having((error) => error.retryable, 'retryable', isTrue),
        ),
      );
    },
  );

  test(
    'maps remote profile authentication failure to authentication',
    () async {
      final resolver = CustomSceneProfileContextResolver(
        babyProfileRepository: _FailingBabyProfileRepository(
          const AccountApiException(
            kind: AccountApiFailureKind.http,
            statusCode: 401,
            code: 'invalid_session',
            message: 'session expired',
          ),
        ),
        settingsRepository: _SettingsRepository(),
      );

      await expectLater(
        resolver.resolve(),
        throwsA(
          isA<CustomSceneProfileContextException>().having(
            (error) => error.kind,
            'kind',
            CustomSceneProfileContextFailureKind.authentication,
          ),
        ),
      );
    },
  );
}

class _FailingBabyProfileRepository extends Fake
    implements BabyProfileRepository {
  _FailingBabyProfileRepository(this.error);

  final AccountApiException error;

  @override
  Future<BabyProfileProjection?> load() async {
    throw error;
  }
}

class _SettingsRepository extends Fake implements SettingsRepository {
  @override
  Future<SettingsSnapshot> readSettings() async =>
      const SettingsSnapshot(preferredLanguage: 'zh-CN');
}
