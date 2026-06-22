import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/context_memory.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/normalized_input.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/ritual_room_content.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/strategy_decision.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';
import 'package:mobile_v2/features/ritual_room/presentation/widgets/ritual_action_cue.dart';
import 'package:mobile_v2/features/ritual_room/presentation/widgets/ritual_context_input_tray.dart';
import 'package:mobile_v2/features/ritual_room/presentation/widgets/ritual_current_utterance.dart';
import 'package:mobile_v2/features/ritual_room/presentation/widgets/ritual_identity_header.dart';
import 'package:mobile_v2/features/ritual_room/presentation/widgets/ritual_listen_control.dart';
import 'package:mobile_v2/features/ritual_room/presentation/widgets/ritual_reassurance.dart';
import 'package:mobile_v2/features/ritual_room/presentation/widgets/ritual_submitting_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'projects exactly one current utterance, action cue, listen control, reassurance, and quiet exit',
    (tester) async {
      await _setPhoneViewport(tester);
      final room = _room();
      final snapshot = _snapshot();
      final reactions = <String>[];
      var listenCalls = 0;
      var quietExitCalls = 0;
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        _supportSurface(
          room: room,
          snapshot: snapshot,
          onListen: () => listenCalls += 1,
          onReactionSelected: reactions.add,
          onQuietExit: () => quietExitCalls += 1,
        ),
      );

      expect(find.byType(RitualIdentityHeader), findsOneWidget);
      expect(find.byType(RitualCurrentUtterance), findsOneWidget);
      expect(find.byType(RitualActionCue), findsOneWidget);
      expect(find.byType(RitualListenControl), findsOneWidget);
      expect(find.byType(RitualReassurance), findsOneWidget);
      expect(find.text(snapshot.activeUtterance.primary), findsOneWidget);
      expect(find.text(room.actionCue), findsOneWidget);
      expect(find.text(room.reassurance), findsOneWidget);
      expect(find.text(room.quietExit), findsOneWidget);
      expect(find.text(room.reactionChoices[0].label), findsOneWidget);
      expect(find.text(room.reactionChoices[1].label), findsOneWidget);
      expect(find.text(room.reactionChoices[2].label), findsNothing);

      final headerSize = tester.getSize(
        find.byKey(const Key('ritual-identity-header')),
      );
      expect(headerSize.height, inInclusiveRange(185, 220));

      expect(find.bySemanticsLabel(room.audio.label), findsOneWidget);
      expect(find.bySemanticsLabel(room.quietExit), findsOneWidget);
      expect(
        find.bySemanticsLabel(room.reactionChoices[0].label),
        findsOneWidget,
      );

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

      await tester.tap(find.byKey(const Key('ritual-listen-control')));
      await tester.tap(find.byKey(const Key('ritual-reaction-choice-0')));
      await tester.tap(find.byKey(const Key('ritual-quiet-exit')));

      expect(listenCalls, 1);
      expect(reactions, [room.reactionChoices[0].id]);
      expect(quietExitCalls, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'shows additional content-owned reactions in a half-height Material sheet',
    (tester) async {
      await _setPhoneViewport(tester);
      final room = _room();
      final reactions = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RitualContextInputTray(
              prompt: room.reactionPrompt,
              choices: room.reactionChoices,
              moreChoicesLabel: '更多情况',
              onReactionSelected: reactions.add,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('ritual-more-reactions')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ritual-reaction-sheet')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('ritual-reaction-sheet'))).height,
        inInclusiveRange(390, 430),
      );
      expect(find.text(room.reactionChoices[2].label), findsOneWidget);
      expect(find.text(room.reactionChoices[4].label), findsOneWidget);

      await tester.tap(find.text(room.reactionChoices[3].label));
      await tester.pumpAndSettle();

      expect(reactions, [room.reactionChoices[3].id]);
      expect(find.byKey(const Key('ritual-reaction-sheet')), findsNothing);
    },
  );

  testWidgets(
    'preserves the last usable snapshot while submitting and replaces revised content in place',
    (tester) async {
      await _setPhoneViewport(tester);
      final room = _room();
      final current = _snapshot();
      final revised = _snapshot(
        revision: 1,
        contextLabel: '还不想穿',
        utterance: "You don't want your shoes on yet.",
        helper: '你现在还不想穿鞋。',
      );

      await tester.pumpWidget(
        _supportSurface(room: room, snapshot: current, submitting: true),
      );

      expect(find.byType(RitualCurrentUtterance), findsOneWidget);
      expect(find.text(current.activeUtterance.primary), findsOneWidget);
      expect(find.byType(RitualSubmittingIndicator), findsOneWidget);
      expect(find.text(room.pendingCopy), findsOneWidget);

      await tester.pumpWidget(_supportSurface(room: room, snapshot: revised));
      await tester.pump();

      expect(find.byType(RitualCurrentUtterance), findsOneWidget);
      expect(find.text(current.activeUtterance.primary), findsNothing);
      expect(find.text(revised.normalizedContext.eventSummary), findsOneWidget);
      expect(find.text(revised.activeUtterance.primary), findsOneWidget);
      expect(find.text(revised.activeUtterance.zhSupport), findsOneWidget);
      expect(find.byType(RitualSubmittingIndicator), findsNothing);
      expect(find.text(room.anchorPhrase), findsOneWidget);
    },
  );

  testWidgets(
    'alternate safe payload replaces every ritual value and long scaled text does not clip',
    (tester) async {
      await _setPhoneViewport(tester);
      final alternateRoom = _room(
        ritualRoomId: 'bath_room_v1',
        roomName: '洗澡小声音',
        routineAnchor: '洗澡时间',
        anchorPhrase: 'Bath time.',
        chineseHelper: '洗澡啦。',
        illustrationPath:
            'assets/illustrations/rituals/shoes_on/shoes_on_approved_v1.png',
        actionCue: '放好浴巾以后，慢慢说这一句。',
        audioLabel: '播放这句话',
        reactionPrompt: '现在这个时刻是什么样？',
        reactionChoices: const [
          RitualReactionChoice(id: 'watching_water', label: '在看水'),
          RitualReactionChoice(id: 'holding_towel', label: '抱着浴巾'),
          RitualReactionChoice(id: 'needs_pause', label: '想先停一下'),
        ],
        pendingCopy: '正在准备更贴近此刻的说法…',
        reassurance: '不用要求回应，只要把这句话放进正在发生的动作里。',
        quietExit: '今天先到这里',
      );
      final alternateSnapshot = _snapshot(
        roomId: alternateRoom.ritualRoomId,
        anchor: alternateRoom.anchorPhrase,
        contextLabel: '正在一起准备很长很长的洗澡步骤',
        utterance:
            'Let us put the warm towel beside the tub before we begin bath time together.',
        helper: '开始一起洗澡之前，我们先把暖和的浴巾放在浴缸旁边。',
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: _supportSurface(
            room: alternateRoom,
            snapshot: alternateSnapshot,
            moreChoicesLabel: '看看其他情况',
          ),
        ),
      );

      for (final value in [
        alternateRoom.roomName,
        alternateRoom.routineAnchor,
        alternateRoom.anchorPhrase,
        alternateRoom.chineseHelper,
        alternateRoom.actionCue,
        alternateRoom.audio.label,
        alternateRoom.reactionPrompt,
        alternateRoom.reactionChoices[0].label,
        alternateRoom.reactionChoices[1].label,
        alternateRoom.reassurance,
        alternateRoom.quietExit,
        alternateSnapshot.normalizedContext.eventSummary,
        alternateSnapshot.activeUtterance.primary,
        alternateSnapshot.activeUtterance.zhSupport,
      ]) {
        expect(find.text(value), findsOneWidget);
      }

      for (final oldValue in [
        '出门小声音',
        '出门穿鞋',
        'Shoes on.',
        '穿鞋啦。',
        "Let's put your shoes on.",
        '我们来穿鞋吧。',
        '拿起鞋时',
        '听一遍',
        '现在是什么情况？',
        '还不想穿',
        '想自己来',
        '不用每句都说，说一句就够了。',
        '先这样就好',
      ]) {
        expect(find.text(oldValue), findsNothing);
      }

      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.textContaining('下一句'), findsNothing);
      expect(find.textContaining('进度'), findsNothing);
      expect(find.textContaining('积分'), findsNothing);
      expect(find.textContaining('任务'), findsNothing);
      expect(find.textContaining('Garden'), findsNothing);
      expect(find.textContaining('表现'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _supportSurface({
  required RitualRoomContent room,
  required ProductSnapshot snapshot,
  bool submitting = false,
  String moreChoicesLabel = '更多情况',
  VoidCallback? onListen,
  ValueChanged<String>? onReactionSelected,
  VoidCallback? onQuietExit,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            RitualIdentityHeader(
              illustration: room.illustration,
              roomName: room.roomName,
              routineAnchor: room.routineAnchor,
              anchorPhrase: room.anchorPhrase,
              chineseHelper: room.chineseHelper,
            ),
            RitualCurrentUtterance(
              snapshot: snapshot,
              actionCue: room.actionCue,
              audio: room.audio,
              submitting: submitting,
              pendingCopy: room.pendingCopy,
              onListen: onListen ?? () {},
            ),
            RitualContextInputTray(
              prompt: room.reactionPrompt,
              choices: room.reactionChoices,
              moreChoicesLabel: moreChoicesLabel,
              onReactionSelected: onReactionSelected ?? (_) {},
            ),
            RitualReassurance(
              message: room.reassurance,
              quietExitLabel: room.quietExit,
              onQuietExit: onQuietExit ?? () {},
            ),
          ],
        ),
      ),
    ),
  );
}

