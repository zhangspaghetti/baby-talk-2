import '../../features/ritual_room/domain/models/input_event.dart';
import '../../features/ritual_room/domain/runtime/interaction_clock.dart';
import 'event_id_generator.dart';

/// Creates ephemeral typed input events and retains none of their raw content.
final class InteractionInputFactory {
  const InteractionInputFactory({
    required InteractionClock clock,
    required EventIdGenerator idGenerator,
  }) : _clock = clock,
       _idGenerator = idGenerator;

  final InteractionClock _clock;
  final EventIdGenerator _idGenerator;

  InputEvent reaction(String selected) => InputEvent.reactionSelection(
    eventId: _idGenerator.nextEventId(),
    occurredAt: _clock.now(),
    selected: selected,
  );

  InputEvent voice(String transcript) => InputEvent.voiceObservation(
    eventId: _idGenerator.nextEventId(),
    occurredAt: _clock.now(),
    transcript: transcript,
  );

  InputEvent freeText(String text) => InputEvent.freeText(
    eventId: _idGenerator.nextEventId(),
    occurredAt: _clock.now(),
    text: text,
  );

  InputEvent futureSignal({required String signal, required String value}) =>
      InputEvent.futureSignal(
        eventId: _idGenerator.nextEventId(),
        occurredAt: _clock.now(),
        signal: signal,
        value: value,
      );

  InputEvent strategyPreference(String preference) =>
      InputEvent.strategyPreference(
        eventId: _idGenerator.nextEventId(),
        occurredAt: _clock.now(),
        preference: preference,
      );
}
