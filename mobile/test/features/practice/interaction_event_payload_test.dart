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
  });
}
