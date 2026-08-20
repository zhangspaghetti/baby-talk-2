import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/network/auth_headers.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_api.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_memory_cache.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/care_audio_playback_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android BytesSource completes six controlled MP3 payloads', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final output = AudioplayersCareAudioOutput();

      try {
        var sessionId = 0;
        for (final assetPath in _controlledMp3Assets) {
          final expectedSessionId = ++sessionId;
          final asset = await rootBundle.load(assetPath);
          final bytes = Uint8List.view(
            asset.buffer,
            asset.offsetInBytes,
            asset.lengthInBytes,
          );
          final completed = output.completionStream.first.timeout(
            const Duration(seconds: 15),
          );

          await output.playBytes(
            bytes,
            'audio/mpeg',
            sessionId: expectedSessionId,
            playbackRate: 1.0,
          );
          expect((await completed).sessionId, expectedSessionId);
        }
      } finally {
        await output.dispose();
      }
    });
  });

  testWidgets(
    'Android controlled local HTTP generated audio reaches BytesSource completion',
    (tester) async {
      await tester.runAsync(() async {
        final asset = await rootBundle.load(_controlledMp3Assets.first);
        final audioBytes = Uint8List.view(
          asset.buffer,
          asset.offsetInBytes,
          asset.lengthInBytes,
        );
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final api = GeneratedAudioApi(
          authenticatedApiClient: AuthenticatedApiClient(
            apiService: _NoRefreshAccountApiService(),
          ),
          baseUrl: 'http://${server.address.address}:${server.port}',
        );
        final controller = SourceNeutralCareAudioPlaybackController(
          generatedAudioRepository: _repository(api),
        );

        try {
          final inboundRequest = server.first;
          final completed = controller.completionStream.first.timeout(
            const Duration(seconds: 15),
          );
          final playing = controller.play(
            const CareAudioPlaybackRequest(
              source: GeneratedCareAudioSource(
                generatedContentId: 'pgc_controlled_network_1',
                utteranceId: 'utt_controlled_network_1',
              ),
              sessionId: 1,
            ),
          );
          final inbound = await inboundRequest;
          expect(inbound.method, 'GET');
          expect(
            inbound.uri.path,
            '/api/v1/practice/generated-content/'
            'pgc_controlled_network_1/utterances/'
            'utt_controlled_network_1/audio',
          );
          expect(
            inbound.headers.value(authorizationHeaderName),
            'Bearer accepted-access-token',
          );
          expect(
            inbound.headers.value('accept'),
            'audio/mpeg, application/json',
          );
          expect(
            inbound.headers.value('x-app-version'),
            defaultAccountApiVersion,
          );
          inbound.response.headers.contentType = ContentType('audio', 'mpeg');
          inbound.response.headers.set(
            'x-generated-audio-voice-version',
            'generated-tts-v1',
          );
          inbound.response.add(audioBytes);
          await inbound.response.close();

          await playing;
          expect((await completed).sessionId, 1);
        } finally {
          await controller.dispose();
          api.close();
          await server.close(force: true);
        }
      });
    },
  );
}

GeneratedAudioRepository _repository(GeneratedAudioApi api) {
  final session = AccountSession(
    accountId: 'accepted-account',
    sessionId: 'accepted-session',
    maskedPhoneNumber: '138****0000',
    createdAt: DateTime.utc(2026, 7, 28),
    accessToken: 'accepted-access-token',
    refreshToken: 'accepted-refresh-token',
  );
  return GeneratedAudioRepository(
    api: api,
    cache: GeneratedAudioMemoryCache(),
    accountSnapshotLoader: () async => AccountLocalSnapshot(
      consentState: AccountConsentState.acceptedPendingSync,
      session: session,
    ),
    persistRefreshedSession: (value) async => value,
  );
}

class _NoRefreshAccountApiService extends AccountApiService {
  _NoRefreshAccountApiService() : super();

  @override
  Future<AccountSessionResponse> refreshSession({
    required String refreshToken,
  }) {
    throw StateError('refresh should not be called');
  }

  @override
  Future<void> close() async {}
}

const _controlledMp3Assets = <String>[
  'assets/audio/phrases/bath_time_warm_water.mp3',
  'assets/audio/phrases/bath_time_splash_splash.mp3',
  'assets/audio/phrases/bath_time_all_clean.mp3',
  'assets/audio/phrases/diaper_change_clean_bottom.mp3',
  'assets/audio/phrases/diaper_change_all_dry.mp3',
  'assets/audio/phrases/feeding_time_open_wide.mp3',
];
