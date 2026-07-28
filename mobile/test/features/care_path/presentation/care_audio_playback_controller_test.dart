import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/care_audio_playback_controller.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_api.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_memory_cache.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_repository.dart';

void main() {
  test('stopped generated request cannot start late playback', () async {
    final gateway = _DelayedGateway();
    final output = _MemoryOutput();
    final controller = SourceNeutralCareAudioPlaybackController(
      generatedAudioRepository: _repository(gateway),
      output: output,
    );

    final playing = controller.play(
      const GeneratedCareAudioSource(
        generatedContentId: 'pgc_1',
        utteranceId: 'utt_1',
      ),
    );
    await gateway.requested.future;
    await controller.stop();
    gateway.response.complete(
      GeneratedAudioPayload(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        mimeType: 'audio/mpeg',
        voiceVersion: 'generated-tts-v1',
      ),
    );
    await playing;

    expect(output.playedBytes, isEmpty);
    expect(output.stopCalls, 1);
  });

  test('seed asset remains packaged-asset playback', () async {
    final output = _MemoryOutput();
    final controller = SourceNeutralCareAudioPlaybackController(
      generatedAudioRepository: _repository(_DelayedGateway()),
      output: output,
    );

    await controller.play(
      const CareAssetAudioSource(assetPath: 'assets/audio/seed.mp3'),
    );

    expect(output.playedAssets, <String>['audio/seed.mp3']);
  });
}

GeneratedAudioRepository _repository(GeneratedAudioGateway gateway) {
  final session = AccountSession(
    accountId: 'acct_1',
    sessionId: 'session_1',
    maskedPhoneNumber: '138****0000',
    createdAt: DateTime.utc(2026, 7, 28),
    accessToken: 'access',
    refreshToken: 'refresh',
  );
  return GeneratedAudioRepository(
    api: gateway,
    cache: GeneratedAudioMemoryCache(),
    accountSnapshotLoader: () async => AccountLocalSnapshot(
      consentState: AccountConsentState.acceptedPendingSync,
      session: session,
    ),
    persistRefreshedSession: (value) async => value,
  );
}

class _DelayedGateway implements GeneratedAudioGateway {
  final requested = Completer<void>();
  final response = Completer<GeneratedAudioPayload>();

  @override
  Future<GeneratedAudioPayload> fetch({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    required String generatedContentId,
    required String utteranceId,
    required String expectedVoiceVersion,
    required String expectedFormat,
  }) {
    requested.complete();
    return response.future;
  }
}

class _MemoryOutput implements CareAudioOutput {
  final StreamController<void> _completion = StreamController<void>.broadcast();
  final List<List<int>> playedBytes = <List<int>>[];
  final List<String> playedAssets = <String>[];
  int stopCalls = 0;

  @override
  Stream<void> get completionStream => _completion.stream;

  @override
  Future<void> dispose() => _completion.close();

  @override
  Future<void> playAsset(String assetPath) async {
    playedAssets.add(assetPath);
  }

  @override
  Future<void> playBytes(List<int> bytes, String mimeType) async {
    playedBytes.add(bytes);
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}
