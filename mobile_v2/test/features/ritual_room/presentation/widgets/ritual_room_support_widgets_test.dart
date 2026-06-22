import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/app/localization/generated/app_localizations.dart';
import 'package:mobile_v2/app/theme/baby_talk_theme.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/context_memory.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/normalized_input.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/ritual_atmosphere_tone.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/ritual_room_content.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/strategy_decision.dart';
import 'package:mobile_v2/features/ritual_room/presentation/models/ritual_listen_state.dart';
import 'package:mobile_v2/features/ritual_room/presentation/widgets/ritual_atmosphere_layer.dart';
import 'package:mobile_v2/features/ritual_room/presentation/widgets/ritual_identity_header.dart';
import 'package:mobile_v2/features/ritual_room/presentation/widgets/ritual_sentence_plane.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'builds a decorative atmosphere and atomic snapshot sentence field',
    (tester) async {
      await _setPhoneViewport(tester);
      final room = _room();
      final snapshot = _snapshot();

      await tester.pumpWidget(
        _sentenceFieldSurface(room: room, snapshot: snapshot),
      );

      expect(find.byType(RitualAtmosphereLayer), findsOneWidget);
      expect(find.byType(RitualSentencePlane), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(RitualIdentityHeader), findsNothing);
      expect(find.text(snapshot.activeUtterance.primary), findsOneWidget);
      expect(find.text(snapshot.activeUtterance.zhSupport), findsOneWidget);
      expect(find.text(snapshot.activeUtterance.actionCue), findsOneWidget);
      expect(find.text('legacy room-level cue'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('swaps all three utterance values atomically in one pump', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    final room = _room();
    final current = _snapshot();
    final revised = _snapshot(
      revision: 1,
      utterance: 'You can hold your shoe.',
      helper: '你可以拿着自己的鞋。',
      actionCue: '宝宝伸手时',
    );

    await tester.pumpWidget(
      _sentenceFieldSurface(
        room: room,
        snapshot: current,
        motionDuration: Duration.zero,
      ),
    );
    await tester.pumpWidget(
      _sentenceFieldSurface(
        room: room,
        snapshot: revised,
        motionDuration: Duration.zero,
      ),
    );

    for (final value in [
      revised.activeUtterance.primary,
      revised.activeUtterance.zhSupport,
      revised.activeUtterance.actionCue,
    ]) {
      expect(find.text(value), findsOneWidget);
    }
    for (final value in [
      current.activeUtterance.primary,
      current.activeUtterance.zhSupport,
      current.activeUtterance.actionCue,
    ]) {
      expect(find.text(value), findsNothing);
    }
  });

  testWidgets(
    'keeps atmosphere decorative, edge-sized, and gradient-free in high contrast',
    (tester) async {
      await _setPhoneViewport(tester);
      final room = _room();

      await tester.pumpWidget(
        _sentenceFieldSurface(room: room, snapshot: _snapshot()),
      );

      expect(find.byKey(const Key('ritual-atmosphere-layer')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('ritual-atmosphere-layer')),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget(find.byKey(const Key('ritual-atmosphere-layer'))),
        isA<IgnorePointer>(),
      );
      final illustrationSize = tester.getSize(
        find.byKey(const Key('ritual-atmosphere-illustration')),
      );
      expect(illustrationSize.width, inInclusiveRange(88, 128));
      expect(illustrationSize.height, inInclusiveRange(88, 128));
      expect(_atmosphereDecoration(tester).gradient, isNotNull);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: _sentenceFieldSurface(room: room, snapshot: _snapshot()),
        ),
      );

      expect(_atmosphereDecoration(tester).gradient, isNull);
    },
  );

  testWidgets('orders sentence semantics and disables unavailable audio', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    final snapshot = _snapshot();
    var listenCalls = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _sentenceFieldSurface(
        room: _room(),
        snapshot: snapshot,
        listenState: const RitualListenUnavailable(),
        onListen: () => listenCalls += 1,
      ),
    );

    final primary = tester.widget<Semantics>(
      find.byKey(const Key('ritual-primary-sentence')),
    );
    final support = tester.widget<Semantics>(
      find.byKey(const Key('ritual-zh-support')),
    );
    expect(primary.properties.sortKey, const OrdinalSortKey(1));
    expect(support.properties.sortKey, const OrdinalSortKey(2));
    expect(
      find.bySemanticsLabel('说这句话的时机：${snapshot.activeUtterance.actionCue}'),
      findsOneWidget,
    );

    final button = tester.widget<IconButton>(
      find.byKey(const Key('ritual-listen-control')),
    );
    expect(button.onPressed, isNull);
    await tester.tap(find.byKey(const Key('ritual-listen-control')));
    expect(listenCalls, 0);
    semantics.dispose();
  });

  testWidgets('uses fade-only switching for an 80ms motion duration', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    final room = _room();

    await tester.pumpWidget(
      _sentenceFieldSurface(
        room: room,
        snapshot: _snapshot(),
        motionDuration: const Duration(milliseconds: 80),
      ),
    );
    await tester.pumpWidget(
      _sentenceFieldSurface(
        room: room,
        snapshot: _snapshot(revision: 1),
        motionDuration: const Duration(milliseconds: 80),
      ),
    );

    final switcher = find.descendant(
      of: find.byKey(const Key('ritual-sentence-plane')),
      matching: find.byType(AnimatedSwitcher),
    );
    expect(switcher, findsOneWidget);
    expect(
      find.descendant(of: switcher, matching: find.byType(FadeTransition)),
      findsWidgets,
    );
    expect(
      find.descendant(of: switcher, matching: find.byType(SlideTransition)),
      findsNothing,
    );
  });
}

