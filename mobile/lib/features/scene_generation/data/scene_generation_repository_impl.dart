import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/scene_generation/data/scene_generation_api.dart';
import 'package:mobile/features/scene_generation/data/scene_generation_dtos.dart';
import 'package:mobile/features/scene_generation/data/scene_generation_mapper.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_failure.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_repository.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';

typedef SceneGenerationAccountSnapshotLoader =
    Future<AccountLocalSnapshot> Function();
typedef SceneGenerationLocaleLoader = Future<String> Function();
typedef SceneGenerationInstallationIdLoader = Future<String> Function();

class SceneGenerationRepositoryImpl implements SceneGenerationRepository {
  SceneGenerationRepositoryImpl({
    required SceneGenerationApiGateway api,
    SceneGenerationMapper mapper = const SceneGenerationMapper(),
    required SceneGenerationAccountSnapshotLoader accountSnapshotLoader,
    required PersistRefreshedSession persistRefreshedSession,
    required SceneGenerationLocaleLoader localeLoader,
    required SceneGenerationInstallationIdLoader installationIdLoader,
  }) : _api = api,
       _mapper = mapper,
       _accountSnapshotLoader = accountSnapshotLoader,
       _persistRefreshedSession = persistRefreshedSession,
       _localeLoader = localeLoader,
       _installationIdLoader = installationIdLoader;

  final SceneGenerationApiGateway _api;
  final SceneGenerationMapper _mapper;
  final SceneGenerationAccountSnapshotLoader _accountSnapshotLoader;
  final PersistRefreshedSession _persistRefreshedSession;
  final SceneGenerationLocaleLoader _localeLoader;
  final SceneGenerationInstallationIdLoader _installationIdLoader;

