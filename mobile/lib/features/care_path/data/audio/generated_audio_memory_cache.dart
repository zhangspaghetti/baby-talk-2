import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

class GeneratedAudioPayload {
  GeneratedAudioPayload({
    required Uint8List bytes,
    required this.mimeType,
    required this.voiceVersion,
  }) : bytes = Uint8List.fromList(bytes) {
    if (this.bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', '生成音频不能为空。');
    }
    if (mimeType.trim().isEmpty || voiceVersion.trim().isEmpty) {
      throw ArgumentError('生成音频元数据不能为空。');
    }
  }

  final Uint8List bytes;
  final String mimeType;
  final String voiceVersion;

  int get byteLength => bytes.lengthInBytes;
}

class GeneratedAudioCacheKey {
  GeneratedAudioCacheKey({
    required String accountId,
    required String generatedContentId,
    required String utteranceId,
    required String voiceVersion,
    required String format,
  }) : accountId = _required(accountId, 'accountId'),
       generatedContentId = _required(generatedContentId, 'generatedContentId'),
       utteranceId = _required(utteranceId, 'utteranceId'),
       voiceVersion = _required(voiceVersion, 'voiceVersion'),
       format = _required(format, 'format');

  final String accountId;
  final String generatedContentId;
  final String utteranceId;
  final String voiceVersion;
  final String format;

  @override
  bool operator ==(Object other) {
    return other is GeneratedAudioCacheKey &&
        other.accountId == accountId &&
        other.generatedContentId == generatedContentId &&
        other.utteranceId == utteranceId &&
        other.voiceVersion == voiceVersion &&
        other.format == format;
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    generatedContentId,
    utteranceId,
    voiceVersion,
    format,
  );
}

/// Volatile generated-audio cache. It never creates files or persistent stores.
class GeneratedAudioMemoryCache {
  GeneratedAudioMemoryCache({
    this.maxEntries = 12,
    this.maxTotalBytes = 2 * 1024 * 1024,
    this.ttl = const Duration(minutes: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    if (maxEntries <= 0 || maxTotalBytes <= 0 || ttl <= Duration.zero) {
      throw ArgumentError('缓存边界必须为正数。');
    }
  }

  final int maxEntries;
  final int maxTotalBytes;
  final Duration ttl;
  final DateTime Function() _now;
  final LinkedHashMap<GeneratedAudioCacheKey, _CacheEntry> _entries =
      LinkedHashMap<GeneratedAudioCacheKey, _CacheEntry>();
  final Map<GeneratedAudioCacheKey, _InFlightAudioLoad> _inFlight =
      <GeneratedAudioCacheKey, _InFlightAudioLoad>{};
  int _totalBytes = 0;
  int _generation = 0;

  int get entryCount => _entries.length;
  int get totalBytes => _totalBytes;

  Future<GeneratedAudioPayload> getOrLoad(
    GeneratedAudioCacheKey key,
    Future<GeneratedAudioPayload> Function() loader,
  ) {
    final cached = _takeIfFresh(key);
    if (cached != null) {
      return Future<GeneratedAudioPayload>.value(cached);
    }
    final active = _inFlight[key];
    if (active != null && active.generation == _generation) {
      return active.future;
    }

    final generation = _generation;
    late final _InFlightAudioLoad load;
    late final Future<GeneratedAudioPayload> future;
    future = Future<GeneratedAudioPayload>.sync(loader)
        .then((payload) {
          if (generation == _generation) {
            _store(key, payload);
          }
          return payload;
        })
        .whenComplete(() {
          if (identical(_inFlight[key], load)) {
            _inFlight.remove(key);
          }
        });
    load = _InFlightAudioLoad(generation: generation, future: future);
    _inFlight[key] = load;
    return future;
  }

  void clear() {
    _generation += 1;
    _entries.clear();
    _inFlight.clear();
    _totalBytes = 0;
  }

  GeneratedAudioPayload? _takeIfFresh(GeneratedAudioCacheKey key) {
    final entry = _entries.remove(key);
    if (entry == null) {
      return null;
    }
    if (_now().difference(entry.cachedAt) >= ttl) {
      _totalBytes -= entry.payload.byteLength;
      return null;
    }
    _entries[key] = entry;
    return entry.payload;
  }

  void _store(GeneratedAudioCacheKey key, GeneratedAudioPayload payload) {
    if (payload.byteLength > maxTotalBytes) {
      return;
    }
    final existing = _entries.remove(key);
    if (existing != null) {
      _totalBytes -= existing.payload.byteLength;
    }
    _entries[key] = _CacheEntry(payload: payload, cachedAt: _now());
    _totalBytes += payload.byteLength;
    while (_entries.length > maxEntries || _totalBytes > maxTotalBytes) {
      final oldest = _entries.entries.first;
      _entries.remove(oldest.key);
      _totalBytes -= oldest.value.payload.byteLength;
    }
  }
}

class _CacheEntry {
  const _CacheEntry({required this.payload, required this.cachedAt});

  final GeneratedAudioPayload payload;
  final DateTime cachedAt;
}

class _InFlightAudioLoad {
  const _InFlightAudioLoad({required this.generation, required this.future});

  final int generation;
  final Future<GeneratedAudioPayload> future;
}

String _required(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, '不能为空。');
  }
  return normalized;
}
