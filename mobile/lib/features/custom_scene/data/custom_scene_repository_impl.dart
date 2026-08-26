import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_api.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_dtos.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_mapper.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_profile_context_resolver.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_failure.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_repository.dart';
import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';

typedef CustomSceneAccountSnapshotLoader =
    Future<AccountLocalSnapshot> Function();
typedef CustomSceneInstallationIdLoader = Future<String> Function();

class CustomSceneRepositoryImpl implements CustomSceneRepository {
  CustomSceneRepositoryImpl({
    required CustomSceneDiscoveryGateway api,
    required CustomSceneMapper mapper,
    required CustomSceneProfileContextSource profileContextResolver,
    required CustomSceneAccountSnapshotLoader accountSnapshotLoader,
    required PersistRefreshedSession persistRefreshedSession,
    required CustomSceneInstallationIdLoader installationIdLoader,
  }) : _api = api,
       _mapper = mapper,
       _profileContextResolver = profileContextResolver,
       _accountSnapshotLoader = accountSnapshotLoader,
       _persistRefreshedSession = persistRefreshedSession,
       _installationIdLoader = installationIdLoader;

  final CustomSceneDiscoveryGateway _api;
  final CustomSceneMapper _mapper;
  final CustomSceneProfileContextSource _profileContextResolver;
  final CustomSceneAccountSnapshotLoader _accountSnapshotLoader;
  final PersistRefreshedSession _persistRefreshedSession;
  final CustomSceneInstallationIdLoader _installationIdLoader;

  @override
  Future<GeneratedCareMoment> generate(CustomSceneDraft draft) async {
    _validateClientRequestId(draft.requestIdentity.clientRequestId);
    final account = await _loadAuthenticatedAccount();
    final context = await _loadProfileContext();
    final installationId = await _loadInstallationId();
    try {
      final response = await _api.generate(
        session: account.session!,
        persistRefreshedSession: _persistRefreshedSession,
        request: CustomSceneRequestDto(
          installationId: installationId,
          babyProfileId: context.babyProfileId,
          ageRange: context.ageRange,
          parentGoal: context.parentGoal,
          locale: context.locale,
          customSceneText: draft.text,
          clientRequestId: draft.requestIdentity.clientRequestId,
        ),
      );
      try {
        return _mapper.toGeneratedCareMoment(response);
      } on CustomSceneMappingException {
        throw const CustomSceneFailure(
          kind: CustomSceneFailureKind.malformedResponse,
          retryable: false,
        );
      } on ArgumentError {
        throw const CustomSceneFailure(
          kind: CustomSceneFailureKind.malformedResponse,
          retryable: false,
        );
      }
    } on CustomSceneApiException catch (error) {
      throw _mapApiFailure(error);
    }
  }

  Future<AccountLocalSnapshot> _loadAuthenticatedAccount() async {
    try {
      final snapshot = await _accountSnapshotLoader();
      final session = snapshot.session;
      if (session == null ||
          !session.hasJwtTokens ||
          snapshot.consentState == AccountConsentState.localOnly ||
          snapshot.consentState == AccountConsentState.signedOut ||
          snapshot.consentState == AccountConsentState.revoked ||
          snapshot.consentState == AccountConsentState.deleted) {
        throw const CustomSceneFailure(
          kind: CustomSceneFailureKind.authenticationRequired,
          retryable: false,
        );
      }
      return snapshot;
    } on CustomSceneFailure {
      rethrow;
    } on Object {
      throw const CustomSceneFailure(
        kind: CustomSceneFailureKind.authenticationRequired,
        retryable: false,
      );
    }
  }

  Future<CustomSceneProfileContext> _loadProfileContext() async {
    try {
      return await _profileContextResolver.resolve();
    } on CustomSceneProfileContextUnavailableException {
      throw const CustomSceneFailure(
        kind: CustomSceneFailureKind.profileUnavailable,
        retryable: false,
      );
    } on CustomSceneProfileContextException catch (error) {
      throw _mapProfileContextFailure(error);
    }
  }

  CustomSceneFailure _mapProfileContextFailure(
    CustomSceneProfileContextException error,
  ) {
    switch (error.kind) {
      case CustomSceneProfileContextFailureKind.network:
        return const CustomSceneFailure(
          kind: CustomSceneFailureKind.network,
          retryable: true,
        );
      case CustomSceneProfileContextFailureKind.timeout:
        return const CustomSceneFailure(
          kind: CustomSceneFailureKind.timeout,
          retryable: true,
        );
      case CustomSceneProfileContextFailureKind.authentication:
        return const CustomSceneFailure(
          kind: CustomSceneFailureKind.authenticationRequired,
          retryable: false,
        );
      case CustomSceneProfileContextFailureKind.malformed:
        return const CustomSceneFailure(
          kind: CustomSceneFailureKind.malformedResponse,
          retryable: false,
        );
      case CustomSceneProfileContextFailureKind.unavailable:
        return CustomSceneFailure(
          kind: CustomSceneFailureKind.unavailable,
          retryable: error.retryable,
        );
    }
  }

