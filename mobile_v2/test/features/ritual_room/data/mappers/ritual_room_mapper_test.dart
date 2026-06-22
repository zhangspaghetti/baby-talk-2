import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/data/dto/ritual_room_response.dart';
import 'package:mobile_v2/features/ritual_room/data/mappers/ritual_room_mapper.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';

void main() {
  group('RitualRoomMapper', () {
    test(
      'R058/R059 maps the stable family micro-ritual without course semantics',
      () {
        final content = const RitualRoomMapper().toDomain(
          RitualRoomResponse.fromJson(_payload()),
        );

        expect(content.ritualRoomId, 'shoes_on_room_v1');
        expect(content.roomName, '出门小声音');
        expect(content.routineAnchor, '出门穿鞋');
        expect(content.anchorPhrase, 'Shoes on.');
        expect(content.chineseHelper, '穿鞋啦。');
        expect(content.illustration.assetPath, _approvedIllustrationPath);
        expect(content.illustration.status, 'approved');
        final ready = const RitualRoomMapper().toActiveUtterance(
          RitualRoomResponse.fromJson(_payload()),
          ActiveUtteranceSlot.ready,
        );
        expect(ready.displayId, 'shoes_on_ready_v1');
        expect(ready.primary, 'Let’s put your shoes on.');
        expect(ready.zhSupport, '我们来穿鞋吧。');
        expect(ready.actionCue, '拿起鞋时');
        expect(ready.audioAssetId, 'rr_shoes_001');
        final revised = const RitualRoomMapper().toActiveUtterance(
          RitualRoomResponse.fromJson(_payload()),
          ActiveUtteranceSlot.notReadyYet,
        );
        expect(revised.displayId, 'shoes_on_revised_wait_v1');
        expect(revised.contextLabel, '还不想穿');
        expect(revised.gentleSupport, '可以先等等。');
        expect(revised.actionCue, '宝宝停下来时');
        expect(revised.audioAssetId, 'rr_shoes_002');
        expect(content.actionCue, '拿起鞋时');
        expect(content.audio.label, '听一遍');
        expect(content.reactionPrompt, '现在是什么情况？');
        expect(content.reactionChoices.map((choice) => choice.label), [
          '还不想穿',
          '想自己来',
          '哭了',
          '跑开了',
          '已经穿好了',
        ]);
        expect(content.pendingCopy, '正在换一种说法…');
        expect(content.reassurance, '不用每句都说，说一句就够了。');
        expect(content.quietExit, '先这样就好');
      },
    );

    test(
      'R060/R063 keeps Context Seed, joinability, and Governor evidence non-authoritative',
      () {
        final content = const RitualRoomMapper().toDomain(
          RitualRoomResponse.fromJson(_payload()),
        );

        expect(
          content.governanceEvidence.contextSeedId,
          'context_seed_shoes_on',
        );
        expect(
          content.governanceEvidence.joinabilityHypothesis,
          'shared_action_is_open',
        );
        expect(content.governanceEvidence.governorDecision, 'allow_activation');
        expect(
          content.governanceEvidence.productionGardenStatus,
          'not_enabled',
        );
      },
    );

    test(
      'R067 alternate safe payload substitutes every content-owned room value',
      () {
        final alternate = _payload()
          ..['room_name'] = '雨天小声音'
          ..['anchor_phrase'] = 'Boots on.'
          ..['chinese_helper'] = '穿雨靴啦。'
          ..['active_utterances'] = {
            'ready': {
              'display_id': 'boots_on_ready_v1',
              'primary': "Let's put your boots on.",
              'zh_support': '我们来穿雨靴吧。',
              'action_cue': '拿起雨靴时',
              'audio_asset_id': 'rr_boots_001',
            },
            'not_ready_yet': {
              'display_id': 'boots_on_wait_v1',
              'primary': 'Boots can wait.',
              'zh_support': '雨靴可以等等。',
              'action_cue': '宝宝停下来时',
              'audio_asset_id': 'rr_boots_002',
            },
          }
          ..['action_cue'] = '拿起雨靴时'
          ..['reaction_choices'] = [
            {'id': 'needs_help', 'label': '想请你帮忙'},
            {'id': 'ready_now', 'label': '现在想穿了'},
          ];

        final content = const RitualRoomMapper().toDomain(
          RitualRoomResponse.fromJson(alternate),
        );

        expect(content.roomName, '雨天小声音');
        expect(content.anchorPhrase, 'Boots on.');
        expect(content.chineseHelper, '穿雨靴啦。');
        final active = const RitualRoomMapper().toActiveUtterance(
          RitualRoomResponse.fromJson(alternate),
          ActiveUtteranceSlot.ready,
        );
        expect(active.primary, "Let's put your boots on.");
        expect(content.actionCue, '拿起雨靴时');
        expect(content.reactionChoices.map((choice) => choice.label), [
          '想请你帮忙',
          '现在想穿了',
        ]);
      },
    );

    test('T-41-05-01 rejects spoofed illustration lifecycle metadata', () {
      final wrongStatus = _payload()
        ..['illustration'] = {
          'asset_path': _approvedIllustrationPath,
          'status': 'draft',
        };
      final wrongPath = _payload()
        ..['illustration'] = {
          'asset_path': 'assets/illustrations/rituals/shoes_on/unreviewed.png',
          'status': 'approved',
        };

      expect(
        () => const RitualRoomMapper().toDomain(
          RitualRoomResponse.fromJson(wrongStatus),
        ),
        throwsFormatException,
      );
      expect(
        () => const RitualRoomMapper().toDomain(
          RitualRoomResponse.fromJson(wrongPath),
        ),
        throwsFormatException,
      );
    });

    test(
      'R064/R065 content structures exclude runtime, score, completion, replay, and Garden authority',
      () {
        final serialized = RitualRoomResponse.fromJson(_payload()).toJson();
        final serializedText = serialized.toString();
        final domainSource = File(
          'lib/features/ritual_room/domain/models/ritual_room_content.dart',
        ).readAsStringSync();
        const forbidden = <String>[
          'ProductSnapshot',
          'ConsistencyState',
          'ReplayJournal',
          'score',
          'streak',
          'completed',
          'completion',
          'gardenTransition',
          'activate',
        ];

        for (final term in forbidden) {
          expect(
            serializedText,
            isNot(contains(term)),
            reason: 'serialized stable content leaked $term',
          );
          expect(
            domainSource,
            isNot(contains(term)),
            reason: 'stable domain content gained $term authority',
          );
        }
      },
    );
  });
}