  @override
  Future<GeneratedCareMoment> generate({
    required SceneGenerationSource source,
    required String clientRequestId,
  }) async {
    _validateClientRequest(source, clientRequestId);
    final session = await _loadAcceptedSession();
    final requestLocale = await _loadLocale();
    final installationId = await _loadInstallationId();
    final request = SceneGenerationRequestDto(
      source: source,
      locale: requestLocale,
      installationId: installationId,
      clientRequestId: clientRequestId,
    );

    try {
      final response = await _api.generate(
        session: session,
        persistRefreshedSession: _persistRefreshedSession,
        request: request,
      );
      try {
        return _mapper.toGeneratedCareMoment(response, expectedSource: source);
      } on SceneGenerationMappingException {
        throw const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.malformedResponse,
          retryable: false,
        );
      } on ArgumentError {
        throw const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.malformedResponse,
          retryable: false,
        );
      } on FormatException {
        throw const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.malformedResponse,
          retryable: false,
        );
      } on Object {
        throw const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.malformedResponse,
          retryable: false,
        );
      }
    } on SceneGenerationFailure {
      rethrow;
    } on SceneGenerationApiException catch (error) {
      throw _mapApiFailure(error);
    } on AuthenticatedApiClientException catch (error) {
      throw _mapAuthenticatedFailure(error);
    } on Object {
      throw const SceneGenerationFailure(
        kind: SceneGenerationFailureKind.unexpected,
        retryable: false,
      );
    }
  }

  Future<AccountSession> _loadAcceptedSession() async {
    try {
      final snapshot = await _accountSnapshotLoader();
      if (snapshot.consentState != AccountConsentState.acceptedPendingSync) {
        throw const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.authenticationRequired,
          retryable: false,
        );
      }
      final session = snapshot.session;
      if (session == null || !session.hasJwtTokens) {
        throw const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.authenticationRequired,
          retryable: false,
        );
      }
      return session;
    } on SceneGenerationFailure {
      rethrow;
    } on Object {
      throw const SceneGenerationFailure(
        kind: SceneGenerationFailureKind.authenticationRequired,
        retryable: false,
      );
    }
  }

  Future<String> _loadLocale() async {
    try {
      final normalized = (await _localeLoader()).trim();
      if (normalized.isEmpty) {
        throw const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.invalidInput,
          retryable: false,
        );
      }
      return normalized;
    } on SceneGenerationFailure {
      rethrow;
    } on Object {
      throw const SceneGenerationFailure(
        kind: SceneGenerationFailureKind.unexpected,
        retryable: false,
      );
    }
  }

  Future<String> _loadInstallationId() async {
    try {
      final normalized = (await _installationIdLoader()).trim();
      if (!isBackendCompatibleInstallationId(normalized)) {
        throw const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.invalidInput,
          retryable: false,
        );
      }
      return normalized;
    } on SceneGenerationFailure {
      rethrow;
    } on Object {
      throw const SceneGenerationFailure(
        kind: SceneGenerationFailureKind.unexpected,
        retryable: false,
      );
    }
  }

  void _validateClientRequest(
    SceneGenerationSource source,
    String clientRequestId,
  ) {
    final validRequestId = RegExp(
      r'^[A-Za-z0-9][A-Za-z0-9_-]{0,95}$',
    ).hasMatch(clientRequestId);
    if (!validRequestId || RegExp(r'[0-9]{11,}').hasMatch(clientRequestId)) {
      throw const SceneGenerationFailure(
        kind: SceneGenerationFailureKind.invalidInput,
        retryable: false,
      );
    }
    switch (source) {
      case CustomSceneGenerationSource(:final text):
        if (text.trim().isEmpty) {
          throw const SceneGenerationFailure(
            kind: SceneGenerationFailureKind.invalidInput,
            retryable: false,
          );
        }
      case PresetSceneGenerationSource(:final presetSceneId):
        if (presetSceneId.trim().isEmpty) {
          throw const SceneGenerationFailure(
            kind: SceneGenerationFailureKind.invalidInput,
            retryable: false,
          );
        }
    }
  }

  SceneGenerationFailure _mapApiFailure(SceneGenerationApiException error) {
    switch (error.kind) {
      case SceneGenerationApiFailureKind.network:
        return _failure(
          SceneGenerationFailureKind.network,
          retryable: true,
          error: error,
        );
      case SceneGenerationApiFailureKind.timeout:
        return _failure(
          SceneGenerationFailureKind.timeout,
          retryable: true,
          error: error,
        );
      case SceneGenerationApiFailureKind.malformed:
        return _failure(
          SceneGenerationFailureKind.malformedResponse,
          error: error,
        );
      case SceneGenerationApiFailureKind.unexpected:
        return _failure(
          SceneGenerationFailureKind.unexpected,
          retryable: error.retryable,
          error: error,
        );
      case SceneGenerationApiFailureKind.http:
        return _mapHttpFailure(error);
    }
  }

  SceneGenerationFailure _mapHttpFailure(SceneGenerationApiException error) {
    switch (error.code) {
      case 'consumer_authentication_required':
      case 'consumer_session_invalid':
      case 'invalid_session':
      case 'consent_required':
      case 'consent_revoked':
      case 'account_deleted':
        return _failure(
          SceneGenerationFailureKind.authenticationRequired,
          error: error,
        );
      case 'profile_unavailable':
      case 'onboarding_profile_not_found':
      case 'completed_profile_missing_starter':
        return _failure(
          SceneGenerationFailureKind.profileUnavailable,
          error: error,
        );
      case 'shared_profile_unavailable':
        return _failure(
          SceneGenerationFailureKind.sharedProfileUnavailable,
          error: error,
        );
      case 'household_access_required':
        return _failure(
          SceneGenerationFailureKind.householdAccessRequired,
          error: error,
        );
      case 'preset_scene_unavailable':
        return _failure(
          SceneGenerationFailureKind.presetSceneUnavailable,
          error: error,
        );
      case 'invalid_scene_source':
      case 'invalid_custom_scene_text':
      case 'unsafe_custom_scene_text':
      case 'invalid_scene_input':
      case 'validation_failed':
      case 'unsupported_locale':
      case 'invalid_client_request_id':
      case 'invalid_installation_id':
      case 'invalid_age_range':
      case 'invalid_parent_goal':
      case 'profile_context_mismatch':
        return _failure(SceneGenerationFailureKind.invalidInput, error: error);
      case 'client_request_id_conflict':
        return _failure(
          SceneGenerationFailureKind.requestConflict,
          error: error,
        );
      case 'client_request_terminal':
        return _failure(
          SceneGenerationFailureKind.requestTerminal,
          retryable: error.retryable,
          error: error,
        );
      case 'generation_in_progress':
        return _failure(
          SceneGenerationFailureKind.generationInProgress,
          retryable: error.retryable,
          error: error,
        );
      case 'custom_scene_rate_limited':
      case 'generation_rate_limited':
      case 'scene_generation_rate_limited':
      case 'rate_limited':
        return _failure(
          SceneGenerationFailureKind.rateLimited,
          retryable: true,
          error: error,
        );
      case 'generation_timeout':
        return _failure(
          SceneGenerationFailureKind.timeout,
          retryable: error.retryable,
          error: error,
        );
      case 'generated_content_rejected':
      case 'generation_invalid_output':
      case 'unsupported_custom_scene_text':
        return _failure(SceneGenerationFailureKind.rejected, error: error);
      case 'app_version_required':
      case 'app_version_unsupported':
        return _failure(
          SceneGenerationFailureKind.unavailable,
          retryable: false,
          error: error,
        );
      case 'invalid_app_version':
        return _failure(SceneGenerationFailureKind.invalidInput, error: error);
      case 'generation_unavailable':
        return _failure(
          SceneGenerationFailureKind.unavailable,
          retryable: error.retryable,
          error: error,
        );
      default:
        if (error.statusCode == 408 || error.statusCode == 504) {
          return _failure(
            SceneGenerationFailureKind.timeout,
            retryable: true,
            error: error,
          );
        }
        if (error.statusCode == 429) {
          return _failure(
            SceneGenerationFailureKind.rateLimited,
            retryable: true,
            error: error,
          );
        }
        if ((error.statusCode ?? 0) >= 500) {
          return _failure(
            SceneGenerationFailureKind.unavailable,
            retryable: error.retryable || (error.statusCode ?? 0) >= 500,
            error: error,
          );
        }
        return _failure(
          SceneGenerationFailureKind.unexpected,
          retryable: error.retryable,
          error: error,
        );
    }
  }

  SceneGenerationFailure _mapAuthenticatedFailure(
    AuthenticatedApiClientException error,
  ) {
    switch (error.kind) {
      case AuthenticatedApiClientFailureKind.missingCredentials:
      case AuthenticatedApiClientFailureKind.sessionExpired:
        return const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.authenticationRequired,
          retryable: false,
        );
      case AuthenticatedApiClientFailureKind.refreshNetwork:
        return const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.network,
          retryable: true,
        );
      case AuthenticatedApiClientFailureKind.refreshTimeout:
        return const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.timeout,
          retryable: true,
        );
      case AuthenticatedApiClientFailureKind.refreshMalformed:
        return const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.malformedResponse,
          retryable: false,
        );
      case AuthenticatedApiClientFailureKind.refreshFailed:
      case AuthenticatedApiClientFailureKind.persistenceFailure:
        return const SceneGenerationFailure(
          kind: SceneGenerationFailureKind.unexpected,
          retryable: false,
        );
    }
  }

  SceneGenerationFailure _failure(
    SceneGenerationFailureKind kind, {
    bool retryable = false,
    SceneGenerationApiException? error,
  }) {
    return SceneGenerationFailure(
      kind: kind,
      retryable: retryable,
      generatedContentId: error?.generatedContentId,
      requiresNewClientRequestId: error?.requiresNewClientRequestId ?? false,
    );
  }
}
