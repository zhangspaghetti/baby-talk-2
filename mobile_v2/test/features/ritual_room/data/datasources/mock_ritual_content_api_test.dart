import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/data/datasources/mock_ritual_content_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'R058/R059 mock content API asynchronously loads the registered shoes_on fixture',
    () async {
      final api = MockRitualContentApi(assetBundle: rootBundle);

      final response = await api.fetchRoom('shoes_on_room_v1');

      expect(response.ritualRoomId, 'shoes_on_room_v1');
      expect(response.atmosphereTone, 'everyday_calm');
      expect(response.anchorPhrase, 'Shoes on.');
      expect(
        response.illustration.assetPath,
        'assets/illustrations/rituals/shoes_on/shoes_on_approved_v1.png',
      );
      expect(response.illustration.status, 'approved');
      final illustration = await rootBundle.load(
        response.illustration.assetPath,
      );
      expect(illustration.lengthInBytes, greaterThan(0));
    },
  );

  test(
    'R060/R063/R064/R065 fixture owns evidence but no runtime or Garden transition fields',
    () async {
      final raw = await rootBundle.loadString(
        'assets/fixtures/ritual_rooms/shoes_on.json',
      );
      final payload = jsonDecode(raw) as Map<String, Object?>;

      expect(payload['atmosphere_tone'], 'everyday_calm');
      expect(payload['governance_evidence'], {
        'context_seed_id': 'context_seed_shoes_on',
        'joinability_hypothesis': 'shared_action_is_open',
        'governor_decision': 'allow_activation',
        'production_garden_status': 'not_enabled',
      });
      expect(payload['reaction_prompt'], '现在是什么情况？');
      expect(payload['pending_copy'], '正在换一种说法…');
      expect(payload['quiet_exit'], '先这样就好');

      final keys = _allKeys(payload);
      expect(
        keys.intersection({
          'product_snapshot',
          'consistency_state',
          'replay_journal',
          'score',
          'streak',
          'completed',
          'completion',
          'garden_transition',
          'activation_authority',
        }),
        isEmpty,
      );
    },
  );

  test('unknown ritual identity is rejected instead of substituted', () async {
    final api = MockRitualContentApi(assetBundle: rootBundle);

    expect(() => api.fetchRoom('unknown_room'), throwsA(isA<ArgumentError>()));
  });
}

Set<String> _allKeys(Object? value) {
  if (value is Map<String, Object?>) {
    return {
      ...value.keys,
      for (final child in value.values) ..._allKeys(child),
    };
  }
  if (value is List<Object?>) {
    return {for (final child in value) ..._allKeys(child)};
  }
  return const {};
}
