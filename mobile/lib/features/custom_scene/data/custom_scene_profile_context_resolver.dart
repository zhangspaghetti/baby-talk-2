import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/settings/data/repositories/baby_profile_repository.dart';
import 'package:mobile/features/settings/data/repositories/settings_repository.dart';

class CustomSceneProfileContextUnavailableException implements Exception {
  const CustomSceneProfileContextUnavailableException();
}

enum CustomSceneProfileContextFailureKind {
  network,
  timeout,
  authentication,
  malformed,
  unavailable,
}

class CustomSceneProfileContextException implements Exception {
  const CustomSceneProfileContextException({
    required this.kind,
    this.retryable = false,
  });

  const CustomSceneProfileContextException.network()
    : this(kind: CustomSceneProfileContextFailureKind.network, retryable: true);

  const CustomSceneProfileContextException.timeout()
    : this(kind: CustomSceneProfileContextFailureKind.timeout, retryable: true);

  const CustomSceneProfileContextException.authentication()
    : this(kind: CustomSceneProfileContextFailureKind.authentication);

  const CustomSceneProfileContextException.malformed()
    : this(kind: CustomSceneProfileContextFailureKind.malformed);

  const CustomSceneProfileContextException.unavailable({bool retryable = false})
    : this(
        kind: CustomSceneProfileContextFailureKind.unavailable,
        retryable: retryable,
      );

  final CustomSceneProfileContextFailureKind kind;
  final bool retryable;
}

abstract interface class CustomSceneProfileContextSource {
  Future<CustomSceneProfileContext> resolve();
}

/// Resolves generation context from the saved account profile and Settings.
/// UI never supplies age, goal, locale, or backend profile IDs.
class CustomSceneProfileContextResolver
    implements CustomSceneProfileContextSource {
  CustomSceneProfileContextResolver({
    required BabyProfileRepository babyProfileRepository,
    required SettingsRepository settingsRepository,
  }) : _babyProfileRepository = babyProfileRepository,
       _settingsRepository = settingsRepository;

  static const _defaultParentGoal = 'natural_opening';

  final BabyProfileRepository _babyProfileRepository;
  final SettingsRepository _settingsRepository;

  @override
  Future<CustomSceneProfileContext> resolve() async {
    final profile = await _loadProfile();
    if (profile == null) {
      throw const CustomSceneProfileContextUnavailableException();
    }
    try {
      final settings = await _settingsRepository.readSettings();
      return CustomSceneProfileContext(
        babyProfileId: profile.babyProfileId,
        ageRange: profile.ageRange,
        parentGoal: profile.parentGoal ?? _defaultParentGoal,
        locale: _localeFor(settings.preferredLanguage),
      );
    } on CustomSceneProfileContextUnavailableException {
      rethrow;
    } on Object {
      throw const CustomSceneProfileContextUnavailableException();
    }
  }

  Future<BabyProfileProjection?> _loadProfile() async {
    try {
      return await _babyProfileRepository.load();
    } on CustomSceneProfileContextException {
      rethrow;
    } on AccountApiException catch (error) {
      throw _mapAccountApiFailure(error);
    } on AuthenticatedApiClientException catch (error) {
      throw _mapAuthenticatedApiFailure(error);
    } on Object {
      throw const CustomSceneProfileContextException.unavailable();
    }
  }

  CustomSceneProfileContextException _mapAccountApiFailure(
    AccountApiException error,
  ) {
    switch (error.kind) {
      case AccountApiFailureKind.network:
        return const CustomSceneProfileContextException.network();
      case AccountApiFailureKind.timeout:
        return const CustomSceneProfileContextException.timeout();
      case AccountApiFailureKind.malformed:
        return const CustomSceneProfileContextException.malformed();
      case AccountApiFailureKind.http:
        if (error.isUnauthorized) {
          return const CustomSceneProfileContextException.authentication();
        }
        return CustomSceneProfileContextException.unavailable(
          retryable: error.isServerFailure || error.isRetryable,
        );
    }
  }

  CustomSceneProfileContextException _mapAuthenticatedApiFailure(
    AuthenticatedApiClientException error,
  ) {
    switch (error.kind) {
      case AuthenticatedApiClientFailureKind.refreshNetwork:
        return const CustomSceneProfileContextException.network();
      case AuthenticatedApiClientFailureKind.refreshTimeout:
        return const CustomSceneProfileContextException.timeout();
      case AuthenticatedApiClientFailureKind.refreshMalformed:
        return const CustomSceneProfileContextException.malformed();
      case AuthenticatedApiClientFailureKind.missingCredentials:
      case AuthenticatedApiClientFailureKind.sessionExpired:
      case AuthenticatedApiClientFailureKind.persistenceFailure:
        return const CustomSceneProfileContextException.authentication();
      case AuthenticatedApiClientFailureKind.refreshFailed:
        return const CustomSceneProfileContextException.unavailable(
          retryable: true,
        );
    }
  }

  String _localeFor(String value) {
    switch (value.trim()) {
      case 'zh':
      case 'zh-CN':
        return 'zh-CN';
      default:
        throw const CustomSceneProfileContextUnavailableException();
    }
  }
}
