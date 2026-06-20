import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/input_event.dart';

final class InputFingerprint {
  const InputFingerprint._();

  static String forEvent(InputEvent event) {
    final canonical = canonicalize({
      'eventId': event.eventId,
      'type': event.type.wireName,
      'timestamp': event.occurredAt,
      'payload': event.payload.canonicalFields,
    });
    return 'sha256:${sha256.convert(utf8.encode(canonical))}';
  }

  static String canonicalize(Object? value) => jsonEncode(_normalize(value));

  static Object? _normalize(Object? value) {
    if (value == null || value is bool || value is num || value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is List<Object?>) {
      return value.map(_normalize).toList(growable: false);
    }
    if (value is Map<Object?, Object?>) {
      if (value.keys.any((key) => key is! String)) {
        throw ArgumentError.value(value, 'value', 'Map keys must be strings');
      }
      final keys = value.keys.cast<String>().toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _normalize(value[key]),
      };
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unsupported canonical fingerprint value',
    );
  }
}