RitualRoomContent _room({
  String ritualRoomId = 'shoes_on_room_v1',
  String roomName = '出门小声音',
  String routineAnchor = '出门穿鞋',
  String anchorPhrase = 'Shoes on.',
  String chineseHelper = '穿鞋啦。',
  String illustrationPath =
      'assets/illustrations/rituals/shoes_on/shoes_on_approved_v1.png',
  String actionCue = '拿起鞋时',
  String audioLabel = '听一遍',
  String reactionPrompt = '现在是什么情况？',
  List<RitualReactionChoice> reactionChoices = const [
    RitualReactionChoice(id: 'not_ready', label: '还不想穿'),
    RitualReactionChoice(id: 'self', label: '想自己来'),
    RitualReactionChoice(id: 'crying', label: '哭了'),
    RitualReactionChoice(id: 'moved_away', label: '跑开了'),
    RitualReactionChoice(id: 'finished', label: '已经穿好了'),
  ],
  String pendingCopy = '正在换一种说法…',
  String reassurance = '不用每句都说，说一句就够了。',
  String quietExit = '先这样就好',
}) {
  return RitualRoomContent(
    ritualRoomId: ritualRoomId,
    roomName: roomName,
    routineAnchor: routineAnchor,
    anchorPhrase: anchorPhrase,
    chineseHelper: chineseHelper,
    illustration: RitualIllustration(
      assetPath: illustrationPath,
      status: 'approved',
    ),
    actionCue: actionCue,
    audio: RitualAudioContent(
      available: true,
      label: audioLabel,
      assetReference: 'assets/audio/current.mp3',
    ),
    reactionPrompt: reactionPrompt,
    reactionChoices: reactionChoices,
    pendingCopy: pendingCopy,
    reassurance: reassurance,
    quietExit: quietExit,
    governanceEvidence: const RitualGovernanceEvidence(
      contextSeedId: 'safe-test-seed',
      joinabilityHypothesis: 'shared_action_available',
      governorDecision: 'explore',
      productionGardenStatus: 'unchanged',
    ),
  );
}

