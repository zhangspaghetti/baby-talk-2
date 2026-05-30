import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  group('BabyReactionType wire mapping', () {
    test('needsBreak maps to needs_break and parses back', () {
      expect(BabyReactionType.needsBreak.wireValue, 'needs_break');
      expect(parseBabyReactionType('needs_break'), BabyReactionType.needsBreak);
    });
  });
}
