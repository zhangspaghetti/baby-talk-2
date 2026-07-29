import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  group('BabyReactionType wire mapping', () {
    test('canonical reactions write and parse canonical wire values', () {
      expect(BabyReactionType.cooperating.wireValue, 'cooperating');
      expect(BabyReactionType.hesitant.wireValue, 'hesitant');
      expect(BabyReactionType.resisting.wireValue, 'resisting');
      expect(BabyReactionType.noResponse.wireValue, 'no_response');
      expect(BabyReactionType.other.wireValue, 'other');

      expect(
        parseBabyReactionType('cooperating'),
        BabyReactionType.cooperating,
      );
      expect(parseBabyReactionType('hesitant'), BabyReactionType.hesitant);
      expect(parseBabyReactionType('resisting'), BabyReactionType.resisting);
      expect(parseBabyReactionType('no_response'), BabyReactionType.noResponse);
      expect(parseBabyReactionType('other'), BabyReactionType.other);
    });

    test('old and unknown reaction wire values are rejected', () {
      for (final value in [
        'calm',
        'engaged',
        'imitated',
        'needs_break',
        'mystery',
      ]) {
        expect(
          () => parseBabyReactionType(value),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('generated interaction identity is complete and immutable', () {
      expect(
        () => InteractionEventPayload.validated(
          localEventId: 'evt_generated_incomplete',
          installationId: 'install_test',
          spaceId: 'generated_space',
          activityId: 'generated_activity',
          phraseId: 'phrase_starter',
          reactionType: BabyReactionType.hesitant,
          clientTimestamp: DateTime.utc(2026, 7, 29),
          generatedContentId: 'generated_1',
        ),
        throwsFormatException,
      );

      final payload = InteractionEventPayload.validated(
        localEventId: 'evt_generated_complete',
        installationId: 'install_test',
        spaceId: 'generated_space',
        activityId: 'generated_activity',
        phraseId: 'phrase_starter',
        reactionType: BabyReactionType.hesitant,
        clientTimestamp: DateTime.utc(2026, 7, 29),
        generatedContentId: 'generated_1',
        utteranceId: 'utterance_starter',
      );

      expect(payload.generatedContentId, 'generated_1');
      expect(payload.utteranceId, 'utterance_starter');
      expect(payload.reactionType.wireValue, 'hesitant');
      expect(payload.toFactMap()['generatedContentId'], 'generated_1');
    });
  });
}