ProductSnapshot _snapshot({
  int revision = 0,
  String roomId = 'shoes_on_room_v1',
  String anchor = 'Shoes on.',
  String contextLabel = '出门穿鞋',
  String utterance = "Let's put your shoes on.",
  String helper = '我们来穿鞋吧。',
}) {
  return ProductSnapshot(
    schemaVersion: ProductSnapshot.currentSchemaVersion,
    revision: revision,
    interactionId: 'interaction-$roomId',
    ritualRoomId: roomId,
    anchor: anchor,
    normalizedContext: NormalizedInput(
      semanticSignals: const ['shared_action'],
      intentEstimate: 'continue',
      momentHypothesis: 'shared action is available',
      contextFrame: const {
        'interactionType': 'caregiver_shared_action_support',
      },
      confidence: 0.8,
      eventSummary: contextLabel,
    ),
    memory: ContextMemory(
      summary: 'shared action remains available',
      eventLog: const [],
      signalWeights: const {'shared_action': 0.8},
      interactionTrend: 'stable',
      contextStability: 0.8,
      narrative: 'the caregiver can continue with one simple line',
    ),
    strategy: StrategyDecision(
      primary: PressurePolicy.lowPressure,
      modifiers: const [
        StrategyModifier.continueInteraction,
        StrategyModifier.reduceOptions,
      ],
      confidence: 0.8,
      rationale: 'one simple line fits the current moment',
      pressureLevel: 20,
      recommendedTone: 'soft',
      interactionHint: 'offer one line without requiring a response',
    ),
    activeUtterance: ActiveUtterance(
      displayId: revision == 0
          ? 'shoes_on_ready_v1'
          : 'shoes_on_revised_wait_v1',
      primary: utterance,
      zhSupport: helper,
      audioAssetId: revision == 0 ? 'rr_shoes_001' : 'rr_shoes_002',
      contextLabel: contextLabel,
    ),
    metadata: ProductSnapshotMetadata(
      lastEventId: revision == 0 ? null : 'event-$revision',
      updatedAt: DateTime.utc(2026, 6, 20, 10, revision),
    ),
  );
}
