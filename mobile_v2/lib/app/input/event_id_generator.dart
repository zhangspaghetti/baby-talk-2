import 'dart:math';

import '../../features/ritual_room/domain/runtime/interaction_id_generator.dart';

abstract interface class EventIdGenerator {
  String nextEventId();
}

/// Generates opaque 128-bit identifiers with no embedded product meaning.
final class SecureEventIdGenerator implements EventIdGenerator {
  SecureEventIdGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  String nextEventId() => List<int>.generate(
    16,
    (_) => _random.nextInt(256),
    growable: false,
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

/// Uses the same opaque identifier policy for interaction lifecycle identity.
final class SecureInteractionIdGenerator implements InteractionIdGenerator {
  SecureInteractionIdGenerator({EventIdGenerator? generator})
    : _generator = generator ?? SecureEventIdGenerator();

  final EventIdGenerator _generator;

  @override
  String generate() => _generator.nextEventId();
}
