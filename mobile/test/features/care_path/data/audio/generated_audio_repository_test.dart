import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_api.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_memory_cache.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';

void main() {
  test('stale or missing provenance fails before cache and API', () async {
    final cache = GeneratedAudioMemoryCache();
    var accountLoads = 0;
    var apiCalls = 0;
    final repository = GeneratedAudioRepository(
      api: _Gateway(onFetch: () => apiCalls += 1),
      cache: cache,
      accountSnapshotLoader: () async {
        accountLoads += 1;
        return _accountSnapshot;
      },
      persistRefreshedSession: (session) async => session,
    );

    for (final source in <GeneratedCareAudioSource>[
      const GeneratedCareAudioSource(
        generatedContentId: 'content_1',
        utteranceId: 'utterance_1',
        safetyPolicyVersion: 'health-safety-v0',
        contentRefreshEpoch: 1,
      ),
      const GeneratedCareAudioSource(
        generatedContentId: 'content_1',
        utteranceId: 'utterance_1',
        safetyPolicyVersion: '',
        contentRefreshEpoch: 0,
      ),
    ]) {
      await expectLater(
        repository.load(source),
        throwsA(isA<GeneratedAudioRepositoryException>()),
      );
    }

    expect(accountLoads, 0);
    expect(apiCalls, 0);
    expect(cache.entryCount, 0);
  });

  test('current generated provenance permits cache hit', () async {
    var apiCalls = 0;
    final repository = GeneratedAudioRepository(
      api: _Gateway(
        onFetch: () => apiCalls += 1,
        payload: GeneratedAudioPayload(
          bytes: Uint8List.fromList(<int>[1]),
          mimeType: 'audio/mpeg',
          voiceVersion: 'generated-tts-v1',
        ),
      ),
      cache: GeneratedAudioMemoryCache(),
      accountSnapshotLoader: () async => _accountSnapshot,
      persistRefreshedSession: (session) async => session,
    );
    const source = GeneratedCareAudioSource(
      generatedContentId: 'content_1',
      utteranceId: 'utterance_1',
      safetyPolicyVersion: 'health-safety-v1',
      contentRefreshEpoch: 2,
    );

    await repository.load(source);
    await repository.load(source);

    expect(apiCalls, 1);
  });
}

final _accountSnapshot = AccountLocalSnapshot(
  consentState: AccountConsentState.acceptedPendingSync,
  session: AccountSession(
    accountId: 'acct_1',
    sessionId: 'session_1',
    maskedPhoneNumber: '138****0000',
    createdAt: DateTime.utc(2026, 7, 28),
    accessToken: 'access',
    refreshToken: 'refresh',
  ),
);

class _Gateway implements GeneratedAudioGateway {
  _Gateway({this.onFetch, this.payload});

  final void Function()? onFetch;
  final GeneratedAudioPayload? payload;

  @override
  Future<GeneratedAudioPayload> fetch({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    required String generatedContentId,
    required String utteranceId,
    required String expectedVoiceVersion,
    required String expectedFormat,
  }) async {
    onFetch?.call();
    return payload ??
        GeneratedAudioPayload(
          bytes: Uint8List.fromList(<int>[1]),
          mimeType: 'audio/mpeg',
          voiceVersion: expectedVoiceVersion,
        );
  }
}
