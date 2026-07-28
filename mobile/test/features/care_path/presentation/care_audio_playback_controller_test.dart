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
      const CareAudioPlaybackRequest(
        source: GeneratedCareAudioSource(
          generatedContentId: 'pgc_1',
          utteranceId: 'utt_1',
        ),
        sessionId: 1,
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
      const CareAudioPlaybackRequest(
        source: CareAssetAudioSource(assetPath: 'assets/audio/seed.mp3'),
        sessionId: 1,
      ),
    );

    expect(output.playedAssets, <String>['audio/seed.mp3']);
  });

  test(
    'old output completion never becomes a newer playback session',
    () async {
      final output = _MemoryOutput();
      final controller = SourceNeutralCareAudioPlaybackController(
        generatedAudioRepository: _repository(_DelayedGateway()),
        output: output,
      );
      final completions = <CareAudioPlaybackCompletion>[];
      final subscription = controller.completionStream.listen(completions.add);
      addTearDown(subscription.cancel);

      await controller.play(
        const CareAudioPlaybackRequest(
          source: CareAssetAudioSource(assetPath: 'assets/audio/seed.mp3'),
          sessionId: 7,
        ),
      );
      output.emitCompletion(7);
      await Future<void>.delayed(Duration.zero);
      expect(completions.single.sessionId, 7);

      await controller.stop();
      await controller.play(
        const CareAudioPlaybackRequest(
          source: CareAssetAudioSource(assetPath: 'assets/audio/seed.mp3'),
          sessionId: 8,
        ),
      );
      output.emitCompletion(7);
      await Future<void>.delayed(Duration.zero);
      expect(completions.map((completion) => completion.sessionId), <int>[
        7,
        7,
      ]);

      output.emitCompletion(8);
      await Future<void>.delayed(Duration.zero);
      expect(completions.map((completion) => completion.sessionId), <int>[
        7,
        7,
        8,
      ]);
    },
  );

  test(
    'same generated identity shares one session request and memory result',
    () async {
      final gateway = _PerUtteranceGateway();
      final repository = _repository(gateway);
      const source = GeneratedCareAudioSource(
        generatedContentId: 'pgc_1',
        utteranceId: 'starter_1',
      );

      final first = repository.load(source);
      final second = repository.load(source);
      await gateway.requested('starter_1');
      expect(gateway.fetchCount('starter_1'), 1);

      gateway.respond(
        'starter_1',
        GeneratedAudioPayload(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          mimeType: 'audio/mpeg',
          voiceVersion: 'generated-tts-v1',
        ),
      );

      expect(await first, same(await second));
      await repository.load(source);
      expect(gateway.fetchCount('starter_1'), 1);
    },
  );

  test(
    'changing generated reaction prevents an older branch from playing',
    () async {
      final gateway = _PerUtteranceGateway();
      final output = _MemoryOutput();
      final controller = SourceNeutralCareAudioPlaybackController(
        generatedAudioRepository: _repository(gateway),
        output: output,
      );
      const starter = GeneratedCareAudioSource(
        generatedContentId: 'pgc_1',
        utteranceId: 'starter_1',
      );
      const support = GeneratedCareAudioSource(
        generatedContentId: 'pgc_1',
        utteranceId: 'support_hesitant_1',
      );

      final starterPlayback = controller.play(
        const CareAudioPlaybackRequest(source: starter, sessionId: 1),
      );
      await gateway.requested(starter.utteranceId);
      final supportPlayback = controller.play(
        const CareAudioPlaybackRequest(source: support, sessionId: 2),
      );
      await gateway.requested(support.utteranceId);

      gateway.respond(
        starter.utteranceId,
        GeneratedAudioPayload(
          bytes: Uint8List.fromList(<int>[1]),
          mimeType: 'audio/mpeg',
          voiceVersion: 'generated-tts-v1',
        ),
      );
      await starterPlayback;
      expect(output.playedBytes, isEmpty);

      gateway.respond(
        support.utteranceId,
        GeneratedAudioPayload(
          bytes: Uint8List.fromList(<int>[2]),
          mimeType: 'audio/mpeg',
          voiceVersion: 'generated-tts-v1',
        ),
      );
      await supportPlayback;
      expect(output.playedBytes, <List<int>>[
        <int>[2],
      ]);
    },
  );
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

class _PerUtteranceGateway implements GeneratedAudioGateway {
  final Map<String, Completer<void>> _requests = <String, Completer<void>>{};
  final Map<String, Completer<GeneratedAudioPayload>> _responses =
      <String, Completer<GeneratedAudioPayload>>{};
  final Map<String, int> _fetchCounts = <String, int>{};

  Future<void> requested(String utteranceId) => _requestFor(utteranceId).future;

  int fetchCount(String utteranceId) => _fetchCounts[utteranceId] ?? 0;

  void respond(String utteranceId, GeneratedAudioPayload payload) {
    _responseFor(utteranceId).complete(payload);
  }

  @override
  Future<GeneratedAudioPayload> fetch({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    required String generatedContentId,
    required String utteranceId,
    required String expectedVoiceVersion,
    required String expectedFormat,
  }) {
    _fetchCounts.update(utteranceId, (count) => count + 1, ifAbsent: () => 1);
    _requestFor(utteranceId).complete();
    return _responseFor(utteranceId).future;
  }

  Completer<void> _requestFor(String utteranceId) {
    return _requests.putIfAbsent(utteranceId, Completer<void>.new);
  }

  Completer<GeneratedAudioPayload> _responseFor(String utteranceId) {
    return _responses.putIfAbsent(
      utteranceId,
      Completer<GeneratedAudioPayload>.new,
    );
  }
}

class _MemoryOutput implements CareAudioOutput {
  final StreamController<CareAudioPlaybackCompletion> _completion =
      StreamController<CareAudioPlaybackCompletion>.broadcast();
  final List<List<int>> playedBytes = <List<int>>[];
  final List<String> playedAssets = <String>[];
  int stopCalls = 0;

  @override
  Stream<CareAudioPlaybackCompletion> get completionStream =>
      _completion.stream;

  void emitCompletion(int sessionId) {
    _completion.add(CareAudioPlaybackCompletion(sessionId: sessionId));
  }

  @override
  Future<void> dispose() => _completion.close();

  @override
  Future<void> playAsset(String assetPath, {required int sessionId}) async {
    playedAssets.add(assetPath);
  }

  @override
  Future<void> playBytes(
    List<int> bytes,
    String mimeType, {
    required int sessionId,
  }) async {
    playedBytes.add(bytes);
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}
