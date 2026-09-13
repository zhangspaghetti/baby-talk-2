import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_api.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_memory_cache.dart';
import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';

class GeneratedAudioRepositoryException implements Exception {
  const GeneratedAudioRepositoryException();
}

typedef GeneratedAudioAccountSnapshotLoader =
    Future<AccountLocalSnapshot> Function();

class GeneratedAudioRepository {
  GeneratedAudioRepository({
    required GeneratedAudioGateway api,
    required GeneratedAudioMemoryCache cache,
    required GeneratedAudioAccountSnapshotLoader accountSnapshotLoader,
    required PersistRefreshedSession persistRefreshedSession,
  }) : _api = api,
       _cache = cache,
       _accountSnapshotLoader = accountSnapshotLoader,
       _persistRefreshedSession = persistRefreshedSession;

  final GeneratedAudioGateway _api;
  final GeneratedAudioMemoryCache _cache;
  final GeneratedAudioAccountSnapshotLoader _accountSnapshotLoader;
  final PersistRefreshedSession _persistRefreshedSession;

  Future<GeneratedAudioPayload> load(GeneratedCareAudioSource source) async {
    _validateSource(source);
    final account = await _loadAuthenticatedAccount();
    final session = account.session!;
    final key = GeneratedAudioCacheKey(
      accountId: session.accountId,
      generatedContentId: source.generatedContentId,
      utteranceId: source.utteranceId,
      voiceVersion: source.voiceVersion,
      format: source.format,
      safetyPolicyVersion: source.safetyPolicyVersion,
      contentRefreshEpoch: source.contentRefreshEpoch,
    );
    return _cache.getOrLoad(
      key,
      () => _api.fetch(
        session: session,
        persistRefreshedSession: _persistRefreshedSession,
        generatedContentId: source.generatedContentId,
        utteranceId: source.utteranceId,
        expectedVoiceVersion: source.voiceVersion,
        expectedFormat: source.format,
      ),
    );
  }

  void clearForLifecycle() => _cache.clear();

  void _validateSource(GeneratedCareAudioSource source) {
    if (source.safetyPolicyVersion != generatedCareSafetyPolicyVersion ||
        source.contentRefreshEpoch != generatedCareMomentContentRefreshEpoch) {
      throw const GeneratedAudioRepositoryException();
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
        throw const GeneratedAudioRepositoryException();
      }
      return snapshot;
    } on GeneratedAudioRepositoryException {
      rethrow;
    } on Object {
      throw const GeneratedAudioRepositoryException();
    }
  }
}
