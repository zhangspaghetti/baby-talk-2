import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/data/datasources/ritual_content_api.dart';
import 'package:mobile_v2/features/ritual_room/data/dto/ritual_room_response.dart';
import 'package:mobile_v2/features/ritual_room/data/repositories/ritual_room_repository_impl.dart';
import 'package:mobile_v2/features/ritual_room/domain/repositories/ritual_room_repository.dart';

void main() {
  test(
    'R067 repository delegates fixture-shaped content through DTO and mapper only',
    () async {
      final api = _FakeRitualContentApi(_alternateResponse());
      final RitualRoomRepository repository = RitualRoomRepositoryImpl(
        api: api,
      );

      final content = await repository.loadRoom('alternate_room_v1');

      expect(api.requestedIds, ['alternate_room_v1']);
      expect(content.ritualRoomId, 'alternate_room_v1');
      expect(content.roomName, '雨天小声音');
      expect(content.anchorPhrase, 'Boots on.');
      expect(content.chineseHelper, '穿雨靴啦。');
      expect(content.bootstrapUtterance.primary, "Let's put your boots on.");
      expect(content.actionCue, '拿起雨靴时');
      expect(content.reactionChoices.single.label, '现在想穿了');
    },
  );
}

final class _FakeRitualContentApi implements RitualContentApi {
  _FakeRitualContentApi(this.response);

  final RitualRoomResponse response;
  final List<String> requestedIds = [];

  @override
  Future<RitualRoomResponse> fetchRoom(String ritualRoomId) async {
    requestedIds.add(ritualRoomId);
    return response;
  }
}

RitualRoomResponse _alternateResponse() => RitualRoomResponse.fromJson({
  'ritual_room_id': 'alternate_room_v1',
  'room_name': '雨天小声音',
  'routine_anchor': '雨天出门',
  'anchor_phrase': 'Boots on.',
  'chinese_helper': '穿雨靴啦。',
  'illustration': {
    'asset_path':
        'assets/illustrations/rituals/shoes_on/shoes_on_approved_v1.png',
    'status': 'approved',
  },
  'bootstrap_utterance': {
    'primary': "Let's put your boots on.",
    'zh_helper': '我们来穿雨靴吧。',
  },
  'action_cue': '拿起雨靴时',
  'audio': {'available': false, 'label': '听一遍', 'asset_reference': null},
  'reaction_prompt': '现在是什么情况？',
  'reaction_choices': [
    {'id': 'ready_now', 'label': '现在想穿了'},
  ],
  'pending_copy': '正在换一种说法…',
  'reassurance': '说一句就够了。',
  'quiet_exit': '先这样就好',
  'governance_evidence': {
    'context_seed_id': 'context_seed_alternate',
    'joinability_hypothesis': 'shared_action_is_open',
    'governor_decision': 'allow_activation',
    'production_garden_status': 'not_enabled',
  },
});