  Future<String> _loadInstallationId() async {
    try {
      final installationId = (await _installationIdLoader()).trim();
      if (!isBackendCompatibleInstallationId(installationId)) {
        throw const CustomSceneFailure(
          kind: CustomSceneFailureKind.invalidDraft,
          retryable: false,
        );
      }
      return installationId;
    } on CustomSceneFailure {
      rethrow;
    } on Object {
      throw const CustomSceneFailure(
        kind: CustomSceneFailureKind.unexpected,
        retryable: true,
      );
    }
  }

  void _validateClientRequestId(String value) {
    final validShape = RegExp(
      r'^[A-Za-z0-9][A-Za-z0-9_-]{0,95}$',
    ).hasMatch(value);
    final exposesPhoneLikeSequence = RegExp(r'[0-9]{11,}').hasMatch(value);
    if (!validShape || exposesPhoneLikeSequence) {
      throw const CustomSceneFailure(
        kind: CustomSceneFailureKind.invalidDraft,
        retryable: false,
      );
    }
  }

  CustomSceneFailure _mapApiFailure(CustomSceneApiException error) {
    switch (error.kind) {
      case CustomSceneApiFailureKind.network:
        return const CustomSceneFailure(
          kind: CustomSceneFailureKind.network,
          retryable: true,
        );
      case CustomSceneApiFailureKind.timeout:
        return const CustomSceneFailure(
          kind: CustomSceneFailureKind.timeout,
          retryable: true,
        );
      case CustomSceneApiFailureKind.malformed:
        return const CustomSceneFailure(
          kind: CustomSceneFailureKind.malformedResponse,
          retryable: false,
        );
      case CustomSceneApiFailureKind.http:
        return _mapHttpFailure(error);
    }
  }

  CustomSceneFailure _mapHttpFailure(CustomSceneApiException error) {
    final contentId = error.generatedContentId;
    switch (error.code) {
      case 'consumer_authentication_required':
      case 'consumer_session_invalid':
      case 'invalid_session':
      case 'consent_required':
      case 'consent_revoked':
      case 'account_deleted':
        return const CustomSceneFailure(
          kind: CustomSceneFailureKind.authenticationRequired,
          retryable: false,
        );
      case 'generation_in_progress':
        return CustomSceneFailure(
          kind: CustomSceneFailureKind.generationInProgress,
          retryable: true,
          generatedContentId: contentId,
        );
      case 'client_request_id_conflict':
        return CustomSceneFailure(
          kind: CustomSceneFailureKind.requestConflict,
          retryable: false,
          generatedContentId: contentId,
        );
      case 'client_request_terminal':
        return CustomSceneFailure(
          kind: CustomSceneFailureKind.requestTerminal,
          retryable: error.retryable,
          generatedContentId: contentId,
          requiresNewClientRequestId: error.requiresNewClientRequestId,
        );
      case 'custom_scene_rate_limited':
        return CustomSceneFailure(
          kind: CustomSceneFailureKind.rateLimited,
          retryable: error.retryable,
        );
      case 'generation_unavailable':
        return CustomSceneFailure(
          kind: CustomSceneFailureKind.unavailable,
          retryable: error.retryable,
        );
      case 'generation_timeout':
        return const CustomSceneFailure(
          kind: CustomSceneFailureKind.timeout,
          retryable: true,
        );
      case 'generated_content_rejected':
      case 'unsupported_custom_scene_text':
        return const CustomSceneFailure(
          kind: CustomSceneFailureKind.rejected,
          retryable: false,
        );
      case 'invalid_client_request_id':
      case 'invalid_installation_id':
      case 'invalid_custom_scene_text':
      case 'invalid_age_range':
      case 'invalid_parent_goal':
      case 'unsupported_locale':
      case 'profile_context_mismatch':
        return const CustomSceneFailure(
          kind: CustomSceneFailureKind.invalidDraft,
          retryable: false,
        );
      default:
        if ((error.statusCode ?? 0) >= 500) {
          return CustomSceneFailure(
            kind: CustomSceneFailureKind.unavailable,
            retryable: error.retryable || (error.statusCode ?? 0) >= 500,
          );
        }
        return const CustomSceneFailure(
          kind: CustomSceneFailureKind.unexpected,
          retryable: false,
        );
    }
  }
}
