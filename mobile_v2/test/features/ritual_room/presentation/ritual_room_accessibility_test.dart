import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/ritual_atmosphere_tone.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/ritual_room_content.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';
import 'package:mobile_v2/features/ritual_room/presentation/capability/interaction_capability_mask.dart';
import 'package:mobile_v2/features/ritual_room/presentation/screens/ritual_room_screen.dart';
import 'package:mobile_v2/features/ritual_room/presentation/state/ritual_room_ui_state.dart';

import '../../../fixtures/interaction_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'R058/R060 ready screen has semantic labels and 48x48 targets at 390x844',
    (tester) async {
      await _setPhoneViewport(tester);
      final semantics = tester.ensureSemantics();
      final room = _room();

      await tester.pumpWidget(
        MaterialApp(
          home: RitualRoomScreen(
            state: RitualRoomReady(room: room, snapshot: interactionSnapshot()),
            capabilityMask: InteractionCapabilityMask.phase41,
            onReactionSelected: (_) {},
            onRetry: () {},
            onRetryPendingEvent: () {},
            onListen: () {},
            onQuietExit: () {},
          ),
        ),
      );

      for (final label in [
        room.audio.label,
        room.quietExit,
        room.reactionChoices[0].label,
        room.reactionChoices[1].label,
        '更多情况',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      for (final key in const [
        Key('ritual-listen-control'),
        Key('ritual-reaction-choice-0'),
        Key('ritual-reaction-choice-1'),
        Key('ritual-more-reactions'),
        Key('ritual-quiet-exit'),
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'R059 long payload at text scale 1.3 wraps without clipping or forbidden controls',
    (tester) async {
      await _setPhoneViewport(tester);
      final room = _room(
        actionCue: '把鞋放在身边以后，停一下，再慢慢说出这一句。',
        reassurance: '不用要求孩子回应，也不用催促，只要自然地说一句就够了。',
      );
      final snapshot = _longSnapshot(actionCue: room.actionCue);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            home: RitualRoomScreen(
              state: RitualRoomReady(room: room, snapshot: snapshot),
              capabilityMask: InteractionCapabilityMask.phase41,
              onReactionSelected: (_) {},
              onRetry: () {},
              onRetryPendingEvent: () {},
              onListen: () {},
              onQuietExit: () {},
            ),
          ),
        ),
      );

      expect(find.text(snapshot.activeUtterance.primary), findsOneWidget);
      expect(find.text(snapshot.activeUtterance.zhSupport), findsOneWidget);
      expect(find.text(snapshot.activeUtterance.actionCue), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(room.reassurance),
        160,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(room.reassurance), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('下一句'), findsNothing);
      expect(find.textContaining('课程'), findsNothing);
      expect(find.textContaining('任务'), findsNothing);
      expect(find.textContaining('进度'), findsNothing);
      expect(find.textContaining('分数'), findsNothing);
      expect(find.textContaining('Garden'), findsNothing);
      expect(find.textContaining('Phase 42'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unknown outcome message and retry action remain semantically reachable',
    (tester) async {
      await _setPhoneViewport(tester);
      final semantics = tester.ensureSemantics();
      final room = _room();
      var retries = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: RitualRoomScreen(
            state: RitualRoomUnknownOutcome(
              room: room,
              snapshot: interactionSnapshot(),
              selectedReaction: 'not_ready',
              isRetrying: false,
            ),
            capabilityMask: InteractionCapabilityMask.phase41,
            onReactionSelected: (_) {},
            onRetry: () {},
            onRetryPendingEvent: () => retries += 1,
            onListen: () {},
            onQuietExit: () {},
          ),
        ),
      );

      expect(find.bySemanticsLabel('刚才这次没有确认成功，可以再试一次'), findsOneWidget);
      final retryFinder = find.byKey(const Key('ritual-unknown-outcome-retry'));
      expect(retryFinder, findsOneWidget);
      expect(tester.getSize(retryFinder).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(retryFinder).height, greaterThanOrEqualTo(48));
      await tester.tap(retryFinder);
      expect(retries, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

RitualRoomContent _room({
  String actionCue = '拿起鞋时',
  String reassurance = '不用每句都说，说一句就够了。',
}) => RitualRoomContent(
  ritualRoomId: 'shoes_on_room_v1',
  atmosphereTone: RitualAtmosphereTone.everydayCalm,
  roomName: '出门小声音',
  routineAnchor: '出门穿鞋',
  anchorPhrase: 'Shoes on.',
  chineseHelper: '穿鞋啦。',
  illustration: const RitualIllustration(
    assetPath: 'assets/illustrations/rituals/shoes_on/shoes_on_approved_v1.png',
    status: 'approved',
  ),
  actionCue: actionCue,
  audio: const RitualAudioContent(
    available: true,
    label: '听一遍',
    assetReference: 'assets/audio/current.mp3',
  ),
  reactionPrompt: '现在是什么情况？',
  reactionChoices: const [
    RitualReactionChoice(id: 'not_ready', label: '还不想穿'),
    RitualReactionChoice(id: 'self', label: '想自己来'),
    RitualReactionChoice(id: 'crying', label: '哭了'),
  ],
  pendingCopy: '正在换一种说法…',
  reassurance: reassurance,
  quietExit: '先这样就好',
  governanceEvidence: const RitualGovernanceEvidence(
    contextSeedId: 'accessibility-test-seed',
    joinabilityHypothesis: 'shared_action_available',
    governorDecision: 'allow_activation',
    productionGardenStatus: 'not_enabled',
  ),
);

ProductSnapshot _longSnapshot({required String actionCue}) {
  final base = interactionSnapshot();
  return ProductSnapshot(
    schemaVersion: base.schemaVersion,
    revision: base.revision,
    interactionId: base.interactionId,
    ritualRoomId: base.ritualRoomId,
    anchor: base.anchor,
    normalizedContext: base.normalizedContext,
    memory: base.memory,
    strategy: base.strategy,
    activeUtterance: ActiveUtterance(
      displayId: 'shoes_on_long_v1',
      primary:
          'Let us place one shoe beside you and wait together until this shared moment feels easier to enter.',
      zhSupport: '我们先把一只鞋放在你身边，一起等一等，等这个共同的时刻更容易加入。',
      actionCue: actionCue,
      audioAssetId: 'rr_shoes_001',
    ),
    metadata: base.metadata,
  );
}