BoxDecoration _atmosphereDecoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.byKey(const Key('ritual-atmosphere-field')),
            )
            .decoration
        as BoxDecoration;

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _sentenceFieldSurface({
  required RitualRoomContent room,
  required ProductSnapshot snapshot,
  RitualListenState listenState = const RitualListenReady(),
  VoidCallback? onListen,
  Duration motionDuration = const Duration(milliseconds: 200),
}) {
  return MaterialApp(
    theme: BabyTalkTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RitualAtmosphereLayer(
              illustration: room.illustration,
              tone: room.atmosphereTone,
              roomName: room.roomName,
            ),
            Align(
              alignment: Alignment.center,
              child: RitualSentencePlane(
                utterance: snapshot.activeUtterance,
                listenState: listenState,
                onListen: onListen,
                motionDuration: motionDuration,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

RitualRoomContent _room() {
  return RitualRoomContent(
    ritualRoomId: 'shoes_on_room_v1',
    atmosphereTone: RitualAtmosphereTone.everydayCalm,
    roomName: '出门小声音',
    routineAnchor: '出门穿鞋',
    anchorPhrase: 'Shoes on.',
    chineseHelper: '穿鞋啦。',
    illustration: const RitualIllustration(
      assetPath:
          'assets/illustrations/rituals/shoes_on/shoes_on_approved_v1.png',
      status: 'approved',
    ),
    actionCue: 'legacy room-level cue',
    audio: const RitualAudioContent(
      available: true,
      label: '听一遍',
      assetReference: 'assets/audio/current.mp3',
    ),
    reactionPrompt: '现在是什么情况？',
    reactionChoices: const [],
    pendingCopy: '正在换一种说法…',
    reassurance: '不用每句都说，说一句就够了。',
    quietExit: '先这样就好',
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
  String utterance = 'Let’s put your shoes on.',
  String helper = '我们来穿鞋吧。',
  String actionCue = '拿起鞋时',
}) {
  return ProductSnapshot(
    schemaVersion: ProductSnapshot.currentSchemaVersion,
    revision: revision,
    interactionId: 'interaction-shoes',
    ritualRoomId: 'shoes_on_room_v1',
    anchor: 'Shoes on.',
    normalizedContext: NormalizedInput(
      semanticSignals: const ['shared_action'],
      intentEstimate: 'continue',
      momentHypothesis: 'shared action is available',
      contextFrame: const {
        'interactionType': 'caregiver_shared_action_support',
      },
      confidence: 0.8,
      eventSummary: '出门穿鞋',
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
      modifiers: const [StrategyModifier.continueInteraction],
      confidence: 0.8,
      rationale: 'one simple line fits the current moment',
      pressureLevel: 20,
      recommendedTone: 'soft',
      interactionHint: 'offer one line without requiring a response',
    ),
    activeUtterance: ActiveUtterance(
      displayId: 'shoes-$revision',
      primary: utterance,
      zhSupport: helper,
      actionCue: actionCue,
      audioAssetId: 'rr-shoes-$revision',
    ),
    metadata: ProductSnapshotMetadata(
      lastEventId: revision == 0 ? null : 'event-$revision',
      updatedAt: DateTime.utc(2026, 6, 23, 10, revision),
    ),
  );
}
