import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_memory_cache.dart';

void main() {
  test('cache identity includes policy and content refresh epoch', () {
    GeneratedAudioCacheKey key({required String policy, required int epoch}) {
      return GeneratedAudioCacheKey(
        accountId: 'acct_1',
        generatedContentId: 'content_1',
        utteranceId: 'utterance_1',
        voiceVersion: 'generated-tts-v1',
        format: 'mp3',
        safetyPolicyVersion: policy,
        contentRefreshEpoch: epoch,
      );
    }

    expect(
      key(policy: 'health-safety-v0', epoch: 2),
      isNot(key(policy: 'health-safety-v1', epoch: 2)),
    );
    expect(
      key(policy: 'health-safety-v1', epoch: 1),
      isNot(key(policy: 'health-safety-v1', epoch: 2)),
    );
  });

  test('clear prevents an old in-flight response from being cached', () async {
    final cache = GeneratedAudioMemoryCache();
    final gate = Future<GeneratedAudioPayload>.value(
      GeneratedAudioPayload(
        bytes: Uint8List.fromList(<int>[1]),
        mimeType: 'audio/mpeg',
        voiceVersion: 'generated-tts-v1',
      ),
    );
    final key = GeneratedAudioCacheKey(
      accountId: 'acct_1',
      generatedContentId: 'content_1',
      utteranceId: 'utterance_1',
      voiceVersion: 'generated-tts-v1',
      format: 'mp3',
      safetyPolicyVersion: 'health-safety-v1',
      contentRefreshEpoch: 2,
    );

    final pending = cache.getOrLoad(key, () => gate);
    cache.clear();
    await pending;

    expect(cache.entryCount, 0);
  });
}