const _approvedIllustrationPath =
    'assets/illustrations/rituals/shoes_on/shoes_on_approved_v1.png';

Map<String, Object?> _payload() => {
  'ritual_room_id': 'shoes_on_room_v1',
  'room_name': '出门小声音',
  'routine_anchor': '出门穿鞋',
  'anchor_phrase': 'Shoes on.',
  'chinese_helper': '穿鞋啦。',
  'illustration': {
    'asset_path': _approvedIllustrationPath,
    'status': 'approved',
  },
  'listen_label': '听一遍',
  'active_utterances': {
    'ready': {
      'display_id': 'shoes_on_ready_v1',
      'primary': 'Let’s put your shoes on.',
      'zh_support': '我们来穿鞋吧。',
      'action_cue': '拿起鞋时',
      'audio_asset_id': 'rr_shoes_001',
    },
    'not_ready_yet': {
      'display_id': 'shoes_on_revised_wait_v1',
      'primary': 'You don’t want your shoes on yet.',
      'zh_support': '你现在还不想穿鞋。',
      'action_cue': '宝宝停下来时',
      'context_label': '还不想穿',
      'gentle_support': '可以先等等。',
      'audio_asset_id': 'rr_shoes_002',
    },
  },
  'action_cue': '拿起鞋时',
  'audio': {'available': false, 'label': '听一遍', 'asset_reference': null},
  'reaction_prompt': '现在是什么情况？',
  'reaction_choices': [
    {'id': 'not_ready_yet', 'label': '还不想穿'},
    {'id': 'wants_independence', 'label': '想自己来'},
    {'id': 'crying', 'label': '哭了'},
    {'id': 'moved_away', 'label': '跑开了'},
    {'id': 'already_wearing', 'label': '已经穿好了'},
  ],
  'pending_copy': '正在换一种说法…',
  'reassurance': '不用每句都说，说一句就够了。',
  'quiet_exit': '先这样就好',
  'governance_evidence': {
    'context_seed_id': 'context_seed_shoes_on',
    'joinability_hypothesis': 'shared_action_is_open',
    'governor_decision': 'allow_activation',
    'production_garden_status': 'not_enabled',
  },
};
