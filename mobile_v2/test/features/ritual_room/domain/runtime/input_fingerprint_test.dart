import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/input_event.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/input_fingerprint.dart';

void main() {
  group('InputFingerprint', () {
    test(
      'canonical maps ignore insertion order and timestamps normalize to UTC',
      () {
        final localTime = DateTime.parse('2026-06-20T12:30:00+08:00');
        final utcTime = DateTime.parse('2026-06-20T04:30:00Z');

        final first = InputFingerprint.canonicalize({
          'nested': {
            'timestamp': localTime,
            'values': ['first', 'second'],
          },
          'eventId': 'event-1',
        });
        final second = InputFingerprint.canonicalize({
          'eventId': 'event-1',
          'nested': {
            'values': ['first', 'second'],
            'timestamp': utcTime,
          },
        });

        expect(first, second);
        expect(first, contains('2026-06-20T04:30:00.000Z'));
      },
    );

    test('list order remains significant', () {
      final first = InputFingerprint.canonicalize({
        'values': ['first', 'second'],
      });
      final second = InputFingerprint.canonicalize({
        'values': ['second', 'first'],
      });

      expect(first, isNot(second));
    });

    test('complete immutable event content determines the fingerprint', () {
      final occurredAt = DateTime.utc(2026, 6, 20, 4, 30);
      final event = InputEvent.voiceObservation(
        eventId: 'voice-1',
        occurredAt: occurredAt,
        transcript: 'the shared action is hard to enter',
      );
      final equivalent = InputEvent.voiceObservation(
        eventId: 'voice-1',
        occurredAt: DateTime.parse('2026-06-20T12:30:00+08:00'),
        transcript: 'the shared action is hard to enter',
      );
      final changedPayload = InputEvent.voiceObservation(
        eventId: 'voice-1',
        occurredAt: occurredAt,
        transcript: 'the shared action is open',
      );
      final changedId = InputEvent.voiceObservation(
        eventId: 'voice-2',
        occurredAt: occurredAt,
        transcript: 'the shared action is hard to enter',
      );

      expect(InputFingerprint.forEvent(event), startsWith('sha256:'));
      expect(
        InputFingerprint.forEvent(event),
        InputFingerprint.forEvent(equivalent),
      );
      expect(
        InputFingerprint.forEvent(event),
        isNot(InputFingerprint.forEvent(changedPayload)),
      );
      expect(
        InputFingerprint.forEvent(event),
        isNot(InputFingerprint.forEvent(changedId)),
      );
    });

    test('unsupported canonical values fail closed', () {
      expect(
        () => InputFingerprint.canonicalize({'unsupported': Object()}),
        throwsArgumentError,
      );
    });
  });
}
