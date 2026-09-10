import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_memory_cache.dart';

void main() {
  GeneratedAudioPayload payload(int bytes) => GeneratedAudioPayload(
    bytes: Uint8List(bytes),
    mimeType: 'audio/mpeg',
    voiceVersion: 'generated-tts-v1',
  );
  GeneratedAudioCacheKey key(String value) => GeneratedAudioCacheKey(
    accountId: 'acct_1',
    generatedContentId: 'content_$value',
    utteranceId: 'utterance_$value',
    voiceVersion: 'generated-tts-v1',
    format: 'mp3',
  );

  test('same key shares one in-flight request', () async {
    final cache = GeneratedAudioMemoryCache();
    final gate = Completer<GeneratedAudioPayload>();
    var loads = 0;

    final first = cache.getOrLoad(key('one'), () {
      loads += 1;
      return gate.future;
    });
    final second = cache.getOrLoad(key('one'), () {
      loads += 1;
      return Future<GeneratedAudioPayload>.value(payload(1));
    });
    gate.complete(payload(2));

    expect(await first, same(await second));
    expect(loads, 1);
  });

  test('uses TTL and LRU while retaining bounded bytes', () async {
    var now = DateTime.utc(2026, 7, 28, 10);
    final cache = GeneratedAudioMemoryCache(
      maxEntries: 2,
      maxTotalBytes: 3,
      ttl: const Duration(minutes: 1),
      now: () => now,
    );
    var firstLoads = 0;
    await cache.getOrLoad(key('one'), () async {
      firstLoads += 1;
      return payload(1);
    });
    await cache.getOrLoad(key('two'), () async => payload(2));
    await cache.getOrLoad(key('one'), () async => payload(1));
    await cache.getOrLoad(key('three'), () async => payload(2));

    expect(cache.entryCount, 2);
    expect(cache.totalBytes, 3);
    await cache.getOrLoad(key('two'), () async => payload(1));
    expect(cache.entryCount, 2);

    now = now.add(const Duration(minutes: 2));
    await cache.getOrLoad(key('one'), () async {
      firstLoads += 1;
      return payload(1);
    });
    expect(firstLoads, 2);
  });

  test(
    'lifecycle clear prevents a late response from repopulating cache',
    () async {
      final cache = GeneratedAudioMemoryCache();
      final gate = Completer<GeneratedAudioPayload>();

      final pending = cache.getOrLoad(key('one'), () => gate.future);
      cache.clear();
      gate.complete(payload(1));
      await pending;

      expect(cache.entryCount, 0);
      expect(cache.totalBytes, 0);
    },
  );

  test('lifecycle clear makes a same-key caller start a new request', () async {
    final cache = GeneratedAudioMemoryCache();
    final oldGate = Completer<GeneratedAudioPayload>();
    final freshGate = Completer<GeneratedAudioPayload>();
    var loads = 0;

    final oldRequest = cache.getOrLoad(key('one'), () {
      loads += 1;
      return oldGate.future;
    });
    cache.clear();
    final freshRequest = cache.getOrLoad(key('one'), () {
      loads += 1;
      return freshGate.future;
    });

    expect(loads, 2);
    freshGate.complete(payload(2));
    expect((await freshRequest).byteLength, 2);

    oldGate.complete(payload(1));
    await oldRequest;
    expect(cache.entryCount, 1);
    expect(cache.totalBytes, 2);
  });
}
